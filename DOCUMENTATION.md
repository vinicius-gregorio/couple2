# Couple — Documentation

## What is this?

**Couple** is a cross-platform app for romantic partners to connect and sync their accounts. Users sign in with Google or Apple (both through **Firebase Authentication**), receive a unique 6-character pairing code, and share it with their partner to link both accounts together via a double handshake protocol.

The project is split into two parts:

- **`couple2_backend`** — REST API server
- **`couple2_app`** — Flutter mobile/web/desktop client

---

## couple2_backend

### Overview

NestJS REST API that handles social authentication, user management, and the pairing system. Runs on Node.js with **PostgreSQL** from the official local Supabase stack (`supabase start`). Prisma is the only data access layer.

### Tech Stack

| Layer | Technology |
|---|---|
| Framework | NestJS 11 |
| Language | TypeScript 5.7 |
| Runtime | Node.js 22 |
| Database | PostgreSQL 17 via local Supabase (`supabase start`) |
| Data access | Prisma 7 (`@prisma/client` + `@prisma/adapter-pg`) |
| Auth | App-issued JWT (Passport). Firebase ID token verification is optional |

> **Data layer:** Prisma talks to the Postgres database that `supabase start` runs in Docker. There is no cloud Supabase project and no Firestore. `firebase-admin` is used only when `POST /auth/firebase` verifies a real Google or Apple ID token. `POST /auth/dev-login` and every list/pairing query run without a Firebase service account.

### Dependencies

**Runtime**

| Package | Version | Purpose |
|---|---|---|
| `@nestjs/common` | 11.0.1 | Core NestJS decorators and utilities |
| `@nestjs/core` | 11.0.1 | NestJS application core |
| `@nestjs/platform-express` | 11.0.1 | Express HTTP adapter |
| `@nestjs/jwt` | 11.0.2 | App JWT generation and validation |
| `@nestjs/passport` | 11.0.5 | Passport.js integration |
| `firebase-admin` | 13.10.0 | Optional Firebase ID token verification and FCM (`PUSH_DRIVER=fcm`) |
| `@nestjs/schedule` | ^6.0.0 | Hourly job for important-date reminders |
| `@prisma/client` | 7.2.0 | Postgres queries and model types |
| `@prisma/adapter-pg` | 7.2.0 | Prisma 7 driver adapter for `pg` |
| `pg` | ^8.23.1 | Postgres connection pool |
| `passport-jwt` | 4.0.1 | JWT Passport strategy |
| `rxjs` | 7.8.2 | Reactive extensions (NestJS internals) |
| `class-validator` | ^0.15.1 | DTO validation (`ValidationPipe` global) |
| `class-transformer` | ^0.5.1 | DTO transform used by `ValidationPipe` |
| `date-fns` | ^3.6.0 | Calendar-day math for `daysTogether` |
| `date-fns-tz` | ^3.2.0 | "Today" in the couple IANA timezone |

**Development**

| Package | Version | Purpose |
|---|---|---|
| `prisma` | 7.2.0 | Client generation and SQL migrations |
| `typescript` | 5.7.3 | TypeScript compiler |
| `ts-node` | 10.9.2 | TypeScript execution |
| `jest` | 30.0.0 | Test runner |
| `ts-jest` | 29.4.0 | Jest TypeScript transformer |
| `eslint` | 9.18.0 | Linter |
| `prettier` | 3.4.2 | Code formatter |

### Project Structure

```
src/
├── main.ts                   # Bootstrap, ValidationPipe, starts server on PORT (default 3000)
├── configure-app.ts          # Global ValidationPipe + CORS
├── app.module.ts             # Root module
├── auth/                     # Auth module (login, JWT, guards, decorators)
│   ├── strategies/           # firebase.strategy (ID token verify), jwt.strategy
│   ├── guards/               # JwtAuthGuard, PairingGuard
│   └── decorators/           # @GetUser(), @GetPartner()
├── users/                    # User profile (`PATCH /users/me`) and pairing codes
├── pairing/                  # Pairing logic (double handshake + Couple row)
├── couple/                   # Couple record, important dates, CoupleGuard
├── lists/                    # Shared lists scoped by coupleId
├── notifications/            # Device tokens, activity feed, push, date reminders
├── firebase/                 # Firebase Admin init (ID token verify + FCM)
└── prisma/                   # PrismaService (Postgres via the pg adapter)
```

