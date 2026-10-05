# Gift ideas ocultas (Feature #6)

Depends on #1 (coupleId, `SharedListItemGuard`, `CoupleGuard`) and #2 (activity feed, push prefs, the 09:00 important-dates job). Coder opens the PR only. Do not merge.

## What shipped

- `ListType.GIFT_IDEAS` and `ListVisibility` (`SHARED`, `PRIVATE_FROM_PARTNER`). `PartnerList.visibility` defaults to `SHARED`, so every list that already existed stays shared. Index `@@index([coupleId, visibility])`.
- `ALTER TYPE "ListType" ADD VALUE 'GIFT_IDEAS'` is its own migration (`20261006030000`). Postgres cannot use a new enum value in the transaction that adds it, and Prisma wraps each migration in a transaction. The column lands in `20261006040000`.
- `PRIVATE_FROM_PARTNER` is only valid with `GIFT_IDEAS`. A gift list created without `visibility` is private. Visibility cannot be changed later.
- `listAccessWhere(user)` is the only visibility filter. `ListsService.getLists` / `getList`, `SharedListGuard`, and `SharedListItemGuard` all use it. A partner hitting a private list gets **404**, never 403.
- Gift item metadata: `price` ≥ 0, `currency` `BRL`, `url` http/https only, `occasion` `BIRTHDAY|ANNIVERSARY|CHRISTMAS|VALENTINES|OTHER`, `coupleDateId`, `status` `IDEA|BOUGHT`. `isCompleted` means delivered. Invalid metadata is 400.
- Private lists write no `ActivityEvent` and no partner push. A shared gift list (wishlist) records and pushes like any other shared list.
- The 09:00 important-dates job sends `GIFT_REMINDER` at D-14 of the partner's birthday or the couple anniversary. Push only, to the owner who still has undelivered private ideas. No feed row. Respects `prefs.importantDates` (and the master switch and quiet hours). The lock-screen text does not include the gift name or the list name. A `gift_reminder_dispatches` row claims the send so a second run the same morning does not push again.
- Flutter lists: type "Ideias de presente" 🎁, switch "Esconder de <parceiro>" default on, section "Minhas listas privadas" with 🔒 "Só você vê", item fields for price, link, and occasion, `url_launcher` for http/https links. Logout invalidates `listsViewModelProvider` after `prefs.clear()`.

Unpair leaves the private list on the ENDED couple. Neither partner can read it after that, same as #1.

Any new endpoint that lists `PartnerList` or `ListItem` (search, export, a home count) has to call `listAccessWhere`. That is the review check for this feature.

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
npm run test:e2e
npm run dev
```

```bash
cd couple2_app
flutter pub get
```

Pair two users with `POST /auth/dev-login` and `POST /pairing/pair`. Register a device with `POST /devices` if you want the log driver to print a push.

```bash
# A creates a hidden gift list. visibility is omitted, so it is private.
curl -X POST http://localhost:3000/lists \
  -H "Authorization: Bearer $TOKEN_A" \
  -H "Content-Type: application/json" \
  -d '{"type":"GIFT_IDEAS","name":"Para Bia"}'

curl -X POST http://localhost:3000/lists/$LIST_ID/items \
  -H "Authorization: Bearer $TOKEN_A" \
  -H "Content-Type: application/json" \
  -d '{"content":"Pulseira","metadata":{"price":120,"currency":"BRL","url":"https://example.com/pulseira","occasion":"BIRTHDAY","status":"IDEA"}}'
```

`GET /lists` with B's token does not contain that list. The API log stays quiet: no push, and `activity_events` has no row for it.

A shared wishlist is the same call with `"visibility":"SHARED"`. B sees it, and creating it writes `LIST_CREATED`.

To exercise the reminder, set B's `birthDate` to 14 days from today in the couple timezone, give A at least one undelivered private idea and an iOS/Android device token, then run the important-dates job at 09:00 local (or call `UpcomingRemindersService.run(now)` in a test). The body looks like `Aniversário de Bia em 14 dias — você tem 2 ideias anotadas`.

## Tester checklist

1. A creates `GIFT_IDEAS` without `visibility`. The list is `PRIVATE_FROM_PARTNER`, `ownerId` is A, and `coupleId` is the active couple.
2. B's `GET /lists` has no trace of A's private list: not the id, not the name, not the item count or item text.
3. As B, `GET /lists/:id`, `POST /lists/:id/items`, `DELETE /lists/:id`, `PATCH /lists/items/:itemId`, and `DELETE /lists/items/:itemId` for A's private list are all **404**. The body does not contain the list name or the gift name. The row is unchanged.
4. A adds an item and marks it delivered on the private list. `activity_events` gains no row for that couple, and B's device receives no push. B's feed does not show the gift.
5. `POST /lists` with `type=MOVIES` and `visibility=PRIVATE_FROM_PARTNER` returns 400. No row is created.
6. B creates `GIFT_IDEAS` with `visibility=SHARED`. A sees it on `GET /lists`. Creating it and adding an item write feed events (`LIST_CREATED`, `LIST_ITEM_ADDED`) and can push A.
7. An item with `url: "javascript:..."` or `price: -1` returns 400. A valid `https` url and `price: 0` are stored. `status` other than `IDEA` or `BOUGHT` is 400.
8. B's birthday is 14 days away and A has 2 undelivered private ideas (a bought-but-not-delivered item still counts; a delivered item does not). At 09:00 in the couple timezone the job sends one push to A and nothing to B. The title and body do not contain the gift name or the list name. A second run the same morning does not send again. No `ActivityEvent`. If A has no undelivered ideas, nobody gets a gift push. With `importantDates` off, A gets no push. The couple anniversary at D-14 uses the same rule and says "Aniversário de namoro", still without the gift name.
9. After the migration, existing lists are `SHARED`. `SHOPPING_CART`, `MOVIES`, `MILESTONES`, and `TRAVEL` still show up for the partner, and add/complete still write the usual feed events.
10. The e2e leak suite calls every `/lists` route as the partner (`GET /lists`, `POST /lists`, `GET /lists/:id`, `POST /lists/:id/items`, `PATCH /lists/items/:id`, `DELETE /lists/items/:id`, `DELETE /lists/:id`) and none of the responses contain the private list id, name, or gift text.
