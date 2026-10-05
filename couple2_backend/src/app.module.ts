import { Module } from '@nestjs/common';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { PrismaModule } from './prisma';
import { UsersModule } from './users';
import { AuthModule } from './auth';
import { PairingModule } from './pairing';
import { ListsModule } from './lists/lists.module';

@Module({
  imports: [PrismaModule, UsersModule, AuthModule, PairingModule, ListsModule],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}