SQL migrations live in `prisma/migrations`. Local Supabase config lives at the repo root in `supabase/config.toml` (`project_id = "couple2"`).

### Database Schema

Postgres tables (Prisma `@map` names). Primary keys are UUIDs. Relations are foreign keys.

**`users`** — user profiles and partner relationships

| Field | Type | Notes |
|---|---|---|
| `id` | string (UUID) | Primary key |
| `email` | string | One account per email (enforced in app logic) |
| `name` | string? | From the provider |
| `picture` | string? | Avatar URL |
| `googleId` | string? | Legacy Google OAuth ID |
| `appleId` | string? | Legacy Apple Sign-In ID |
| `firebaseUid` | string? | Firebase Auth UID (primary identity now) |
| `pairingCode` | string? | 6-char code, expires in 30 days |
| `pairingCodeExpiresAt` | timestamp? | Expiry |
| `partnerId` | string? | UUID of paired user. Written in the same transaction as `coupleId` |
| `coupleId` | string? | Active couple. Null after unpair |
| `birthDate` | date? | Calendar birthday (`YYYY-MM-DD`) |
| `feedSeenAt` | timestamp? | Unread partner events are those newer than this. Null means the feed was never opened |
| `createdAt` / `updatedAt` | timestamp | Set by the database / Prisma |

**`device_tokens`** — one row per FCM token (`token` unique, `platform` `IOS` / `ANDROID` / `WEB`). Logout deletes only the current user's row. A token that signs into another account is reassigned. Web tokens are stored but not pushed (no web push).

**`activity_events`** — couple-scoped feed. `actorId` null is a system event. `payload` is a snapshot (item text is truncated to 80 characters). Gift / private list types never write a row. A partial unique index on `(coupleId, type, entityId, payload.occurrenceDate)` stops duplicate `COUPLE_DATE_UPCOMING` rows.

**`notification_preferences`** — one row per user, created on the first `GET`. Category flags plus `quietStartMin` / `quietEndMin` (minutes from midnight in the couple timezone; `1380` is 23:00). A window that passes midnight wraps. Quiet hours and a disabled category still leave the event in the feed.

**`couples`** — one row per pairing. `userAId` is the smaller user id. `status` is `ACTIVE` or `ENDED`. `anniversaryDate` is the relationship start (calendar date, optional). `timezone` is one IANA zone for the couple (default `America/Sao_Paulo`). Partial unique indexes allow only one `ACTIVE` row per user. Re-pairing the same people creates a new row.

**`couple_dates`** — custom dates (`title` ≤ 60, calendar `date`, `recurrence` `YEARLY` or `NONE`). Birthdays and the relationship anniversary are not stored here. Deleting a couple cascades to these rows.

**`partner_lists`** / **`list_items`** — shared lists and their items (`ownerId`, `type`, `name`, `coupleId`; items carry `listId`, `content`, `metadata` JSON, `isCompleted`, `addedById`). `coupleId` stays nullable so lists created before a pairing can be attached on the next one. Lists of an ended couple keep that `coupleId` and are not readable by either former partner or by a new partner. Deleting a list cascades to its items.

**`pairing_requests`** — tracks the double handshake state

| Field | Type | Notes |
|---|---|---|
| `id` | string (UUID) | Primary key |
| `requesterId` | string | UUID of requesting user |
| `targetCode` | string | Partner's code entered |
| `createdAt` | timestamp | Created |

### API Endpoints

**Auth**

| Method | Path | Auth | Description |
|---|---|---|---|
| POST | `/auth/firebase` | — | Login with a Firebase ID token (Google or Apple) → returns app JWT |
| POST | `/auth/dev-login` | — | Dev-only login by email (no Firebase service account) |
| GET | `/auth/me` | JWT | Current user (includes `coupleId` and `birthDate`) + partner info |

