# Date night com RSVP (Feature #5)

Depends on #1 (Couple), #2 (push, feed, scheduler), #3 (question of the day), and #4 (mood). Coder opens the PR only. Tech Manager merges on Tester PASS.

## What shipped

- `DatePlan` and `DatePlanStatus` (`PROPOSED`, `ACCEPTED`, `DECLINED`, `CANCELLED`, `DONE`, `EXPIRED`). Migration `20261006020000_add_date_plans`.
- `proposerId` is the current offer and changes on counter. `createdById` stays the original author. `scheduledAt` is stored in UTC.
- `sourceListItemId` is optional and has no foreign key. It must belong to a `MOVIES` or `TRAVEL` list of this couple (422 otherwise). Deleting the item leaves the date; the detail screen says "Item removido".
- `POST /date-plans` requires a future ISO-8601 `scheduledAt` with `Z` or a numeric offset. A past or naive value is 400. Success writes `DATE_PLAN_PROPOSED` and pushes the partner at `/dates/:id`.
- RSVP: `accept`, `decline` (note optional), `counter`, `cancel`, `done`. The role is checked first (403). The write is `updateMany` on the expected status; `count = 0` is 409.
- `done` is allowed only from `ACCEPTED` when `scheduledAt <= now + 2h`. Earlier than that is 422. Success sets `completedAt`.
- `GET /date-plans?scope=upcoming|past` — upcoming is `PROPOSED`/`ACCEPTED` with `scheduledAt >= now-2h` (ascending). Past is the complement (descending).
- `DatePlanGuard` on `:id` and every action. Another couple is 404.
- Every 10 minutes, on the existing scheduler: one reminder to both partners for an `ACCEPTED` date in `[now+1h50, now+2h10]` when `reminderSentAt` is null, then overdue `PROPOSED` rows become `EXPIRED` with no push. Push text uses the couple timezone. The reminder respects `NotificationPreference.datePlans`.
- Flutter module `date_plans`. Routes `/dates`, `/dates/new`, `/dates/:id`. Home card shows the next date or "Planejar um date". `MOVIES`/`TRAVEL` items have "Planejar date". Finishing a date that came from a list asks `Marcar '<filme>' como assistido?` and calls the existing `toggleItem`.

## How to run

```bash
# repo root
supabase start

cd couple2_backend
cp .env.example .env
# .env should keep PUSH_DRIVER=log
npm install
npx prisma migrate deploy
npm test
npm run dev
```

Pair two users with `POST /auth/dev-login` and `POST /pairing/pair`. Register a device with `POST /devices` if you want the log driver to print a push (`PUSH_DRIVER=log`).

```bash
# A proposes. scheduledAt must be in the future and include an offset.
curl -X POST http://localhost:3000/date-plans \
  -H "Authorization: Bearer $TOKEN_A" \
  -H "Content-Type: application/json" \
  -d '{"title":"Japonês","scheduledAt":"2026-10-09T20:00:00-03:00","location":"Centro"}'
```

The API log shows B's push. `GET /date-plans?scope=upcoming` with B's token lists it. B calls `POST /date-plans/:id/accept`.

## Tester checklist

1. A proposes a future date. B receives one push (`DATE_PLAN_PROPOSED`, route `/dates/:id`) and sees it under Próximos with Aceitar, Recusar, and Sugerir outro horário. A sees only Editar and Cancelar.
2. A calls `POST /date-plans/:id/accept` on that proposal. Response is 403. The status stays `PROPOSED`.
3. B calls `POST /date-plans/:id/counter` with a new future `scheduledAt`. `proposerId` becomes B, status stays `PROPOSED`, `scheduledAt` is the new time. A can accept. B's accept is 403.
4. While the date is `PROPOSED`, A calls cancel and B calls accept at the same time. Exactly one returns 200. The other returns 409. The row matches the winner.
5. An `ACCEPTED` date with `scheduledAt` about 2 hours ahead: run the 10-minute job (or call the scheduler's `run(now)` in a test). Each partner gets one reminder. Run the job again: no second push (`reminderSentAt` is set). The body clock is the couple timezone, not UTC.
6. A `PROPOSED` date whose `scheduledAt` is already past becomes `EXPIRED` on the next job run. No push. `GET /date-plans?scope=past` includes it. It is not in `upcoming`.
7. `POST /date-plans/:id/done` a day before `scheduledAt` returns 422. After `scheduledAt` (or within the 2 hours before it) the status is `DONE` and `completedAt` is set.
8. `sourceListItemId` from another couple, or from a `SHOPPING_CART` list, returns 422 and does not create a row. A `MOVIES` or `TRAVEL` item of this couple is accepted.
9. `POST /date-plans` with `scheduledAt` in the past, or without a timezone offset, returns 400.
10. A user from another couple gets 404 on `GET /date-plans/:id` and on accept, decline, counter, cancel, done, and PATCH. The response does not reveal the date.
