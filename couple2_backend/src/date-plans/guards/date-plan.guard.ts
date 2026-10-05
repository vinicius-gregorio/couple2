import {
  CanActivate,
  ExecutionContext,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import type { DatePlan } from '@prisma/client';
import type { UserWithPartner } from '../../auth/strategies/jwt.strategy';
import { PrismaService } from '../../prisma';

interface RequestWithDatePlan {
  user: UserWithPartner;
  params: { id: string };
  datePlan?: DatePlan;
}

/**
 * Resolves params.id to a DatePlan in the caller's couple.
 * A missing plan and a plan from another couple are both 404.
 * Attaches the row as request.datePlan.
 */
@Injectable()
export class DatePlanGuard implements CanActivate {
  constructor(private readonly prisma: PrismaService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest<RequestWithDatePlan>();
    const user = request.user;
    const id = request.params.id;

    const plan = id
      ? await this.prisma.datePlan.findUnique({ where: { id } })
      : null;

    if (!plan || !user?.coupleId || plan.coupleId !== user.coupleId) {
      throw new NotFoundException('Date plan not found');
    }

    request.datePlan = plan;
    return true;
  }
}
