import { Injectable } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { PrismaService } from '../prisma';
import { UsersService } from '../users';
import { FirebaseAuthStrategy, FirebaseUser } from './strategies/firebase.strategy';
import { AuthResponseDto } from './dto';

@Injectable()
export class AuthService {
  constructor(
    private prisma: PrismaService,
    private jwtService: JwtService,
    private usersService: UsersService,
    private firebaseStrategy: FirebaseAuthStrategy,
  ) { }

  async firebaseLogin(idToken: string): Promise<AuthResponseDto> {
    const firebaseUser = await this.firebaseStrategy.validateIdToken(idToken);
    const user = await this.findOrCreateFirebaseUser(firebaseUser);
    return await this.generateAuthResponse(user);
  }

  private async findOrCreateFirebaseUser(firebaseUser: FirebaseUser) {
    // Check if user exists by firebaseUid
    let user = await this.prisma.user.findUnique({
      where: { firebaseUid: firebaseUser.firebaseUid },
    });

    if (user) {
      // Update name/picture on each login (in case user changed it)
      return this.prisma.user.update({
        where: { id: user.id },
        data: {
          name: firebaseUser.name ?? user.name,
          picture: firebaseUser.picture ?? user.picture,
        },
      });
    }

    // Check if user exists by email (e.g. registered before Firebase migration)
    user = await this.prisma.user.findUnique({
      where: { email: firebaseUser.email },
    });

    if (user) {
      // Link Firebase account to existing user
      return this.prisma.user.update({
        where: { id: user.id },
        data: {
          firebaseUid: firebaseUser.firebaseUid,
          name: firebaseUser.name ?? user.name,
          picture: firebaseUser.picture ?? user.picture,
        },
      });
    }

    // Create new user
    return this.prisma.user.create({
      data: {
        email: firebaseUser.email,
        name: firebaseUser.name,
        picture: firebaseUser.picture,
        firebaseUid: firebaseUser.firebaseUid,
      },
    });
  }

  private async generateAuthResponse(user: {
    id: string;
    email: string;
    name: string | null;
    picture: string | null;
    partnerId: string | null;
    pairingCode: string | null;
    pairingCodeExpiresAt: Date | null;
  }): Promise<AuthResponseDto> {
    // Ensure user has a valid pairing code if they don't have a partner
    let finalUser = user;
    if (!user.partnerId) {
      finalUser = await this.usersService.ensurePairingCode(user.id);
    }

    const payload = { sub: finalUser.id, email: finalUser.email };
    const accessToken = this.jwtService.sign(payload);

    return {
      accessToken,
      user: {
        id: finalUser.id,
        email: finalUser.email,
        name: finalUser.name,
        picture: finalUser.picture,
        partnerId: finalUser.partnerId,
        pairingCode: finalUser.pairingCode,
        pairingCodeExpiresAt: finalUser.pairingCodeExpiresAt,
      },
    };
  }

  async validateUser(userId: string) {
    return this.prisma.user.findUnique({
      where: { id: userId },
    });
  }

  /**
   * Development-only login method.
   * Creates or finds a user by email without social auth validation.
   */
  async devLogin(email: string, name?: string): Promise<AuthResponseDto> {
    let user = await this.prisma.user.findUnique({
      where: { email },
    });

    if (!user) {
      user = await this.prisma.user.create({
        data: { email, name },
      });
    }

    return await this.generateAuthResponse(user);
  }
}
