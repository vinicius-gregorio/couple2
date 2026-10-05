import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma';
import { CreateUserDto } from './dto/create-user.dto';

const PAIRING_CODE_TTL_DAYS = 30;
const PAIRING_CODE_LENGTH = 6;
const PAIRING_CODE_CHARS = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // Excluded O, 0, I, 1 for clarity

@Injectable()
export class UsersService {
  constructor(private prisma: PrismaService) {}

  async create(data: CreateUserDto) {
    return this.prisma.user.create({
      data,
    });
  }

  async findAll() {
    return this.prisma.user.findMany();
  }

  async findOne(id: string) {
    return this.prisma.user.findUnique({
      where: { id },
    });
  }

  async findByEmail(email: string) {
    return this.prisma.user.findUnique({
      where: { email },
    });
  }

  async findByPairingCode(code: string) {
    const upperCode = code.toUpperCase();
    return this.prisma.user.findUnique({
      where: { pairingCode: upperCode },
    });
  }

  /**
   * Generates a unique 6-character alphanumeric pairing code.
   * Retries if the generated code already exists.
   */
  private generatePairingCode(): string {
    let code = '';
    for (let i = 0; i < PAIRING_CODE_LENGTH; i++) {
      const randomIndex = Math.floor(Math.random() * PAIRING_CODE_CHARS.length);
      code += PAIRING_CODE_CHARS[randomIndex];
    }
    return code;
  }

  /**
   * Creates a new pairing code for a user.
   * Sets expiration to 30 days from now.
   */
  async generatePairingCodeForUser(userId: string) {
    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + PAIRING_CODE_TTL_DAYS);

    // Try to generate a unique code (retry if collision)
    let attempts = 0;
    const maxAttempts = 10;

    while (attempts < maxAttempts) {
      const code = this.generatePairingCode();

      try {
        const user = await this.prisma.user.update({
          where: { id: userId },
          data: {
            pairingCode: code,
            pairingCodeExpiresAt: expiresAt,
          },
        });
        return user;
      } catch (error: unknown) {
        // Pairing codes are unique; retry when Postgres rejects a collision.
        const uniqueViolation =
          (error instanceof Prisma.PrismaClientKnownRequestError &&
            error.code === 'P2002') ||
          (error instanceof Error &&
            error.message.includes('Unique constraint'));
        if (uniqueViolation) {
          attempts++;
          continue;
        }
        throw error;
      }
    }

    throw new Error(
      'Failed to generate unique pairing code after max attempts',
    );
  }

  /**
   * Checks if the user's pairing code is valid (exists and not expired).
   */
  isPairingCodeValid(user: {
    pairingCode: string | null;
    pairingCodeExpiresAt: Date | null;
  }): boolean {
    if (!user.pairingCode || !user.pairingCodeExpiresAt) {
      return false;
    }
    return new Date() < user.pairingCodeExpiresAt;
  }

  /**
   * Ensures a user has a valid pairing code.
   * Generates a new one if missing or expired.
   * Only applies to users without a partner.
   */
  async ensurePairingCode(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
    });

    if (!user) {
      throw new Error('User not found');
    }

    // User already has a partner, no need for pairing code
    if (user.partnerId) {
      return user;
    }

    // Check if current pairing code is valid
    if (this.isPairingCodeValid(user)) {
      return user;
    }

    // Generate new pairing code
    return this.generatePairingCodeForUser(userId);
  }

  /**
   * Clears the pairing code for a user (e.g., after successful pairing).
   */
  async clearPairingCode(userId: string) {
    return this.prisma.user.update({
      where: { id: userId },
      data: {
        pairingCode: null,
        pairingCodeExpiresAt: null,
      },
    });
  }
}
