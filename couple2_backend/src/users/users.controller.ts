import { Body, Controller, Patch, UseGuards } from '@nestjs/common';
import { GetUser } from '../auth/decorators';
import { JwtAuthGuard } from '../auth/guards';
import type { UserWithPartner } from '../auth/strategies/jwt.strategy';
import { UpdateMeDto } from './dto/update-me.dto';
import { UsersService } from './users.service';

@Controller('users')
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  /**
   * PATCH /users/me
   * The authenticated user is the only one who can change their own profile.
   */
  @Patch('me')
  @UseGuards(JwtAuthGuard)
  updateMe(@GetUser() user: UserWithPartner, @Body() dto: UpdateMeDto) {
    return this.usersService.updateMe(user.id, dto);
  }
}
