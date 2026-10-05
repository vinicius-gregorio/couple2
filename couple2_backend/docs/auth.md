# Authentication Module

## Overview

This project uses **social authentication** (Google and Apple Sign-In) for mobile apps. The authentication flow validates ID tokens sent from the mobile client and returns JWT tokens for API access.

## Architecture

```
Mobile App
    │
    ├── Google Sign-In SDK → Gets ID Token
    │       │
    │       ▼
    │   POST /auth/google { idToken }
    │       │
    │       ▼
    │   GoogleAuthStrategy.validateIdToken()
    │       │
    │       ▼
    │   AuthService.findOrCreateGoogleUser()
    │       │
    │       ▼
    │   Returns { accessToken, user }
    │
    └── Apple Sign-In SDK → Gets ID Token + User Info
            │
            ▼
        POST /auth/apple { idToken, user? }
            │
            ▼
        AppleAuthStrategy.validateIdToken()
            │
            ▼
        AuthService.findOrCreateAppleUser()
            │
            ▼
        Returns { accessToken, user }
```

## File Structure

```
src/auth/
├── auth.module.ts          # Module definition
├── auth.service.ts         # Business logic
├── auth.controller.ts      # HTTP endpoints
├── index.ts                # Barrel export
├── dto/
│   ├── social-login.dto.ts    # Request DTOs
│   ├── auth-response.dto.ts   # Response DTO
│   └── index.ts
├── decorators/
│   ├── get-user.decorator.ts    # @GetUser() decorator
│   ├── get-partner.decorator.ts # @GetPartner() decorator
│   └── index.ts
├── guards/
│   ├── jwt-auth.guard.ts   # Route protection (requires auth)
│   ├── pairing.guard.ts    # Route protection (requires partner)
│   └── index.ts
└── strategies/
    ├── google.strategy.ts  # Google ID token validation
    ├── apple.strategy.ts   # Apple ID token validation
    ├── jwt.strategy.ts     # JWT validation + loads partner info
    └── index.ts
```

## Environment Variables

Required in `.env`:

```bash
# JWT Configuration
JWT_SECRET=your_jwt_secret_key_here_min_32_chars

# Google OAuth (for mobile app ID token validation)
GOOGLE_CLIENT_ID=your_google_client_id.apps.googleusercontent.com

# Apple Sign-In
APPLE_CLIENT_ID=com.yourcompany.yourapp
```

### Getting Credentials

