import {
  Injectable,
  BadRequestException,
  NotFoundException,
  ConflictException,
} from '@nestjs/common';
import { PrismaService } from '../prisma';
import { UsersService } from '../users';
import { PairResponseDto, PairingStatus } from './dto';

@Injectable()
export class PairingService {
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
   * Sets partner references, clears pairing codes, and deletes pairing requests.
   */
  private async completePairing(
    userAId: string,
    userBId: string,
  ): Promise<PairResponseDto> {
    // Use a transaction to ensure atomicity
    const [, userB] = await this.prisma.$transaction(async (tx) => {
      // Set User A's partner to User B
      const updatedUserA = await tx.user.update({
        where: { id: userAId },
        data: {
          partnerId: userBId,
          pairingCode: null,
          pairingCodeExpiresAt: null,
        },
      });

      // Set User B's partner to User A
      const updatedUserB = await tx.user.update({
        where: { id: userBId },
        data: {
          partnerId: userAId,
          pairingCode: null,
          pairingCodeExpiresAt: null,
        },
      });

      // Delete all pairing requests from both users
      await tx.pairingRequest.deleteMany({
        where: {
          OR: [{ requesterId: userAId }, { requesterId: userBId }],
        },
      });

      return [updatedUserA, updatedUserB];
    });

    return {
      status: PairingStatus.PAIRED,
      message: 'Successfully paired with your partner!',
      partner: {
        id: userB.id,
        name: userB.name,
      },
    };
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
        message: 'Waiting for your partner to enter your code',
      };
    }

    return {
      status: 'unpaired',
      pairingCode: user.pairingCode,
      pairingCodeExpiresAt: user.pairingCodeExpiresAt,
    };
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

    // Use transaction to unpair both users
    await this.prisma.$transaction(async (tx) => {
      // Clear User A's partner
      await tx.user.update({
        where: { id: userId },
        data: { partnerId: null },
      });

      // Clear User B's partner
      await tx.user.update({
        where: { id: partnerId },
        data: { partnerId: null },
      });
    });

    // Generate new pairing codes for both users
    await this.usersService.ensurePairingCode(userId);
    await this.usersService.ensurePairingCode(partnerId);
  }
}
