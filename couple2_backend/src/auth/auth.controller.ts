import {
  Body,
  Controller,
  Get,
  Post,
  UseGuards,
  ForbiddenException,
} from '@nestjs/common';
import { IsEmail, IsOptional, IsString } from 'class-validator';
import { AuthService } from './auth.service';
import { FirebaseLoginDto, AuthResponseDto } from './dto';
import { JwtAuthGuard } from './guards';
import { GetUser } from './decorators';
import type { UserWithPartner } from './strategies/jwt.strategy';
import { toDateOnlyString } from '../common/calendar-date';

class DevLoginDto {
  @IsEmail()
  email: string;

  @IsOptional()
  @IsString()
  name?: string;
}

@Controller('auth')
export class AuthController {
  constructor(private authService: AuthService) {}

  /**
   * POST /auth/firebase
   * Login with a Firebase ID token (Google or Apple, both via Firebase Auth).
   */
  @Post('firebase')
  async firebaseLogin(@Body() dto: FirebaseLoginDto): Promise<AuthResponseDto> {
    return this.authService.firebaseLogin(dto.idToken);
  }

  /**
   * POST /auth/dev-login
   * Development-only endpoint for testing without real social tokens.
   * DO NOT use in production!
   */
  @Post('dev-login')
  async devLogin(@Body() dto: DevLoginDto): Promise<AuthResponseDto> {
    if (process.env.NODE_ENV === 'production') {
      throw new ForbiddenException('Not available in production');
    }
    return this.authService.devLogin(dto.email, dto.name);
  }

  /**
   * GET /auth/me
   * Returns the current user's session info including:
   * - User profile
   * - Pairing code (if unpaired)
   * - Partner info (if paired)
   */
  @UseGuards(JwtAuthGuard)
  @Get('me')
  getSession(@GetUser() user: UserWithPartner) {
    const isPaired = !!user.partnerId;

    return {
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
        picture: user.picture,
        createdAt: user.createdAt,
        coupleId: user.coupleId,
        birthDate: toDateOnlyString(user.birthDate),
      },
      pairing: {
        isPaired,
        // Only include pairing code if user is not paired
        ...(isPaired
          ? {}
          : {
              pairingCode: user.pairingCode,
              pairingCodeExpiresAt: user.pairingCodeExpiresAt,
            }),
      },
      // Only include partner info if user is paired
      partner: isPaired
        ? {
            id: user.partner!.id,
            name: user.partner!.name,
            email: user.partner!.email,
            picture: user.partner!.picture,
          }
        : null,
    };
  }
}
