import { Body, Controller, Get, Patch, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards';
import { GetUser } from '../auth/decorators';
import type { UserWithPartner } from '../auth/strategies/jwt.strategy';
import { UpdateNotificationPreferencesDto } from './dto/update-notification-preferences.dto';
import { NotificationPreferencesService } from './preferences.service';

@Controller('notifications/preferences')
@UseGuards(JwtAuthGuard)
export class NotificationPreferencesController {
  constructor(private readonly preferences: NotificationPreferencesService) {}

  @Get()
  get(@GetUser() user: UserWithPartner) {
    return this.preferences.getOrCreate(user.id);
  }

  @Patch()
  update(
    @GetUser() user: UserWithPartner,
    @Body() dto: UpdateNotificationPreferencesDto,
  ) {
    return this.preferences.update(user.id, dto);
  }
}
