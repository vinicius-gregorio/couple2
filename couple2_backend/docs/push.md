# Push and activity feed

`PUSH_DRIVER` chooses the transport:

| Value | When | What happens |
|---|---|---|
| `log` | Default in development. Also used when no Firebase service account is configured, even if `PUSH_DRIVER=fcm` | `LogPushSender` prints the title, body, `data.type`, and `data.route`. FCM is not called |
| `fcm` | Production, with `FIREBASE_SERVICE_ACCOUNT` (or `serviceAccount.json`) | `FcmPushSender` calls `admin.messaging().sendEachForMulticast` via `ensureFirebase()` |

```bash
cd couple2_backend
cp .env.example .env
# .env already has PUSH_DRIVER=log
npm install
npx prisma migrate deploy
npm run dev
```

Create two users with `POST /auth/dev-login`, pair them, `POST /devices` for one of them, then have the other complete a list item. The API log shows the push. `GET /feed` returns the event for both partners. The author is not a recipient.

FCM credentials are the same service account used for `verifyIdToken` (Firebase project `couple42-27692`). The key needs the `firebasecloudmessaging` IAM role. iOS delivery also needs the APNs authentication key uploaded in that Firebase project. The app enables Push and the `remote-notification` background mode, and Android 13+ uses `POST_NOTIFICATIONS`. The app asks for permission only after pairing.

Invalid FCM responses `messaging/registration-token-not-registered` and `messaging/invalid-argument` delete that row from `device_tokens` during the same send.

Quiet hours use the couple timezone. `quietStartMin=1380` and `quietEndMin=420` is 23:00–07:00. Inside that window the event is stored and no push is sent. List pushes are also capped at one per list per recipient per 5 minutes.

The hourly scheduler sends `COUPLE_DATE_UPCOMING` at 09:00 local time for dates that are 7, 1, or 0 days away (anniversary, both birthdays, custom couple dates). The same occurrence is not inserted twice.

The same hourly scheduler creates today's question at 10:00 local time and sends one push with `data.type=DAILY_QUESTION` and `data.route=/question` ("A pergunta de hoje chegou"). It respects `dailyQuestion`, the master push switch, and quiet hours. No feed row is written for that arrival. `QUESTION_ANSWERED` pushes "respondeu. Responda para ver." `QUESTION_UNLOCKED` pushes "Desbloqueada!" to the partner who answered first. Neither push includes the answer text.

Gift-idea / private list types (`GIFT_IDEAS`, `GIFTS`, `GIFT`, `PRIVATE`) do not create events. Web push is not sent.
