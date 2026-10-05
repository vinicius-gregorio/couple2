# Pairing System (Double Handshake)

## Overview

The pairing system uses a **double handshake** mechanism to ensure both users consent to becoming partners. Both users must enter each other's pairing codes before the system links them together.

## Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                     DOUBLE HANDSHAKE FLOW                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  User A (code: ABC123)              User B (code: XYZ789)       │
│                                                                 │
│  Step 1: User A enters "XYZ789"                                 │
│  ┌─────────────────────────┐                                    │
│  │ POST /pairing/pair      │                                    │
│  │ { "code": "XYZ789" }    │───────► PairingRequest created     │
│  └─────────────────────────┘        (requesterId: A,            │
│                                      targetCode: XYZ789)        │
│  Response: { status: "pending" }                                │
│                                                                 │
│  Step 2: User B enters "ABC123"                                 │
│                                     ┌─────────────────────────┐ │
│  System detects reciprocal request  │ POST /pairing/pair      │ │
│  (A requested B's code) ◄───────────│ { "code": "ABC123" }    │ │
│                                     └─────────────────────────┘ │
│                                                                 │
│  Step 3: PAIRING COMPLETE!                                      │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │ Transaction:                                                ││
│  │ • User A.partnerId = User B.id                              ││
│  │ • User B.partnerId = User A.id                              ││
│  │ • Clear both pairing codes                                  ││
│  │ • Delete all PairingRequests for both users                 ││
│  └─────────────────────────────────────────────────────────────┘│
│                                                                 │
│  Response: { status: "paired", partner: { id, name } }          │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Database Schema

### PairingRequest Model

```prisma
model PairingRequest {
  id          String   @id @default(uuid())
  requesterId String
  targetCode  String   @db.Char(6)
  createdAt   DateTime @default(now())

  requester User @relation("RequesterRelation", fields: [requesterId], references: [id], onDelete: Cascade)

  @@unique([requesterId, targetCode])
  @@map("pairing_requests")
}
```

| Field       | Type     | Description                        |
|-------------|----------|------------------------------------|
| id          | String   | Primary key (UUID)                 |
| requesterId | String   | FK to the user who made the request|
| targetCode  | String   | The 6-char pairing code entered    |
| createdAt   | DateTime | When the request was created       |

## API Endpoints

All endpoints require JWT authentication (`Authorization: Bearer <token>`).

### POST /pairing/pair

Initiates or completes a pairing request.

**Request:**
```json
{
  "code": "XYZ789"
}
```

**Response (Pending):**
```json
{
  "status": "pending",
  "message": "Pairing request sent. Waiting for your partner to enter your code."
}
```

**Response (Paired):**
```json
{
  "status": "paired",
  "message": "Successfully paired with your partner!",
  "partner": {
    "id": "uuid",
    "name": "Partner Name"
  }
}
```

**Error Responses:**

| Status | Error | Cause |
|--------|-------|-------|
| 400 | Invalid code format | Code is not 6 alphanumeric characters |
| 400 | Cannot pair with yourself | User entered their own code |
| 400 | Pairing code has expired | Target user's code is past 30-day TTL |
| 404 | Invalid pairing code | No user found with this code |
| 409 | Already paired | Requester already has a partner |
| 409 | User is already paired | Target user already has a partner |

### GET /pairing/status

Gets the current pairing status for the authenticated user.

**Response (Paired):**
```json
{
  "status": "paired",
  "partner": {
    "id": "uuid",
    "name": "Partner Name"
  }
}
```

**Response (Pending Request):**
```json
{
  "status": "pending",
  "pendingCode": "XYZ789",
  "message": "Waiting for your partner to enter your code"
}
```

**Response (Unpaired):**
```json
{
  "status": "unpaired",
  "pairingCode": "ABC123",
  "pairingCodeExpiresAt": "2024-02-18T12:00:00.000Z"
}
```

### DELETE /pairing/request

Cancels any pending pairing request.

**Response:**
```json
{
  "message": "Pairing request cancelled"
}
```

### DELETE /pairing/unpair

Dissolves an existing partnership. Both users become unpaired and get new pairing codes.

**Response:**
```json
{
  "message": "Successfully unpaired"
}
```

## PairingService Methods

```typescript
// Initiate or complete pairing
await this.pairingService.requestPairing(userId, targetCode);

// Get current pairing status
await this.pairingService.getPairingStatus(userId);

// Cancel pending request
await this.pairingService.cancelPairingRequest(userId);

// Dissolve partnership
await this.pairingService.unpair(userId);
```

## Security Features

### Double Handshake Verification

The system requires **mutual consent**:
- User A entering User B's code alone is not enough
- User B must also enter User A's code
- Only when both requests exist does pairing complete

### Code Validation

- Codes are normalized to uppercase
- Format validation: exactly 6 alphanumeric characters
- Users cannot enter their own code
- Expired codes are rejected

### Atomic Transactions

Pairing completion uses a database transaction to ensure:
- Both users are updated simultaneously
- Pairing codes are cleared for both
- All pending requests are deleted
- No partial state is possible

### Cascade Delete

When a user is deleted:
- Their PairingRequests are automatically deleted (`onDelete: Cascade`)
- Their partner's `partnerId` is NOT automatically cleared (must be handled in app logic)

## File Structure

```
src/pairing/
├── pairing.module.ts      # Module definition
├── pairing.service.ts     # Business logic
├── pairing.controller.ts  # HTTP endpoints
├── index.ts               # Barrel export
└── dto/
    ├── pair-request.dto.ts    # Request DTO
    ├── pair-response.dto.ts   # Response DTO with PairingStatus enum
    └── index.ts
```

## Testing with curl

```bash
# User A enters User B's code
curl -X POST http://localhost:3000/pairing/pair \
  -H "Authorization: Bearer USER_A_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"code": "XYZ789"}'

# User B enters User A's code (completes pairing)
curl -X POST http://localhost:3000/pairing/pair \
  -H "Authorization: Bearer USER_B_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"code": "ABC123"}'

# Check status
curl http://localhost:3000/pairing/status \
  -H "Authorization: Bearer USER_TOKEN"

# Cancel pending request
curl -X DELETE http://localhost:3000/pairing/request \
  -H "Authorization: Bearer USER_TOKEN"

# Unpair from partner
curl -X DELETE http://localhost:3000/pairing/unpair \
  -H "Authorization: Bearer USER_TOKEN"
```

## State Machine

```
                    ┌──────────────┐
                    │   UNPAIRED   │
                    │ (has code)   │
                    └──────┬───────┘
                           │
                           │ POST /pairing/pair
                           │ (enters partner's code)
                           ▼
                    ┌──────────────┐
         ┌──────────│   PENDING    │──────────┐
         │          │ (waiting)    │          │
         │          └──────────────┘          │
         │                                    │
         │ DELETE /pairing/request            │ Partner enters
         │ (cancel)                           │ your code
         │                                    │
         ▼                                    ▼
  ┌──────────────┐                    ┌──────────────┐
  │   UNPAIRED   │◄───────────────────│    PAIRED    │
  │              │  DELETE /unpair    │ (partnerId   │
  └──────────────┘                    │  is set)     │
                                      └──────────────┘
```