**Pairing**

| Method | Path | Auth | Description |
|---|---|---|---|
| POST | `/pairing/pair` | JWT | Initiate or complete pairing |
| GET | `/pairing/status` | JWT | Get current pairing status |
| DELETE | `/pairing/request` | JWT | Cancel pending pairing request |
| DELETE | `/pairing/unpair` | JWT + paired | End the couple (`ENDED`, `endedAt`) and clear both `partnerId` and `coupleId` |

**Couple**

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/couple` | JWT + active couple | Couple profile, `daysTogether`, partner, upcoming dates (next 60 days) |
| PATCH | `/couple` | JWT + active couple | `{ anniversaryDate?, timezone? }`. Either partner. `timezone` must be IANA |
| GET | `/couple/dates` | JWT + active couple | Custom couple dates |
| POST | `/couple/dates` | JWT + active couple | Create a custom date (`title` ≤ 60, `date`, `recurrence?`) |
| PATCH | `/couple/dates/:id` | JWT + active couple | Update a date in this couple. Other couples get 404 |
| DELETE | `/couple/dates/:id` | JWT + active couple | Delete a date in this couple. Other couples get 404 |
| PATCH | `/users/me` | JWT | `{ birthDate? }`. Future dates and unknown fields return 400 |

**Lists** (scoped by the active `coupleId`; `CoupleGuard` replaces `PairingGuard`)

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/lists` | JWT + active couple | Lists of the current couple only |
| POST | `/lists` | JWT + active couple | Create a list on the current couple |
| GET | `/lists/:id` | JWT + active couple | 404 when the list is missing or belongs to another couple |
| POST | `/lists/:id/items` | JWT + active couple | Add an item. 404 outside the couple |
| PATCH | `/lists/items/:id` | JWT + active couple | Toggle an item. 404 outside the couple (no IDOR) |
| DELETE | `/lists/items/:id` | JWT + active couple | Delete an item. 404 outside the couple |
| DELETE | `/lists/:id` | JWT + active couple | Delete a list in this couple |

Creating a list, adding an item, and completing an item (only the transition to `true`) write a feed event after the list write commits. The partner gets at most one push per list every 5 minutes. The author does not.

**Devices, feed, notification preferences**

| Method | Path | Auth | Description |
|---|---|---|---|
| POST | `/devices` | JWT | Upsert `{ token, platform, appVersion?, locale? }`. Reassigns the token if another user had it |
| DELETE | `/devices/:token` | JWT | Remove that token only if it belongs to the caller. Called on logout before local prefs are cleared |
| GET | `/feed?cursor&limit=20` | JWT + active couple | Keyset page `(createdAt, id)` descending. Both partners and system events. Another couple gets none of these rows |
| GET | `/feed/unread-count` | JWT + active couple | Partner events with `createdAt > feedSeenAt` |
| POST | `/feed/seen` | JWT + active couple | Sets `feedSeenAt` to now |
| GET | `/notifications/preferences` | JWT | Creates defaults on the first read |
| PATCH | `/notifications/preferences` | JWT | Category toggles and quiet hours. Unknown fields are 400 |

### Pairing Flow

1. User A calls `POST /pairing/pair` with User B's code → creates a `PENDING` request.
2. User B calls `POST /pairing/pair` with User A's code → in one transaction, creates an `ACTIVE` couple, sets `partnerId` and `coupleId` on both users, attaches lists that still have `coupleId` NULL, and clears the requests. A failure inside the transaction leaves neither `partnerId` nor the couple row.
3. `DELETE /pairing/unpair` sets that couple to `ENDED` with `endedAt` and clears `coupleId` on both users. Lists stay on the ended couple and are not visible to either person or to a later partner. There is no 30-day archive. Re-pairing creates a new couple.

`daysTogether` counts calendar days from `anniversaryDate` (or the `pairedAt` day in the couple timezone, when the anniversary is unset) through today in that timezone, including the first day. Upcoming dates cover the next 60 days: the yearly anniversary, both birthdays, and custom couple dates. A Feb 29 birthday is shown as Feb 28 in a non-leap year.