**Google:**
1. Go to [Google Cloud Console](https://console.cloud.google.com/apis/credentials)
2. Create OAuth 2.0 Client ID (iOS/Android)
3. Use the Client ID as `GOOGLE_CLIENT_ID`

**Apple:**
1. Go to [Apple Developer Portal](https://developer.apple.com/account/resources/identifiers)
2. Create an App ID with Sign In with Apple capability
3. Use the Bundle ID as `APPLE_CLIENT_ID`

## API Endpoints

### POST /auth/google

Authenticate with Google ID token.

**Request:**
```json
{
  "idToken": "eyJhbGciOiJSUzI1NiIsInR5cCI6..."
}
```

**Response:**
```json
{
  "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6...",
  "user": {
    "id": "uuid",
    "email": "user@gmail.com",
    "name": "John Doe"
  }
}
```

### POST /auth/apple

Authenticate with Apple ID token.

**Request:**
```json
{
  "idToken": "eyJhbGciOiJSUzI1NiIsInR5cCI6...",
  "user": {
    "email": "user@icloud.com",
    "name": {
      "firstName": "John",
      "lastName": "Doe"
    }
  }
}
```

Note: Apple only sends `user` info on the **first login**. The backend stores this data and uses the `appleId` for subsequent logins.

**Response:**
```json
{
  "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6...",
  "user": {
    "id": "uuid",
    "email": "user@icloud.com",
    "name": "John Doe"
  }
}
```

### GET /auth/me (Session Endpoint)

Returns current user session with profile, pairing status, and partner info.

**Headers:**
```
Authorization: Bearer <accessToken>
```

**Response (Unpaired User):**
```json
{
  "user": {
    "id": "uuid",
    "email": "user@example.com",
    "name": "John Doe",
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

**Response (Paired User):**
```json
{
  "user": {
    "id": "uuid",
    "email": "user@example.com",
    "name": "John Doe",
    "createdAt": "2024-01-18T12:00:00.000Z"
  },
  "pairing": {
    "isPaired": true
  },
  "partner": {
    "id": "partner-uuid",
    "name": "Jane Doe",
    "email": "jane@example.com"
  }
}
```

## Protecting Routes

### Using JwtAuthGuard (Authentication Required)

Use `JwtAuthGuard` and `@GetUser()` decorator to protect routes:

```typescript
import { Controller, Get, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards';
import { GetUser } from '../auth/decorators';
import type { UserWithPartner } from '../auth/strategies/jwt.strategy';

@Controller('example')
export class ExampleController {
  @UseGuards(JwtAuthGuard)
  @Get('protected')
  async protectedRoute(@GetUser() user: UserWithPartner) {
    return { userId: user.id };
  }
}
```

### Using PairingGuard (Partner Required)

Use `PairingGuard` after `JwtAuthGuard` to restrict access to paired users only:

```typescript
import { Controller, Get, UseGuards } from '@nestjs/common';
import { JwtAuthGuard, PairingGuard } from '../auth/guards';
import { GetUser, GetPartner } from '../auth/decorators';
import type { UserWithPartner } from '../auth/strategies/jwt.strategy';

@Controller('couple')
export class CoupleController {
  @UseGuards(JwtAuthGuard, PairingGuard)
  @Get('shared-data')
  async getSharedData(
    @GetUser() user: UserWithPartner,
    @GetPartner() partner: { id: string; name: string | null; email: string },
  ) {
    // This route is only accessible by paired users
    return {
      userId: user.id,
      partnerId: partner.id,
    };
  }
}
```

## Custom Decorators

### @GetUser()

Extracts the authenticated user (with partner info) from the request.

```typescript
@GetUser() user: UserWithPartner
```

The `UserWithPartner` type includes:
```typescript
type UserWithPartner = User & {
  partner: Pick<User, 'id' | 'name' | 'email'> | null;
};
```

### @GetPartner()

Extracts the partner info from the request. Returns `null` if user is not paired.

```typescript
@GetPartner() partner: { id: string; name: string | null; email: string } | null
```

## Guards

### JwtAuthGuard

- Validates JWT token from `Authorization: Bearer <token>` header
- Loads user from database
- Attaches user (with partner info) to request
- Returns 401 if token is invalid or user not found

### PairingGuard

- Must be used **after** JwtAuthGuard
- Checks if user has a `partnerId`
- Returns 403 if user is not paired
- Use for couple-only features

## AuthService Methods

### googleLogin(idToken: string)

1. Validates Google ID token using `google-auth-library`
2. Extracts `sub` (Google user ID), `email`, and `name`
3. Finds or creates user in database
4. Returns JWT access token and user data

### appleLogin(idToken: string, userInfo?: AppleUserInfo)

1. Validates Apple ID token using `apple-signin-auth`
2. Extracts `sub` (Apple user ID) and optionally `email`
3. Uses provided `userInfo` for name (only sent on first login)
4. Finds or creates user in database
5. Returns JWT access token and user data

### Account Linking Logic

When a user signs in with a social provider:

1. **Check by social ID** (`googleId` or `appleId`)
   - If found: Return existing user

2. **Check by email**
   - If found: Link social account to existing user
   - This allows users to sign in with Google AND Apple using the same email

3. **Create new user**
   - If no match found, create new user with social ID

## JWT Token

**Payload:**
```typescript
{
  sub: string;   // User ID (UUID)
  email: string; // User email
  iat: number;   // Issued at
  exp: number;   // Expiration (7 days)
}
```

**Configuration in auth.module.ts:**
```typescript
JwtModule.register({
  secret: process.env.JWT_SECRET,
  signOptions: { expiresIn: '7d' },
})
```

## Strategies

### GoogleAuthStrategy

Uses `google-auth-library` to verify ID tokens:

```typescript
const ticket = await this.client.verifyIdToken({
  idToken,
  audience: process.env.GOOGLE_CLIENT_ID,
});
const payload = ticket.getPayload();
// payload.sub = Google user ID
// payload.email = User email
// payload.name = User name
```

### AppleAuthStrategy

Uses `apple-signin-auth` to verify ID tokens:

```typescript
const payload = await appleSignin.verifyIdToken(idToken, {
  audience: process.env.APPLE_CLIENT_ID,
  ignoreExpiration: false,
});
// payload.sub = Apple user ID
// payload.email = User email (may be null on subsequent logins)
```

### JwtStrategy

Uses `passport-jwt` to validate JWT tokens on protected routes:

```typescript
// Extracts token from Authorization header
jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken()

// Validates and returns user from database
async validate(payload: JwtPayload) {
  return this.prisma.user.findUnique({
    where: { id: payload.sub },
  });
}
```

## Error Handling

| Error | HTTP Status | Cause |
|-------|-------------|-------|
| Invalid Google ID token | 401 | Token expired, invalid signature, wrong audience |
| Invalid Apple ID token | 401 | Token expired, invalid signature, wrong audience |
| Email not provided | 400 | Apple user chose to hide email (on first login) |
| User not found | 401 | JWT valid but user deleted from database |

## Testing

### Manual Testing with curl

```bash
# Google login (requires valid ID token from mobile app)
curl -X POST http://localhost:3000/auth/google \
  -H "Content-Type: application/json" \
  -d '{"idToken": "YOUR_GOOGLE_ID_TOKEN"}'

# Apple login
curl -X POST http://localhost:3000/auth/apple \
  -H "Content-Type: application/json" \
  -d '{"idToken": "YOUR_APPLE_ID_TOKEN", "user": {"email": "test@icloud.com", "name": {"firstName": "John", "lastName": "Doe"}}}'

# Get profile (with JWT)
curl http://localhost:3000/auth/me \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

## Dependencies

```json
{
  "@nestjs/passport": "^11.x",
  "@nestjs/jwt": "^11.x",
  "passport": "^0.7.x",
  "passport-jwt": "^4.x",
  "google-auth-library": "^9.x",
  "apple-signin-auth": "^1.x"
}
```
