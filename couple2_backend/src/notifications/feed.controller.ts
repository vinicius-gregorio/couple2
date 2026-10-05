import { Controller, Get, Post, Query, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards';
import { GetUser } from '../auth/decorators';
import type { UserWithPartner } from '../auth/strategies/jwt.strategy';
import { CoupleGuard } from '../couple/guards/couple.guard';
import { FeedQueryDto } from './dto/feed-query.dto';
import { FeedService } from './feed.service';

@Controller('feed')
@UseGuards(JwtAuthGuard, CoupleGuard)
export class FeedController {
  constructor(private readonly feed: FeedService) {}

  @Get('unread-count')
  unreadCount(@GetUser() user: UserWithPartner) {
    return this.feed.unreadCount(user);
  }

  @Post('seen')
  seen(@GetUser() user: UserWithPartner) {
    return this.feed.markSeen(user.id);
  }

  @Get()
  list(@GetUser() user: UserWithPartner, @Query() query: FeedQueryDto) {
    return this.feed.list(user, query);
  }
}
