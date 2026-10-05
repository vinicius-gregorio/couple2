# Testing Guide

## Prerequisites

- Docker Desktop installed and running
- Node.js 20+
- A Google Cloud project (for Google Sign-In)
- An Apple Developer account (for Apple Sign-In)

---

## 1. Environment Setup

### 1.1 Create your .env file

```bash
cp .env.example .env
```

### 1.2 Edit .env with your values

```bash
# Local Supabase Postgres (`supabase start` from the repo root)
DATABASE_URL=postgresql://postgres:postgres@127.0.0.1:54322/postgres?schema=public

# JWT Secret (generate a random 32+ char string)
JWT_SECRET=your-super-secret-jwt-key-at-least-32-chars

# Google OAuth
GOOGLE_CLIENT_ID=your-google-client-id.apps.googleusercontent.com

# Apple Sign-In
APPLE_CLIENT_ID=com.yourcompany.yourapp
```

---

## 2. Start the Database

```bash
# From the repository root — official local Supabase stack (Docker)
supabase start

# Postgres is published on 127.0.0.1:54322
supabase status
```

---

## 3. Run Migrations

```bash
# Apply all migrations
npx prisma migrate dev

# (Optional) View database in Prisma Studio
npx prisma studio
```

---

## 4. Start the Server

```bash
# Development mode (with hot reload)
npm run dev

# Or build and run
npm run build && npm run start
```

Server runs at: `http://localhost:3000`

---

## 5. Getting Test Credentials

### 5.1 Google Sign-In Setup

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing
3. Go to **APIs & Services** → **Credentials**
4. Click **Create Credentials** → **OAuth 2.0 Client ID**
5. Select **iOS** or **Android** application type
6. Add your bundle ID / package name
7. Copy the **Client ID** to your `.env` file

**For testing without a mobile app:**

You can use the [Google OAuth Playground](https://developers.google.com/oauthplayground/):
1. Click the gear icon → Check "Use your own OAuth credentials"
2. Enter your Client ID and Client Secret
3. Select `https://www.googleapis.com/auth/userinfo.email` and `https://www.googleapis.com/auth/userinfo.profile`
4. Click "Authorize APIs" and sign in
5. Click "Exchange authorization code for tokens"
6. The `id_token` in the response is what you need

### 5.2 Apple Sign-In Setup

1. Go to [Apple Developer Portal](https://developer.apple.com/account/)
2. Go to **Certificates, Identifiers & Profiles**
3. Create an **App ID** with "Sign In with Apple" capability
4. The Bundle ID is your `APPLE_CLIENT_ID`

**For testing:** Apple Sign-In requires a real iOS/macOS app or web implementation. You cannot easily get test tokens without a client app.

---

## 6. Testing the API

### 6.1 Health Check

```bash
curl http://localhost:3000
```

### 6.2 Google Login

```bash
curl -X POST http://localhost:3000/auth/google \
  -H "Content-Type: application/json" \
  -d '{
    "idToken": "YOUR_GOOGLE_ID_TOKEN_HERE"
  }'
```

**Expected Response:**
```json
{
  "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "id": "uuid",
    "email": "you@gmail.com",
    "name": "Your Name",
    "partnerId": null,
    "pairingCode": "XJ92L1",
    "pairingCodeExpiresAt": "2024-02-18T12:00:00.000Z"
  }
}
```

### 6.3 Apple Login

```bash
curl -X POST http://localhost:3000/auth/apple \
  -H "Content-Type: application/json" \
  -d '{
    "idToken": "YOUR_APPLE_ID_TOKEN_HERE",
    "user": {
      "email": "user@icloud.com",
      "name": {
        "firstName": "John",
        "lastName": "Doe"
      }
    }
  }'
```

### 6.4 Get Session (Protected Route)

```bash
# Replace YOUR_JWT_TOKEN with the accessToken from login response
curl http://localhost:3000/auth/me \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

**Expected Response (Unpaired):**
```json
{
  "user": {
    "id": "uuid",
    "email": "you@gmail.com",
    "name": "Your Name",
    "createdAt": "2024-01-18T12:00:00.000Z"
  },
  "pairing": {
    "isPaired": false,
    "pairingCode": "XJ92L1",
    "pairingCodeExpiresAt": "2024-02-18T12:00:00.000Z"
  },
  "partner": null
}
```

### 6.5 Pairing Flow

**User A enters User B's code:**
```bash
curl -X POST http://localhost:3000/pairing/pair \
  -H "Authorization: Bearer USER_A_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"code": "USER_B_CODE"}'
```

**Response (pending):**
```json
{
  "status": "pending",
  "message": "Pairing request sent. Waiting for your partner to enter your code."
}
```

**User B enters User A's code:**
```bash
curl -X POST http://localhost:3000/pairing/pair \
  -H "Authorization: Bearer USER_B_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"code": "USER_A_CODE"}'
```

**Response (paired):**
```json
{
  "status": "paired",
  "message": "Successfully paired with your partner!",
  "partner": {
    "id": "user-a-uuid",
    "name": "User A Name"
  }
}
```

---

## 7. Testing Without Real Social Tokens

For local development without real Google/Apple tokens, you can temporarily modify the auth strategies to bypass validation:

### 7.1 Create a Dev-Only Endpoint

Add to `src/auth/auth.controller.ts` (REMOVE BEFORE PRODUCTION):

```typescript
// DEV ONLY - Remove before production!
@Post('dev-login')
async devLogin(@Body() dto: { email: string; name?: string }) {
  if (process.env.NODE_ENV === 'production') {
    throw new ForbiddenException('Not available in production');
  }

  let user = await this.authService.validateUser(dto.email);
  if (!user) {
    // Create user directly for testing
    user = await this.prisma.user.create({
      data: { email: dto.email, name: dto.name },
    });
  }

  // Generate JWT and return
  // ... (implement similar to social login)
}
```

### 7.2 Use Prisma Studio

```bash
npx prisma studio
```

1. Open `http://localhost:5555`
2. Manually create users in the `User` table
3. Use the generated IDs to test protected endpoints

---

## 8. Useful Commands

```bash
# View logs
docker-compose logs -f db

# Reset database (deletes all data!)
npx prisma migrate reset

# Generate new migration after schema changes
npx prisma migrate dev --name your_migration_name

# View all users
npx prisma studio

# Run linter
npm run lint

# Run tests
npm run test
```

---

## 9. Troubleshooting

### "Connection refused" error
- Check local Supabase: `supabase status` from the repo root
- Host API uses `127.0.0.1:54322`; the compose API uses `host.docker.internal:54322`

### "Invalid token" error
- Verify GOOGLE_CLIENT_ID matches the one used to generate the token
- Check token hasn't expired
- Ensure you're using the `id_token`, not `access_token`

### "User not found" on protected routes
- Token may have expired (7 day expiry)
- User may have been deleted from database

### Prisma types not updating
```bash
npx prisma generate
# Then in VS Code: Cmd+Shift+P → "TypeScript: Restart TS Server"
```

---

## 10. API Endpoints Summary

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| POST | `/auth/google` | No | Login with Google ID token |
| POST | `/auth/apple` | No | Login with Apple ID token |
| GET | `/auth/me` | JWT | Get current session |
| POST | `/pairing/pair` | JWT | Enter partner's code |
| GET | `/pairing/status` | JWT | Get pairing status |
| DELETE | `/pairing/request` | JWT | Cancel pending request |
| DELETE | `/pairing/unpair` | JWT + Paired | Dissolve partnership |
