# Pergunta do dia (Feature #3)

Depends on #1 (Couple) and #2 (Activity/Push), already on main.
Coder opens the PR only. Tech Manager merges on Tester PASS.

## What shipped

- `Question`, `CoupleQuestion`, `QuestionAnswer` plus `QuestionCategory` (`FUN`, `DEEP`, `MEMORIES`, `FUTURE`, `DAILY_LIFE`).
- Prisma migration `20261005230000_add_daily_question` creates the tables and seeds 140 pt-BR questions with `INSERT ... ON CONFLICT ("slug") DO NOTHING`. Not `supabase/seed.sql`.
- `GET /questions/today` lazy-assigns one question per couple per local day. A unique clash on `(coupleId, date)` is re-read (`P2002`), so two partners racing still share one row.
- `POST /questions/:coupleQuestionId/answer` upserts the caller's text (1–1000). Outside the 7-day window → 422. After unlock → 409. The second answer sets `unlockedAt` in the same transaction, then `QUESTION_UNLOCKED` pushes the partner who answered first. The first answer emits `QUESTION_ANSWERED` and pushes "Responda para ver."
- `GET /questions/history` is a date-desc cursor page. Partner `text` is selected only when `unlockedAt` is not null. The response omits `partnerAnswer` while locked.
- The existing hourly scheduler also runs at 10:00 in the couple timezone: creates today's question and sends one `dailyQuestion` push (`route: /question`). `dailyNotifiedAt` stops a second push the same morning. No device → the row is still created.
- `DEEP` is left out of the draw when the couple got one in the last 7 days. The bank has 124 non-DEEP questions, so 120 consecutive days do not need a repeat.
- When every active question has been used, the service assigns the least-recent one, returns 200, and logs a warning.
- Flutter module `daily_question`: Today (`/question`) and History (`/question/history`). Home card has the three states. The answer field shows a 1000-character counter and Enviar/Editar until unlock, then both answers side by side.

## Schema note (acceptance criterion 6)

The spec model includes `@@unique([coupleId, questionId])`. That constraint makes the exhaustion fallback impossible: today's new row would collide with the old assignment. The column pair is indexed instead. The service still refuses a repeat until the active bank is empty.

`dailyNotifiedAt` is an extra nullable timestamp so the 10:00 job is idempotent. It is not an activity type; the arrival push does not write a feed row.

## How to run

```bash
# repo root
supabase start

cd couple2_backend
cp .env.example .env
npm install
npx prisma migrate deploy
npm test
npm run dev
```

`PUSH_DRIVER=log` prints the daily, answered, and unlocked pushes. Pair two users with `POST /auth/dev-login` and `POST /pairing/pair`, then `GET /questions/today` with either JWT.

```bash
cd couple2_app
flutter pub get
flutter test
flutter run
```

Home (paired) shows the question card. `/question` answers today. `/question/history` lists past days. A push tap with `route: /question` opens today.

## Tester checklist

1. **One shared question.** Two concurrent `GET /questions/today` calls, one per partner → a single `couple_questions` row and the same `id` / question text. Covered by `QuestionsService` "gives both partners one shared question".
2. **No partner text while locked.** After A answers, A's today payload has `partnerAnswered=false` and no `partnerAnswer`. B's payload has `partnerAnswered=true` and still no `partnerAnswer` and does not contain A's text. History for B selects answer text only where `userId` is B.
3. **Unlock.** B answers → `unlockedAt` is set, both payloads include both texts, the feed row is `QUESTION_UNLOCKED` with actor B (so the push goes to A), and the copy contains "Desbloqueada".
4. **Edit window.** A second `POST` from A before B answers returns the updated `updatedAt`. After unlock the same `POST` is 409.
5. **Seven days.** A question dated 8 days before the couple's today is 422. One dated 6 days before is 200, and the second answer still unlocks it. The day exactly 7 days ago is still inside the window (`date < today-7`).
6. **No repeat, then fallback.** 120 questions over 120 days are unique (`chooseQuestion` spec). On day 121 the choice is the least-recent question, `fallback` is true, and the service logs `active question bank exhausted`. The seed has 140 questions (124 non-DEEP), so a real couple does not hit the fallback inside 120 days. `DEEP` is excluded for 7 days after the last one.
7. **Midnight.** `2026-10-06T02:59:00Z` and `2026-10-06T03:01:00Z` in `America/Sao_Paulo` are `2026-10-05` and `2026-10-06`, and `GET /questions/today` returns two different questions.
8. **Other couple.** `POST /questions/:id/answer` with another couple's id is 404.
9. **Seed twice.** `prisma/migrations/20261005230000_add_daily_question/migration.sql` uses `ON CONFLICT ("slug") DO NOTHING`, slugs are unique, and there is no `DELETE` of `questions`. Running that `INSERT` again does not add rows.

Out of scope: custom couple questions, reactions, audio/photo, admin UI, features #4–#6.
