# Pairing UI (P0)

Flutter flow so a logged-in user without `partnerId` and `coupleId` finishes the existing double handshake and lands on a paired Home.

Nest pairing is used as-is. There is no regenerate endpoint. A missing or expired code is replaced on the next login (`ensurePairingCode`). Pull-to-refresh re-reads `GET /pairing/status` and `GET /auth/me`.

CEO decision (binding, from the couple record): after unpair, lists of the ENDED couple stay inaccessible to both. There is no archive window. A later pairing creates a new couple.

## Routes

| Route | Screen |
|---|---|
| `/pairing` | Your 6-char code, expiry, copy, share. Pending banner if a request is open. |
| `/pairing/enter` | Type the partner code. `POST /pairing/pair`. |
| `/pairing/waiting` | Poll `GET /pairing/status`. Cancel with `DELETE /pairing/request`. |
| `/couple` | Couple settings. **Desfazer o par** calls `DELETE /pairing/unpair`. |
| `/` | Paired Home. Unpaired sessions are redirected to `/pairing`. |

Logged-in users with neither `coupleId` nor `partnerId` cannot stay on Home, lists, or other couple routes. The router sends them to `/pairing`. Home itself, if it renders first, shows **Conectar com meu par** instead of the empty welcome.

A paired visit to `/pairing`, `/pairing/enter`, or `/pairing/waiting` goes back to `/`.

## Handshake

1. Each unpaired user sees `pairingCode` (6 chars) and `pairingCodeExpiresAt` from `GET /pairing/status` when `status` is `unpaired`. While a request is pending, that payload does not include the code; the screen keeps the code from `GET /auth/me` (`pairing.pairingCode`, `pairing.pairingCodeExpiresAt`).
2. User A enters B's code. `POST /pairing/pair` body is `{ "code": "XYZ789" }` (trimmed, uppercased). Response `status: "pending"` opens `/pairing/waiting`.
3. Waiting polls `GET /pairing/status` every 4 seconds and can be refreshed by hand. **Cancelar pedido** calls `DELETE /pairing/request` and returns to `/pairing`.
4. User B enters A's code. The same POST returns `status: "paired"` and `partner: { id, name }`. The app calls `sessionProvider.notifier.refresh()` (`GET /auth/me`) so `coupleId` and `partnerId` update without a new login, then opens `/`.
5. User A, still on the waiting screen or on the code screen with a pending banner, sees `status: "paired"` on the next poll, refreshes the session the same way, and opens `/`.
6. Home then shows the couple features (days together, mood, dates, question, feed, lists).

`POST /pairing/pair` does not return `coupleId`. The session refresh is what unlocks Home.

## Unpair

On `/couple`, **Desfazer o par** asks for confirmation and explains that the ended couple's lists stay inaccessible. Confirm calls `DELETE /pairing/unpair`, refreshes the session, and opens `/pairing` with a new code from the API.

The other person sees the unpaired session on the next Home refresh or when the app resumes (existing session refresh). Lists of the ended couple answer 403/404 and are not shown.

## PT-BR errors

| Situation | Copy |
|---|---|
| Not 6 letters or digits | O código precisa ter 6 letras ou números. |
| Own code | Você não pode usar o seu próprio código. |
| Expired code | Esse código expirou. Peça um código novo. |
| Unknown code | Não encontramos ninguém com esse código. |
| You are already paired | Você já está pareado. |
| Partner already paired | Essa pessoa já está pareada com outra. |
| Offline | Sem conexão. Verifique a internet e tente de novo. |
| Timeout | A conexão demorou demais. Tente de novo. |
| Cancel failed | Não foi possível cancelar o pedido. Tente de novo. |
| Unpair failed | Não foi possível desfazer o par. Tente de novo. |

## Tester smoke (two accounts)

Use two browsers or a browser plus a phone. Both accounts start logged in and unpaired (no partner). Production API: `https://couple2-api-production.up.railway.app`.

1. **A** signs in. The app opens **Parear** (`/pairing`), not an empty Home. A 6-character code and an expiry line are visible (**Válido até …**).
2. **A** taps **Copiar**. The code is on the clipboard. **Compartilhar** opens WhatsApp with the code text, or copies that text if the share target does not open.
3. **B** signs in and also lands on `/pairing`, with a different code.
4. **B** taps **Digitar o código do meu par**, enters A's code, and taps **Enviar pedido**. The app opens **Aguardando confirmação** and shows the code B sent.
5. **A** stays on the code screen. A banner **Pedido enviado** appears after **Atualizar** (or within a few seconds if A had already sent a code). A can also open **Acompanhar pedido**.
6. **A** enters B's code and taps **Enviar pedido**. This is the second half of the handshake. Both apps go to **Home**. The days-together card, mood, next date, question, feed, and **Our Lists** are available. Neither person has to sign out.
7. On B's waiting screen, if A completes first, B reaches Home without typing again (the screen polls). If B is the second to submit, B goes Home from the form.
8. **B** taps **Cancelar pedido** only in a throwaway run, before A confirms. The request disappears and B is back on the code screen. A new attempt still works.
9. From Home, open **Quando vocês começaram?** or **Editar data de início** (`/couple`). Tap **Desfazer o par**, read the warning about lists, tap **Manter o par** once to abort, then confirm **Desfazer**.
10. The person who confirmed returns to `/pairing` with a new code. The other person pulls to refresh Home, or backgrounds and reopens the app, and also lands on `/pairing`.
11. Lists created before the unpair do not show up for either person, including after they pair with someone else.

Negative checks, either account, before a successful pair:

- Entering your own code shows **Você não pode usar o seu próprio código.**
- A random 6-character code shows **Não encontramos ninguém com esse código.**
- A code past its expiry shows **Esse código expirou. Peça um código novo.** The owner signs out and back in to receive a new one.
- Airplane mode shows **Sem conexão. Verifique a internet e tente de novo.**
