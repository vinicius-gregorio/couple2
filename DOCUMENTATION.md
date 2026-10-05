# Couple — Documentation

## What is this?

**Couple** is a cross-platform app for romantic partners to connect and sync their accounts. Users sign in with Google or Apple (both through **Firebase Authentication**), receive a unique 6-character pairing code, and share it with their partner to link both accounts together via a double handshake protocol.

The project is split into two parts:

- **`couple2_backend`** — REST API server
- **`couple2_app`** — Flutter mobile/web/desktop client

---

## couple2_backend

### Overview

NestJS REST API that handles social authentication, user management, and the pairing system. Runs on Node.js with **Cloud Firestore** as the database (via the Firebase Admin SDK).

### Tech Stack

| Layer | Technology |
|---|---|
| Framework | NestJS 11 |
| Language | TypeScript 5.7 |
| Runtime | Node.js 22 |
| Database | Cloud Firestore (Firebase) |
| Data access | Firebase Admin SDK (`firebase-admin`) |
| Auth | App-issued JWT (Passport) + Firebase ID token verification |

> **Note on the data layer:** the database was migrated from PostgreSQL/Prisma to Firestore. To keep the migration contained, `@prisma/client` is still installed **for its generated model types only** (`User`, `PartnerList`, …); no Prisma queries run at runtime. `PrismaService` (`src/prisma/prisma.service.ts`) is now a Firestore-backed shim that keeps the same delegate API the domain services already call, so no service/controller code changed.

### Dependencies

**Runtime**

| Package | Version | Purpose |
|---|---|---|
| `@nestjs/common` | 11.0.1 | Core NestJS decorators and utilities |
| `@nestjs/core` | 11.0.1 | NestJS application core |
| `@nestjs/platform-express` | 11.0.1 | Express HTTP adapter |
| `@nestjs/jwt` | 11.0.2 | App JWT generation and validation |
| `@nestjs/passport` | 11.0.5 | Passport.js integration |
| `firebase-admin` | latest | Firestore access + Firebase ID token verification |
| `@prisma/client` | 7.2.0 | Generated model **types only** (no runtime queries) |
| `passport-jwt` | 4.0.1 | JWT Passport strategy |
| `rxjs` | 7.8.2 | Reactive extensions (NestJS internals) |

**Development**

| Package | Version | Purpose |
|---|---|---|
| `prisma` | 7.2.0 | Kept only to regenerate model types from `schema.prisma` |
| `typescript` | 5.7.3 | TypeScript compiler |
| `ts-node` | 10.9.2 | TypeScript execution |
| `jest` | 30.0.0 | Test runner |
| `ts-jest` | 29.4.0 | Jest TypeScript transformer |
| `eslint` | 9.18.0 | Linter |
| `prettier` | 3.4.2 | Code formatter |

### Project Structure

```
src/
├── main.ts                   # Bootstrap, starts server on PORT (default 3000)
├── app.module.ts             # Root module
├── auth/                     # Auth module (login, JWT, guards, decorators)
│   ├── strategies/           # firebase.strategy (ID token verify), jwt.strategy
│   ├── guards/               # JwtAuthGuard, PairingGuard
│   └── decorators/           # @GetUser(), @GetPartner()
├── users/                    # User CRUD and pairing code generation
├── pairing/                  # Pairing logic (double handshake)
├── firebase/                 # Shared Firebase Admin init (firebase-admin.ts)
└── prisma/                   # Firestore-backed data service (PrismaService shim)
```

### Database Schema

Firestore collections (document IDs are UUIDs generated on create). Relations are
resolved with follow-up reads rather than SQL joins.

**`users`** — user profiles and partner relationships

| Field | Type | Notes |
|---|---|---|
| `id` | string (UUID) | Document ID |
| `email` | string | One account per email (enforced in app logic) |
| `name` | string? | From the provider |
| `picture` | string? | Avatar URL |
| `googleId` | string? | Legacy Google OAuth ID |
| `appleId` | string? | Legacy Apple Sign-In ID |
| `firebaseUid` | string? | Firebase Auth UID (primary identity now) |
| `pairingCode` | string? | 6-char code, expires in 30 days |
| `pairingCodeExpiresAt` | timestamp? | Expiry |
| `partnerId` | string? | UUID of paired user |
| `createdAt` / `updatedAt` | timestamp | Set by the data layer |

