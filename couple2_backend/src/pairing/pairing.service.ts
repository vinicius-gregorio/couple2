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

const copy = {
  badFormat: 'O código precisa ter 6 letras ou números.',
  userNotFound: 'Usuário não encontrado.',
  alreadyPaired: 'Você já está pareado.',
  self: 'Você não pode parear consigo.',
  codeNotFound: 'Não encontramos ninguém com esse código.',
  expired: 'Esse código de pareamento expirou.',
  partnerPaired: 'Essa pessoa já está pareada com outra.',
  pendingSent: 'Pedido enviado. Aguardando a outra pessoa aceitar ou recusar.',
  waiting: 'Aguardando a outra pessoa aceitar ou recusar.',
  paired: 'Pareamento concluído.',
  requestNotFound: 'Pedido de pareamento não encontrado.',
  declined: 'Pedido recusado.',
  notPaired: 'Você não está pareado com ninguém.',
};

@Injectable()
export class PairingService {
  /** Serializes accepts for the same pair inside this process. */
  private readonly acceptTails = new Map<string, Promise<void>>();

  /**
   * Request ids this process already accepted. A replay of one of these ids
   * is 201. Any other id, including a bogus one after the user is paired, is
   * 404 so a guessed id cannot look like success.
   */
  private readonly acceptedRequests = new Map<
    string,
    { userId: string; partnerId: string }
  >();

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
      throw new BadRequestException(copy.badFormat);
    }

    // Get the requester
    const requester = await this.prisma.user.findUnique({
      where: { id: requesterId },
    });

    if (!requester) {
      throw new NotFoundException(copy.userNotFound);
    }

    // Check if requester already has a partner
    if (requester.partnerId) {
      throw new ConflictException(copy.alreadyPaired);
    }

    // Check if user is trying to use their own code
    if (requester.pairingCode === normalizedCode) {
      throw new BadRequestException(copy.self);
    }

    // Find the target user by their pairing code
    const targetUser =
      await this.usersService.findByPairingCode(normalizedCode);

    if (!targetUser) {
      throw new NotFoundException(copy.codeNotFound);
    }

    // Check if target code is expired
    if (!this.usersService.isPairingCodeValid(targetUser)) {
      throw new BadRequestException(copy.expired);
    }

    // Check if target user already has a partner
    if (targetUser.partnerId) {
      throw new ConflictException(copy.partnerPaired);
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
      message: copy.pendingSent,
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
      throw new ConflictException(copy.alreadyPaired);
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
      throw new NotFoundException(copy.userNotFound);
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

    const ready = await this.usersService.ensurePairingCode(userId);
    const sent = user.pairingRequestsSent ?? [];

    if (sent.length > 0) {
      return {
        status: 'pending',
        pendingCode: sent[0].targetCode,
        pairingCode: ready.pairingCode,
        pairingCodeExpiresAt: ready.pairingCodeExpiresAt,
        message: copy.waiting,
      };
    }

    return {
      status: 'unpaired',
      pairingCode: ready.pairingCode,
      pairingCodeExpiresAt: ready.pairingCodeExpiresAt,
    };
  }

  /**
   * Requests whose target code is the caller's current pairing code.
   * The payload is id, time, and the requester's id and name. Never a code.
   */
  async listReceivedRequests(userId: string) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) {
      throw new NotFoundException(copy.userNotFound);
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
      const body = await this.prisma.$transaction(async (tx) => {
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
          throw new NotFoundException(copy.userNotFound);
        }

        const owned =
          !!request &&
          !!user.pairingCode &&
          request.targetCode === user.pairingCode;

        if (!owned) {
          const replay = this.replayAccept(userId, requestId, user);
          if (replay) return replay;
          throw new NotFoundException(copy.requestNotFound);
        }

        if (user.partnerId) {
          throw new ConflictException(copy.alreadyPaired);
        }

        const requester = await tx.user.findUnique({
          where: { id: request.requesterId },
        });
        if (!requester) {
          throw new NotFoundException(copy.requestNotFound);
        }
        if (requester.partnerId) {
          throw new ConflictException(copy.partnerPaired);
        }

        const paired = await applyPairing(tx, user.id, requester.id);
        return this.pairedBody(paired.partner);
      });
      if (body.partner) {
        this.acceptedRequests.set(requestId, {
          userId,
          partnerId: body.partner.id,
        });
      }
      return body;
    } catch (error) {
      if (!isUniqueViolation(error)) throw error;
      const user = await this.prisma.user.findUnique({
        where: { id: userId },
        include: { partner: { select: { id: true, name: true } } },
      });
      const replay = user ? this.replayAccept(userId, requestId, user) : null;
      if (replay) return replay;
      if (user?.partnerId && user.partner) {
        this.acceptedRequests.set(requestId, {
          userId,
          partnerId: user.partner.id,
        });
        return this.pairedBody({
          id: user.partner.id,
          name: user.partner.name,
        });
      }
      throw new ConflictException(copy.alreadyPaired);
    }
  }

  /**
   * 201 only when this process already accepted this exact id into the
   * caller's current pair. A bogus id stays 404 even if the caller is paired.
   */
  private replayAccept(
    userId: string,
    requestId: string,
    user: {
      partnerId: string | null;
      partner: { id: string; name: string | null } | null;
    },
  ): PairResponseDto | null {
    const remembered = this.acceptedRequests.get(requestId);
    if (!remembered || remembered.userId !== userId) return null;
    if (
      !user.partnerId ||
      user.partnerId !== remembered.partnerId ||
      !user.partner
    ) {
      return null;
    }
    return this.pairedBody({ id: user.partner.id, name: user.partner.name });
  }

  private pairedBody(partner: {
    id: string;
    name: string | null;
  }): PairResponseDto {
    return {
      status: PairingStatus.PAIRED,
      message: copy.paired,
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
      throw new ConflictException(copy.alreadyPaired);
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
    throw new ConflictException(copy.alreadyPaired);
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
      throw new NotFoundException(copy.userNotFound);
    }

    const request = await this.ownedRequest(user.pairingCode, requestId);
    if (user.partnerId) {
      throw new ConflictException(copy.alreadyPaired);
    }

    await this.prisma.pairingRequest.delete({ where: { id: request.id } });
    return { message: copy.declined };
  }

  private async ownedRequest(pairingCode: string | null, requestId: string) {
    const request = await this.prisma.pairingRequest.findUnique({
      where: { id: requestId },
    });
    if (!request || !pairingCode || request.targetCode !== pairingCode) {
      throw new NotFoundException(copy.requestNotFound);
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
      throw new NotFoundException(copy.userNotFound);
    }

    if (!user.partnerId) {
      throw new BadRequestException(copy.notPaired);
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
