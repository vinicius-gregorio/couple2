import { ActivityType } from '@prisma/client';

export interface PushCopy {
  title: string;
  body: string;
}

export function buildPushCopy(input: {
  type: ActivityType;
  actorName: string | null;
  payload: Record<string, unknown>;
}): PushCopy {
  const actor = input.actorName?.trim() || 'Parceiro';
  const listName = text(input.payload.listName) || 'uma lista';
  const content = text(input.payload.content);
  const title = text(input.payload.title) || 'Data importante';
  const inDays = numberOrNull(input.payload.inDays);

  switch (input.type) {
    case ActivityType.LIST_CREATED:
      return { title: 'Nova lista', body: `${actor} criou "${listName}"` };
    case ActivityType.LIST_ITEM_ADDED:
      return {
        title: listName,
        body: content
          ? `${actor} adicionou "${content}"`
          : `${actor} adicionou um item`,
      };
    case ActivityType.LIST_ITEM_COMPLETED:
      return {
        title: listName,
        body: content
          ? `${actor} concluiu "${content}"`
          : `${actor} concluiu um item`,
      };
    case ActivityType.COUPLE_DATE_UPCOMING:
      return {
        title: 'Data importante',
        body: `${title} ${whenLabel(inDays)}`,
      };
    case ActivityType.QUESTION_ANSWERED:
      return {
        title: 'Pergunta do dia',
        body: `${actor} respondeu. Responda para ver.`,
      };
    case ActivityType.QUESTION_UNLOCKED:
      return {
        title: 'Pergunta desbloqueada',
        body: `Desbloqueada! Veja a resposta de ${actor}.`,
      };
    default:
      return {
        title: 'Couple',
        body: input.actorName
          ? `${actor} fez uma atualização`
          : 'Tem novidade no casal',
      };
  }
}

function whenLabel(inDays: number | null): string {
  if (inDays === 0) return 'é hoje';
  if (inDays === 1) return 'é amanhã';
  if (inDays != null) return `é em ${inDays} dias`;
  return 'está chegando';
}

function text(value: unknown): string {
  return typeof value === 'string' ? value.trim() : '';
}

function numberOrNull(value: unknown): number | null {
  return typeof value === 'number' && Number.isFinite(value) ? value : null;
}
