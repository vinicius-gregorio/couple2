import { Controller, Post, Get, Delete, Body, UseGuards } from '@nestjs/common';
import { PairingService } from './pairing.service';
import { PairRequestDto, PairResponseDto } from './dto';
import { JwtAuthGuard, PairingGuard } from '../auth/guards';
import { GetUser } from '../auth/decorators';
import type { UserWithPartner } from '../auth/strategies/jwt.strategy';

@Controller('pairing')
@UseGuards(JwtAuthGuard)
export class PairingController {
  constructor(private pairingService: PairingService) {}

  /**
   * POST /pairing/pair
   * Initiates or completes a pairing request.
   */
  @Post('pair')
  async pair(
    @GetUser() user: UserWithPartner,
    @Body() dto: PairRequestDto,
  ): Promise<PairResponseDto> {
    return this.pairingService.requestPairing(user.id, dto.code);
  }

  /**
   * GET /pairing/status
   * Gets the current pairing status for the authenticated user.
   */
  @Get('status')
  async getStatus(@GetUser() user: UserWithPartner) {
    return this.pairingService.getPairingStatus(user.id);
  }

  /**
   * DELETE /pairing/request
   * Cancels any pending pairing request.
   */
  @Delete('request')
  async cancelRequest(@GetUser() user: UserWithPartner) {
    await this.pairingService.cancelPairingRequest(user.id);
    return { message: 'Pairing request cancelled' };
  }

  /**
   * DELETE /pairing/unpair
   * Dissolves an existing partnership.
   * Requires user to be paired (PairingGuard).
   */
  @UseGuards(PairingGuard)
  @Delete('unpair')
  async unpair(@GetUser() user: UserWithPartner) {
    await this.pairingService.unpair(user.id);
    return { message: 'Successfully unpaired' };
  }
}