**`partnerLists`** / **`listItems`** — shared lists and their items (`ownerId`, `type`, `name`; items carry `listId`, `content`, `metadata`, `isCompleted`, `addedById`). Deleting a list cascades to its items.

**`pairingRequests`** — tracks the double handshake state

| Field | Type | Notes |
|---|---|---|
| `id` | string (UUID) | Document ID |
| `requesterId` | string | UUID of requesting user |
| `targetCode` | string | Partner's code entered |
| `createdAt` | timestamp | Created |

### API Endpoints

**Auth**

| Method | Path | Auth | Description |
|---|---|---|---|
| POST | `/auth/firebase` | — | Login with a Firebase ID token (Google or Apple) → returns app JWT |
| POST | `/auth/dev-login` | — | Dev-only login by email (no Firebase needed) |
| GET | `/auth/me` | JWT | Get current user + partner info |

**Pairing**

| Method | Path | Auth | Description |
|---|---|---|---|
| POST | `/pairing/pair` | JWT | Initiate or complete pairing |
| GET | `/pairing/status` | JWT | Get current pairing status |
| DELETE | `/pairing/request` | JWT | Cancel pending pairing request |
| DELETE | `/pairing/unpair` | JWT | Dissolve current partnership |

### Pairing Flow

1. User A calls `POST /pairing/pair` with User B's code → creates a `PENDING` request.
2. User B calls `POST /pairing/pair` with User A's code → finds the pending request, sets `partnerId` on both users, and clears the requests.
3. Both are now paired.

### Environment Variables

```env
JWT_SECRET=your-secret-key
PORT=3000

# Firebase Admin credentials (Firestore + ID token verification).
# Provide ONE of the following (checked in this order):
FIREBASE_SERVICE_ACCOUNT=            # inline service-account JSON (raw or base64)
# FIREBASE_SERVICE_ACCOUNT_PATH=./serviceAccount.json
# or simply drop the key at couple2_backend/serviceAccount.json (gitignored)
```

Get the key from Firebase console → Project settings → Service accounts →
Generate new private key (project `couple42-27692`). The backend still **boots**
without it (lazy init); `dev-login` works keyless, but any Firestore or
`/auth/firebase` call requires it.

### Running

No database container needed — data lives in Cloud Firestore.

```bash
npm install
npx prisma generate   # regenerate model TYPES only (after editing schema.prisma)
npm run dev           # development (watch)
npm run prod          # production
npm test              # unit tests
```

Place the Firebase service-account key at `couple2_backend/serviceAccount.json`
(or set `FIREBASE_SERVICE_ACCOUNT`) before exercising Firestore / real login.

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
| `google_sign_in` | ^7.2.0 | Obtains the Google credential on mobile (fed to Firebase) |
| `shared_preferences` | ^2.5.4 | Persistent local key-value storage |
| `google_fonts` | ^6.2.1 | Typography |
| `flutter_svg` | ^2.2.3 | SVG rendering |
| `intl` | ^0.20.2 | Internationalization |

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
│   └── auth/                        # Auth feature module
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
- **GoRouter** — unauthenticated users redirect to `/auth`; authenticated users redirect to `/home`.
- **Custom HTTP client** — Dio wrapper in `core/external/http_client/` adds JWT headers via interceptor and maps HTTP errors to typed exceptions (401, 403, 404, 409, 422, 500…).
- **Firebase Auth** — sign-in runs through `firebase_auth`. Web uses `signInWithPopup`; mobile Google uses a `google_sign_in` credential exchanged into Firebase; Apple uses the Firebase Apple provider.

### Auth Flow

1. User taps **Sign in with Google** or **Sign in with Apple**.
2. `firebase_auth` runs the provider flow and signs the user into Firebase.
3. App gets the **Firebase ID token** (`user.getIdToken()`) and sends it to `POST /auth/firebase`.
4. Backend verifies the token with `firebase-admin`, upserts the user in Firestore, and returns an app JWT.
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