### Environment Variables

```env
JWT_SECRET=local-dev-jwt-secret-change-me-32b
PORT=3000

# Host process (`npm run dev`). See couple2_backend/.env.example.
DATABASE_URL=postgresql://postgres:postgres@127.0.0.1:54322/postgres?schema=public

# Optional — POST /auth/firebase and PUSH_DRIVER=fcm.
FIREBASE_SERVICE_ACCOUNT=
# FIREBASE_SERVICE_ACCOUNT_PATH=./serviceAccount.json

# log = print the push (default in dev, and whenever credentials are missing).
# fcm = send via Firebase Cloud Messaging.
PUSH_DRIVER=log
```

Real Google/Apple login still verifies a Firebase ID token (project `couple42-27692`).
That path needs a service-account key. Local lists, pairing, `dev-login`, and `PUSH_DRIVER=log` do not.
FCM in production uses the same service account; the key needs the `firebasecloudmessaging` role.
iOS also needs the APNs key uploaded to Firebase project `couple42-27692`.

### Push locally (`PUSH_DRIVER=log`)

```bash
cd couple2_backend
cp .env.example .env   # PUSH_DRIVER=log is already set
npm install
npx prisma migrate deploy
npm run dev
```

List routes keep working with no service account. A partner action writes the feed row and prints one line from `LogPushSender` (`type`, `route`, title, body). Nothing is sent to FCM. Set `PUSH_DRIVER=fcm` only when `FIREBASE_SERVICE_ACCOUNT` is present.

An hourly job records `COUPLE_DATE_UPCOMING` for couples whose local time is 09:00, for dates 7, 1, and 0 days away. Running it again the same morning does not create a second row or a second push.

### Running

Database is local Supabase in Docker. No cloud Supabase account.

From the **repository root**:

```bash
supabase start
```

That publishes Postgres on `127.0.0.1:54322` (user/password/db `postgres` / `postgres` / `postgres`). Studio is on port 54323.

**API on the host** (`couple2_backend`):

```bash
cp .env.example .env
npm install
npx prisma migrate deploy
npm run dev           # http://localhost:3000
npm test
```

**API in Docker** (same Supabase Postgres; compose does not start its own database):

```bash
# repo root: supabase start
cd couple2_backend
docker compose up --build
```

`docker-compose.dev.yml` no longer starts Postgres. Use `supabase start` instead.

`POST /auth/dev-login` with `{ "email": "a@example.com", "name": "A" }` creates the user in Postgres and returns an app JWT. No Firebase key required. Use that JWT as `Authorization: Bearer …` for `/lists` and `/pairing`.

---

## couple2_app

### Overview

Flutter app for iOS, Android, Web, macOS, Windows, and Linux. Handles Firebase Authentication (Google + Apple), app-JWT storage, and the partner pairing UI.

### Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter (SDK ^3.9.0) |
| Language | Dart |
| State Management | Riverpod 3 |
| Navigation | GoRouter 17 |
| HTTP Client | Dio 5 (custom wrapper) |
| Authentication | Firebase Auth (Google + Apple) |
| Local Storage | SharedPreferences 2 |
| UI | Material Design 3 + Google Fonts |

### Dependencies

**Runtime**

| Package | Version | Purpose |
|---|---|---|
| `flutter_riverpod` | ^3.2.0 | Reactive state management |
| `go_router` | ^17.0.1 | Declarative navigation with auth redirects |
| `dio` | ^5.9.0 | HTTP client |
| `firebase_core` | ^4.2.0 | Firebase initialization |
| `firebase_auth` | ^6.1.0 | Google + Apple sign-in via Firebase |
| `firebase_messaging` | ^16.0.4 | FCM token, refresh, and notification taps |
| `flutter_local_notifications` | ^19.4.2 | Show a push while the Android app is in the foreground |
| `google_sign_in` | ^7.2.0 | Obtains the Google credential on mobile (fed to Firebase) |
| `shared_preferences` | ^2.5.4 | Persistent local key-value storage |
| `google_fonts` | ^6.2.1 | Typography |
| `flutter_svg` | ^2.2.3 | SVG rendering |
| `intl` | ^0.20.2 | Internationalization |
| `flutter_timezone` | 4.1.1 | Device IANA timezone (default for the couple) |

