import {
  Body,
  Controller,
  Delete,
  HttpCode,
  Param,
  Post,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards';
import { GetUser } from '../auth/decorators';
import type { UserWithPartner } from '../auth/strategies/jwt.strategy';
import { DevicesService } from './devices.service';
import { RegisterDeviceDto } from './dto/register-device.dto';

@Controller('devices')
@UseGuards(JwtAuthGuard)
export class DevicesController {
  constructor(private readonly devices: DevicesService) {}

  @Post()
  @HttpCode(200)
  register(@GetUser() user: UserWithPartner, @Body() dto: RegisterDeviceDto) {
    return this.devices.register(user.id, dto);
  }

  @Delete(':token')
  @HttpCode(204)
  async remove(
    @GetUser() user: UserWithPartner,
    @Param('token') token: string,
  ): Promise<void> {
    await this.devices.remove(user.id, token);
  }
}
