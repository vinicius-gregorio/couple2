import 'dotenv/config';
import { Module } from '@nestjs/common';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { PrismaModule } from './prisma';
import { UsersModule } from './users';
import { AuthModule } from './auth';
import { PairingModule } from './pairing';
import { ListsModule } from './lists/lists.module';
import { CoupleModule } from './couple/couple.module';

@Module({
  imports: [
    PrismaModule,
    UsersModule,
    AuthModule,
    PairingModule,
    ListsModule,
    CoupleModule,
  ],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}