**Development**

| Package | Purpose |
|---|---|
| `flutter_test` | Flutter testing framework |
| `flutter_lints` | Recommended lint rules |
| `build_runner` | Code generation |

### Project Structure

```
lib/
├── main.dart                        # Entry point — ProviderScope + bootstrap
├── firebase_options.dart            # Generated Firebase config (web/android/ios)
├── app/
│   ├── app.dart                     # CoupleApp widget (MaterialApp.router)
│   ├── bootstrap.dart               # Firebase.initializeApp + DI init
│   ├── di.dart                      # Dependency injection (API base URL here)
│   ├── providers.dart               # Global Riverpod providers
│   └── routing/
│       ├── router.dart              # GoRouter + auth redirects
│       └── routes.dart              # Route path constants
├── modules/
│   ├── auth/                        # Auth feature module
│   ├── couple/                      # Couple record + important dates
│   ├── notifications/               # Push registration + preference screen
│   └── feed/                        # Activity feed page and Home preview
│       ├── ui/pages/auth/           # Login screen + ViewModel
│       ├── ui/widgets/              # Google + Apple sign-in buttons
│       ├── domain/entities/         # User entity
│       └── data/                    # Auth repository (Firebase) + Riverpod providers
├── core/
│   ├── external/http_client/        # Custom Dio wrapper with typed exceptions
│   └── domain/entities/             # Shared entities
└── design_system/
    └── theme/                       # Light and dark theme definitions
```

### Key Patterns

- **Clean Architecture** — each feature module has UI, Domain, and Data layers.
- **Riverpod** — all state goes through providers; ViewModels are `StateNotifier`-based.
- **GoRouter** — unauthenticated users redirect to `/auth`; authenticated users redirect to `/home`. Couple routes: `/couple` and `/couple/dates`. Feed: `/feed`. Notification preferences: `/notifications/preferences`. A push tap calls `router.push` with `data.route` (for example `/lists/<id>`), including when the app was closed (`getInitialMessage`).
- **Push** — permission is requested after pairing, not on first boot. The FCM token is posted to `/devices`. Logout deletes that token before clearing SharedPreferences. Home shows a bell with the unread count and the last 3 events. Opening the feed calls `POST /feed/seen`.
- **Session** — `sessionProvider` calls `GET /auth/me` on boot, on resume, and via `refresh()` after pairing. Home reads that session instead of the user snapshot saved at login, so `coupleId` is current without logging out. Pairing screens (P0) are not in this build; when they land they must call `sessionProvider.notifier.refresh()` after a successful pair. A 403 from lists means the user is not paired and should open that P0 flow.
- **Custom HTTP client** — Dio wrapper in `core/external/http_client/` adds JWT headers via interceptor and maps HTTP errors to typed exceptions (401, 403, 404, 409, 422, 500…).
- **Firebase Auth** — sign-in runs through `firebase_auth`. Web uses `signInWithPopup`; mobile Google uses a `google_sign_in` credential exchanged into Firebase; Apple uses the Firebase Apple provider.

### Auth Flow

1. User taps **Sign in with Google** or **Sign in with Apple**.
2. `firebase_auth` runs the provider flow and signs the user into Firebase.
3. App gets the **Firebase ID token** (`user.getIdToken()`) and sends it to `POST /auth/firebase`.
4. Backend verifies the token with `firebase-admin`, upserts the user in Postgres, and returns an app JWT. Local testing can skip this and call `POST /auth/dev-login` instead.
5. The app JWT is stored in `SharedPreferences`.
6. GoRouter detects the auth state change and navigates to `/home`.

### Running

```bash
flutter pub get

flutter run                # default device
flutter run -d chrome      # web
flutter run -d ios
flutter run -d android
flutter run -d macos

flutter test               # run tests
```

> Set the API base URL in `lib/app/di.dart` to point to your running backend instance.
