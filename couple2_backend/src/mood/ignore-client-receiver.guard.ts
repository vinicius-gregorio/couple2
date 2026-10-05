import { CanActivate, ExecutionContext, Injectable } from '@nestjs/common';
import { stripClientReceiverId } from './strip-receiver';

@Injectable()
export class IgnoreClientReceiverGuard implements CanActivate {
  canActivate(context: ExecutionContext): boolean {
    const request = context.switchToHttp().getRequest<{ body?: unknown }>();
    stripClientReceiverId(request.body);
    return true;
  }
}
