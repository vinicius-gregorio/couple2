# Push + feed de atividade (Feature #2)

> Canonical extract from couple2-specs-features-1-6.md for implementation.
> Depends on #1 (Couple + coupleId) which is already on main.
> Standing merge rule: Tech Manager merges on Tester PASS without asking CEO — Coder must NOT merge.

**Convenções para todas as features novas**

- Recursos novos ficam escopados por `coupleId`. A consulta no service sempre usa `where: { id, coupleId: user.coupleId }`. Recurso fora do casal → **404** (não revela existência).
- Guard padrão das rotas de casal: `JwtAuthGuard` + `CoupleGuard` (novo, #1).
- Todo DTO novo usa `class-validator`, com `ValidationPipe({ whitelist: true, transform: true })` global (introduzido em #1).
- Datas "de calendário" (aniversário, data da pergunta) usam `@db.Date`. Instantes usam `DateTime` em UTC. O "hoje" do casal é calculado com `Couple.timezone`.

**Grafo de dependências:** P0 → #1 → #2 → {#3, #4, #5}. #6 depende de #1 (coupleId nas listas e guard de item) e usa #2 opcionalmente.

---

## 2. Push + feed de atividade

### Problema / por quê
O parceiro não sabe quando o outro adicionou um filme, respondeu a pergunta ou mandou um nudge. Sem push e feed, o app depende de o usuário lembrar de abri-lo. #3, #4 e #5 só funcionam bem com notificação. O `firebase-admin` já está no projeto e o FCM vem nele.

### User stories
- **A:** quando B completar um item da lista de compras, quero receber um push e ver isso no feed.
- **B:** quero um feed "o que rolou" com as ações de A e as minhas, ordenado por tempo.
- **A/B:** quero desligar categorias de push e definir horário de silêncio.
- **A/B:** ao tocar no push, quero cair direto na tela certa.

### Escopo
**In**
- Registro de device tokens (iOS/Android).
- `ActivityService.record()` chamado pelos módulos.
- Envio FCM para o parceiro.
- Remoção de tokens inválidos.
- Feed paginado com contador de não lidos.
- Preferências por categoria + quiet hours.
- Job diário de "datas próximas" (#1): D-7, D-1 e D0 às 09:00 no fuso do casal.
- Instrumentar lists: `LIST_CREATED`, `LIST_ITEM_ADDED`, `LIST_ITEM_COMPLETED` (só na transição para `true`).

**Out**
- Web push (VAPID/service worker).
- E-mail.
- Supabase Realtime: o app não usa Supabase client e o JWT do app não é JWT do Supabase, então RLS não se aplica. O feed atualiza por pull-to-refresh, ao receber push e no resume.
- Agrupamento inteligente por ML.
- Push para o próprio autor.

### Modelo de dados
```prisma
enum DevicePlatform { IOS ANDROID WEB }
enum ActivityType {
  LIST_CREATED LIST_ITEM_ADDED LIST_ITEM_COMPLETED
  COUPLE_DATE_UPCOMING COUPLE_UPDATED
  QUESTION_ANSWERED QUESTION_UNLOCKED          // #3
  MOOD_SHARED NUDGE_SENT                       // #4
  DATE_PLAN_PROPOSED DATE_PLAN_ACCEPTED DATE_PLAN_DECLINED
  DATE_PLAN_COUNTERED DATE_PLAN_CANCELLED DATE_PLAN_DONE  // #5
}

model DeviceToken {
  id         String         @id @default(uuid())
  userId     String
  user       User           @relation(fields: [userId], references: [id], onDelete: Cascade)
  token      String         @unique
  platform   DevicePlatform
  appVersion String?
  locale     String?
  lastSeenAt DateTime       @default(now())
  createdAt  DateTime       @default(now())
  @@index([userId])
  @@map("device_tokens")
}

model ActivityEvent {
  id         String       @id @default(uuid())
  coupleId   String
  couple     Couple       @relation(fields: [coupleId], references: [id], onDelete: Cascade)
  actorId    String?      // null = sistema (ex.: COUPLE_DATE_UPCOMING)
  type       ActivityType
  entityType String       // "PartnerList" | "ListItem" | "CoupleQuestion" | ...
  entityId   String
  payload    Json?        // snapshot mínimo para render (ex.: { listName, content })
  createdAt  DateTime     @default(now())
  @@index([coupleId, createdAt(sort: Desc)])
  @@map("activity_events")
}

model NotificationPreference {
  userId         String   @id
  user           User     @relation(fields: [userId], references: [id], onDelete: Cascade)
  pushEnabled    Boolean  @default(true)
  lists          Boolean  @default(true)
  importantDates Boolean  @default(true)
  dailyQuestion  Boolean  @default(true)   // #3
  mood           Boolean  @default(true)   // #4
  nudges         Boolean  @default(true)   // #4
  datePlans      Boolean  @default(true)   // #5
  quietStartMin  Int?     // minutos desde 00:00 no fuso do casal; ex.: 1380 = 23:00
  quietEndMin    Int?
  updatedAt      DateTime @updatedAt
  @@map("notification_preferences")
}

// User (adição): feedSeenAt DateTime?   // não lidos = eventos do parceiro com createdAt > feedSeenAt
```

### API
| Método | Rota | Guards | Notas |
|---|---|---|---|
| POST | `/devices` | `JwtAuthGuard` | Upsert por `token` com `{ token, platform, appVersion?, locale? }`. Se o token pertencia a outro user, é reatribuído (troca de conta no mesmo device). |
| DELETE | `/devices/:token` | `JwtAuthGuard` | Chamado no logout antes de `prefs.clear()`. Só remove token do próprio user. |
| GET | `/feed?cursor&limit=20` | `JwtAuthGuard`, `CoupleGuard` | Paginação por cursor `(createdAt,id)` desc. Inclui eventos dos dois e do sistema. |
| GET | `/feed/unread-count` | `JwtAuthGuard`, `CoupleGuard` | Conta eventos com `actorId = partner` e `createdAt > feedSeenAt`. |
| POST | `/feed/seen` | `JwtAuthGuard`, `CoupleGuard` | `feedSeenAt = now()`. |
| GET/PATCH | `/notifications/preferences` | `JwtAuthGuard` | Cria com defaults no primeiro GET. |

**Backend interno (novo `NotificationsModule`)**
- `ActivityService.record({ coupleId, actorId, type, entity, payload, push?: PushSpec })`. O insert acontece **depois** do commit da operação principal. A falha de push nunca derruba a requisição: fica em try/catch e é logada.
- `PushSender` é uma interface com duas implementações:
  - `FcmPushSender`: `admin.messaging().sendEachForMulticast`, reaproveitando `ensureFirebase()`.
  - `LogPushSender`: quando `PUSH_DRIVER=log` ou sem credencial. É o default em dev.
- Erros `messaging/registration-token-not-registered` e `invalid-argument` → apaga o token.
- A mensagem leva `notification{title,body}` + `data{ type, route }`, por exemplo `route: "/lists/<id>"`. `collapseKey`/`thread-id` vai por entidade.
- **Anti-spam:** no máximo 1 push por lista a cada 5 min por destinatário (consulta ao último evento do mesmo tipo/entidade). Os demais vão só para o feed.
- Respeita `pushEnabled`, a categoria e as quiet hours (fora do horário só entra no feed).
- **Scheduler:** `@nestjs/schedule` (dependência nova). Job a cada hora que processa os casais cujo horário local = 09:00 → `COUPLE_DATE_UPCOMING`. A deduplicação usa `(coupleId, type, entityId, date)` no `payload` com índice ou verificação prévia.

### App Flutter
- **Dependências:** `firebase_messaging`, `flutter_local_notifications` (exibir push em foreground no Android).
- **Novo módulo `notifications`:**
  - `PushService`: pede permissão **depois do pairing** (não no primeiro boot), faz `getToken` → `POST /devices`, escuta `onTokenRefresh` e trata `onMessageOpenedApp`/`getInitialMessage` → `router.push(data.route)`.
  - `NotificationPreferencesPage` (toggles + quiet hours).
  - `AuthRepository.logOut` passa a chamar `DELETE /devices/:token` antes do `prefs.clear()`.
- **Novo módulo `feed`:**
  - `FeedViewModel` (`Notifier` com paginação) e `FeedPage` com ícone por `type` e texto montado do `payload`, com pull-to-refresh.
  - Na Home: sino com badge de `unread-count` e preview dos últimos 3 eventos.
  - Abrir o feed → `POST /feed/seen`.
- **Config nativa:** chave APNs no projeto Firebase `couple42-27692`, capability Push/Background Modes no iOS e `POST_NOTIFICATIONS` (Android 13+).

### Critérios de aceite
1. Login em 2 devices → 2 registros em `device_tokens`. Logout num deles → resta 1.
2. B marca um item como concluído → A recebe 1 push com `data.route=/lists/<listId>`. B não recebe nada. O feed dos dois mostra `LIST_ITEM_COMPLETED`.
3. B adiciona 5 itens à mesma lista em 2 min → A recebe 1 push e o feed tem 5 eventos.
4. FCM devolve token não registrado → o token some de `device_tokens` no mesmo envio.
5. `PUSH_DRIVER=log` sem service account → as rotas de lista funcionam e o push sai só no log.
6. A desliga `lists` → não recebe push de listas, mas o feed continua registrando.
7. Quiet hours 23:00–07:00 → evento às 23:30 no fuso do casal não gera push.
8. Aniversário de B daqui a 7 dias → os dois recebem exatamente 1 push às 09:00 locais. Reprocessar o job não duplica.
9. `GET /feed` de um usuário de outro casal nunca retorna eventos deste casal. A paginação por cursor não repete itens.
10. Tocar no push com o app fechado abre a tela da rota.

### Dependências
- #1: `coupleId`, `timezone`, datas.
- É dependência dura de #4 (nudge). Também é usada por #3, #5 e, opcionalmente, #6.

### Riscos / notas
- Credencial FCM em produção = mesma service account do `verifyIdToken`. Confirmar escopo IAM (`firebasecloudmessaging`).
- **Privacidade:** o texto do push aparece na lock screen. Conteúdo de itens vai truncado, e #6 **nunca** gera evento.
- O `payload` é snapshot. Se o item for apagado, o feed mostra o texto antigo, e isso é aceito (o tap trata 404 com "item removido").
- Envio síncrono pós-commit é suficiente para o volume atual. Se crescer, mover para fila (pg-boss sobre o mesmo Postgres).
