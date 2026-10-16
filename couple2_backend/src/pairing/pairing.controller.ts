import {
  Controller,
  Post,
  Get,
  Delete,
  Body,
  Param,
  UseGuards,
} from '@nestjs/common';
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
   * POST /pairing/code
   * Returns the current user's pairing code, creating one when it is missing
   * or expired. Login and unpair already do this; this recovers a code
   * without signing out.
   */
  @Post('code')
  async ensureCode(@GetUser() user: UserWithPartner) {
    return this.pairingService.ensureOwnPairingCode(user.id);
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
   * GET /pairing/requests/received
   * Requests other people sent to the caller. No pairing code is included.
   */
  @Get('requests/received')
  async received(@GetUser() user: UserWithPartner) {
    return this.pairingService.listReceivedRequests(user.id);
  }

  /**
   * POST /pairing/requests/:id/accept
   * Completes pairing for a request that targets the caller's own code.
   */
  @Post('requests/:id/accept')
  async acceptReceived(
    @GetUser() user: UserWithPartner,
    @Param('id') id: string,
  ) {
    return this.pairingService.acceptReceivedRequest(user.id, id);
  }

  /**
   * POST /pairing/requests/:id/decline
   * Deletes a request that targets the caller's own code.
   */
  @Post('requests/:id/decline')
  async declineReceived(
    @GetUser() user: UserWithPartner,
    @Param('id') id: string,
  ) {
    return this.pairingService.declineReceivedRequest(user.id, id);
  }

  /**
   * DELETE /pairing/request
   * Cancels any pending pairing request.
   */
  @Delete('request')
  async cancelRequest(@GetUser() user: UserWithPartner) {
    await this.pairingService.cancelPairingRequest(user.id);
    return { message: 'Pedido cancelado' };
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
    return { message: 'Pareamento desfeito' };
  }
}
