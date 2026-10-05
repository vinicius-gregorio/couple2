import { ListType } from '@prisma/client';

export class CreateListDto {
  type: ListType;
  name: string;
}
