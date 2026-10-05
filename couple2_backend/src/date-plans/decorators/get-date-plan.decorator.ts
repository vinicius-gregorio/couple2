import { createParamDecorator, ExecutionContext } from '@nestjs/common';
import type { DatePlan } from '@prisma/client';

interface RequestWithDatePlan {
  datePlan?: DatePlan;
}

/** Date plan loaded by DatePlanGuard. The service still re-reads before writing. */
export const GetDatePlan = createParamDecorator(
  (data: unknown, ctx: ExecutionContext): DatePlan => {
    const request = ctx.switchToHttp().getRequest<RequestWithDatePlan>();
    return request.datePlan as DatePlan;
  },
);
