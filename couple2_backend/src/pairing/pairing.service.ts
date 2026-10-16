import {
  Injectable,
  BadRequestException,
  NotFoundException,
  ConflictException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { isUniqueViolation } from '../notifications/prisma-errors';
import { PrismaService } from '../prisma';
import { UsersService } from '../users';
import { PairResponseDto, PairingStatus } from './dto';
import { applyPairing } from './apply-pairing';

@Injectable()
export class PairingService {
  /** Serializes accepts for the same pair inside this process. */
  private readonly acceptTails = new Map<string, Promise<void>>();

  constructor(
    private prisma: PrismaService,
    private usersService: UsersService,
  ) {}

  /**
   * Initiates or completes a pairing request using the double handshake system.
   *
   * Flow:
   * 1. User A enters User B's code → creates PairingRequest (pending)
   * 2. User B enters User A's code → system detects mutual intent → pairs both users
   */
  async requestPairing(
    requesterId: string,
    targetCode: string,
  ): Promise<PairResponseDto> {
    const normalizedCode = targetCode.toUpperCase().trim();

    // Validate code format
    if (!/^[A-Z0-9]{6}$/.test(normalizedCode)) {
      throw new BadRequestException(
        'Invalid code format. Must be 6 alphanumeric characters.',
      );
    }

    // Get the requester
    const requester = await this.prisma.user.findUnique({
      where: { id: requesterId },
    });

    if (!requester) {
      throw new NotFoundException('User not found');
    }

    // Check if requester already has a partner
    if (requester.partnerId) {
      throw new ConflictException('You are already paired with a partner');
    }

    // Check if user is trying to use their own code
    if (requester.pairingCode === normalizedCode) {
      throw new BadRequestException('You cannot pair with yourself');
    }

    // Find the target user by their pairing code
    const targetUser =
      await this.usersService.findByPairingCode(normalizedCode);

    if (!targetUser) {
      throw new NotFoundException(
        'Invalid pairing code. No user found with this code.',
      );
    }

    // Check if target code is expired
    if (!this.usersService.isPairingCodeValid(targetUser)) {
      throw new BadRequestException('This pairing code has expired');
    }

    // Check if target user already has a partner
    if (targetUser.partnerId) {
      throw new ConflictException(
        'This user is already paired with someone else',
      );
    }

    // Check if there's a reciprocal request (target has already requested pairing with requester)
    const reciprocalRequest = await this.prisma.pairingRequest.findFirst({
      where: {
        requesterId: targetUser.id,
        targetCode: requester.pairingCode || '',
      },
    });

    if (reciprocalRequest) {
      // Double handshake complete! Pair the users
      return await this.completePairing(requester.id, targetUser.id);
    }

    // No reciprocal request, create a pending request
    await this.createPairingRequest(requesterId, normalizedCode);

    return {
      status: PairingStatus.PENDING,
      message:
        'Pairing request sent. Waiting for your partner to enter your code.',
    };
  }

  /**
   * Creates a new pairing request or updates existing one.
   */
  private async createPairingRequest(requesterId: string, targetCode: string) {
    // Delete any existing request from this user (they can only have one pending)
    await this.prisma.pairingRequest.deleteMany({
      where: { requesterId },
    });

    // Create new request
    await this.prisma.pairingRequest.create({
      data: {
        requesterId,
        targetCode,
      },
    });
  }

  /**
   * Completes the pairing between two users.
   * partnerId, coupleId, and the Couple row commit together or not at all.
   */
  private async completePairing(
    userAId: string,
    userBId: string,
  ): Promise<PairResponseDto> {
    try {
      const paired = await this.prisma.$transaction(async (tx) => {
        await this.lockUsers(tx, [userAId, userBId]);
        const existing = await this.alreadyPaired(tx, userAId, userBId);
        if (existing) return existing;
        return applyPairing(tx, userAId, userBId);
      });

      return this.pairedBody(paired.partner);
    } catch (error) {
      if (!isUniqueViolation(error)) throw error;
      return this.conflictOrExistingPair(userAId, userBId);
    }
  }

  /**
   * Cancels any pending pairing request for a user.
   */
  async cancelPairingRequest(userId: string): Promise<void> {
    await this.prisma.pairingRequest.deleteMany({
      where: { requesterId: userId },
    });
  }

  /**
   * Returns the current user's pairing code, creating one when the stored
   * code is missing or expired. Paired users keep no code.
   */
  async ensureOwnPairingCode(userId: string) {
    const user = await this.usersService.ensurePairingCode(userId);
    if (user.partnerId) {
      throw new ConflictException('You are already paired with a partner');
    }
    return {
      pairingCode: user.pairingCode,
      pairingCodeExpiresAt: user.pairingCodeExpiresAt,
    };
  }

  /**
   * Gets the current pairing request status for a user.
   */
  async getPairingStatus(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: {
        partner: {
          select: { id: true, name: true, email: true },
        },
        pairingRequestsSent: true,
      },
    });

    if (!user) {
      throw new NotFoundException('User not found');
    }

    if (user.partnerId && user.partner) {
      return {
        status: 'paired',
        partner: {
          id: user.partner.id,
          name: user.partner.name,
        },
      };
    }

    if (user.pairingRequestsSent.length > 0) {
      return {
        status: 'pending',
        pendingCode: user.pairingRequestsSent[0].targetCode,
        pairingCode: user.pairingCode,
        pairingCodeExpiresAt: user.pairingCodeExpiresAt,
        message: 'Waiting for your partner to accept or decline',
      };
    }

    return {
      status: 'unpaired',
      pairingCode: user.pairingCode,
      pairingCodeExpiresAt: user.pairingCodeExpiresAt,
    };
  }

  /**
   * Requests whose target code is the caller's current pairing code.
   * The payload is id, time, and the requester's id and name. Never a code.
   */
  async listReceivedRequests(userId: string) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) {
      throw new NotFoundException('User not found');
    }
    if (!user.pairingCode) return [];

    const rows = await this.prisma.pairingRequest.findMany({
      where: { targetCode: user.pairingCode },
      include: {
        requester: { select: { id: true, name: true } },
      },
      orderBy: { createdAt: 'asc' },
    });

    return rows.map((row) => ({
      id: row.id,
      createdAt: row.createdAt,
      requester: {
        id: row.requester.id,
        name: row.requester.name,
      },
    }));
  }

  /**
   * Accepts one request addressed to the caller and completes the pair.
   * A repeated or concurrent accept of the same request returns the paired
   * result. It never surfaces a unique-constraint 500.
   * A request for anyone else is 404, so ids cannot be used to probe.
   */
  async acceptReceivedRequest(userId: string, requestId: string) {
    const preview = await this.prisma.pairingRequest.findUnique({
      where: { id: requestId },
    });
    const key = [userId, preview?.requesterId ?? '']
      .filter((id) => id.length > 0)
      .sort()
      .join(':');
    return this.runExclusive(key, () => this.acceptOnce(userId, requestId));
  }

  private async acceptOnce(
    userId: string,
    requestId: string,
  ): Promise<PairResponseDto> {
    try {
      return await this.prisma.$transaction(async (tx) => {
        const request = await tx.pairingRequest.findUnique({
          where: { id: requestId },
        });
        const ids = [userId];
        if (request) ids.push(request.requesterId);
        await this.lockUsers(tx, ids);

        const user = await tx.user.findUnique({
          where: { id: userId },
          include: { partner: { select: { id: true, name: true } } },
        });
        if (!user) {
          throw new NotFoundException('User not found');
        }

        const owned =
          !!request &&
          !!user.pairingCode &&
          request.targetCode === user.pairingCode;

        if (!owned) {
          if (user.partnerId && user.partner) {
            return this.pairedBody({
              id: user.partner.id,
              name: user.partner.name,
            });
          }
          throw new NotFoundException('Pairing request not found');
        }

        if (user.partnerId) {
          throw new ConflictException('You are already paired with a partner');
        }

        const requester = await tx.user.findUnique({
          where: { id: request.requesterId },
        });
        if (!requester) {
          throw new NotFoundException('Pairing request not found');
        }
        if (requester.partnerId) {
          throw new ConflictException(
            'This user is already paired with someone else',
          );
        }

        const paired = await applyPairing(tx, user.id, requester.id);
        return this.pairedBody(paired.partner);
      });
    } catch (error) {
      if (!isUniqueViolation(error)) throw error;
      const user = await this.prisma.user.findUnique({
        where: { id: userId },
        include: { partner: { select: { id: true, name: true } } },
      });
      if (user?.partnerId && user.partner) {
        return this.pairedBody({
          id: user.partner.id,
          name: user.partner.name,
        });
      }
      throw new ConflictException('You are already paired with a partner');
    }
  }

  private pairedBody(partner: {
    id: string;
    name: string | null;
  }): PairResponseDto {
    return {
      status: PairingStatus.PAIRED,
      message: 'Successfully paired with your partner!',
      partner,
    };
  }

  private async alreadyPaired(
    tx: Prisma.TransactionClient,
    userAId: string,
    userBId: string,
  ) {
    const user = await tx.user.findUnique({
      where: { id: userAId },
      include: { partner: { select: { id: true, name: true } } },
    });
    if (user?.partnerId === userBId && user.partner) {
      return {
        coupleId: user.coupleId ?? '',
        partner: { id: user.partner.id, name: user.partner.name },
      };
    }
    const other = await tx.user.findUnique({
      where: { id: userBId },
      include: { partner: { select: { id: true, name: true } } },
    });
    if (other?.partnerId === userAId) {
      return {
        coupleId: other.coupleId ?? '',
        partner: { id: other.id, name: other.name },
      };
    }
    if (user?.partnerId || other?.partnerId) {
      throw new ConflictException('You are already paired with a partner');
    }
    return null;
  }

  private async conflictOrExistingPair(userAId: string, userBId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userAId },
      include: { partner: { select: { id: true, name: true } } },
    });
    if (user?.partnerId === userBId && user.partner) {
      return this.pairedBody({
        id: user.partner.id,
        name: user.partner.name,
      });
    }
    throw new ConflictException('You are already paired with a partner');
  }

  /** Row lock in id order so two accepts cannot both create an active couple. */
  private async lockUsers(tx: Prisma.TransactionClient, ids: string[]) {
    const sorted = [...new Set(ids)].filter((id) => id.length > 0).sort();
    for (const id of sorted) {
      await tx.$queryRaw`SELECT "id" FROM "users" WHERE "id" = ${id} FOR UPDATE`;
    }
  }

  private runExclusive<T>(key: string, fn: () => Promise<T>): Promise<T> {
    const previous = this.acceptTails.get(key) ?? Promise.resolve();
    const run = previous.catch(() => undefined).then(fn);
    this.acceptTails.set(
      key,
      run.then(
        () => undefined,
        () => undefined,
      ),
    );
    return run;
  }

  /**
   * Declines one request addressed to the caller. Other people's requests stay.
   */
  async declineReceivedRequest(userId: string, requestId: string) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) {
      throw new NotFoundException('User not found');
    }

    const request = await this.ownedRequest(user.pairingCode, requestId);
    if (user.partnerId) {
      throw new ConflictException('You are already paired with a partner');
    }

    await this.prisma.pairingRequest.delete({ where: { id: request.id } });
    return { message: 'Pairing request declined' };
  }

  private async ownedRequest(pairingCode: string | null, requestId: string) {
    const request = await this.prisma.pairingRequest.findUnique({
      where: { id: requestId },
    });
    if (!request || !pairingCode || request.targetCode !== pairingCode) {
      throw new NotFoundException('Pairing request not found');
    }
    return request;
  }

  /**
   * Unpairs two users (dissolves the relationship).
   */
  async unpair(userId: string): Promise<void> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
    });

    if (!user) {
      throw new NotFoundException('User not found');
    }

    if (!user.partnerId) {
      throw new BadRequestException('You are not paired with anyone');
    }

    const partnerId = user.partnerId;

    // End the couple and clear both pointers in one transaction.
    // Lists keep the ended coupleId, so neither partner (nor a future
    // partner) can read them. There is no archive window.
    await this.prisma.$transaction(async (tx) => {
      if (user.coupleId) {
        await tx.couple.update({
          where: { id: user.coupleId },
          data: { status: 'ENDED', endedAt: new Date() },
        });
      } else {
        await tx.couple.updateMany({
          where: {
            status: 'ACTIVE',
            OR: [{ userAId: userId }, { userBId: userId }],
          },
          data: { status: 'ENDED', endedAt: new Date() },
        });
      }

      await tx.user.update({
        where: { id: userId },
        data: { partnerId: null, coupleId: null },
      });

      await tx.user.update({
        where: { id: partnerId },
        data: { partnerId: null, coupleId: null },
      });
    });

    // Generate new pairing codes for both users
    await this.usersService.ensurePairingCode(userId);
    await this.usersService.ensurePairingCode(partnerId);
  }
}
