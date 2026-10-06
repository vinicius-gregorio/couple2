# Couple record + datas importantes (Feature #1)

> Canonical extract from couple2-specs-features-1-6.md for implementation.
> CEO decision (binding): on unpair, lists of the ENDED couple stay inaccessible to both — no 30-day archive.

**Convenções para todas as features novas**

- Recursos novos ficam escopados por `coupleId`. A consulta no service sempre usa `where: { id, coupleId: user.coupleId }`. Recurso fora do casal → **404** (não revela existência).
- Guard padrão das rotas de casal: `JwtAuthGuard` + `CoupleGuard` (novo, #1).
- Todo DTO novo usa `class-validator`, com `ValidationPipe({ whitelist: true, transform: true })` global (introduzido em #1).
- Datas "de calendário" (aniversário, data da pergunta) usam `@db.Date`. Instantes usam `DateTime` em UTC. O "hoje" do casal é calculado com `Couple.timezone`.

**Grafo de dependências:** P0 → #1 → #2 → {#3, #4, #5}. #6 depende de #1 (coupleId nas listas e guard de item) e usa #2 opcionalmente.

---

## 1. Couple record + datas importantes

### Problema / por quê
O casal hoje é implícito: dois `users.partnerId` apontando um para o outro. Faltam três coisas:
- um lugar para dados do relacionamento (data de início, fuso, datas importantes);
- uma chave estável (`coupleId`) para as features 2–6;
- um dono correto para as listas. Hoje a posse é por `ownerId`, o que gera o vazamento pós-re-pairing e o IDOR nos itens.

O "dias juntos" e os lembretes de datas são o gancho emocional mais barato do app.

### User stories
- **A:** quero cadastrar a data em que começamos a namorar e ver "X dias juntos" na Home.
- **B:** quero ver o aniversário de A e ser lembrado antes.
- **A/B:** quero cadastrar datas nossas (primeiro beijo, casamento) com recorrência anual.
- **A/B:** se nos separarmos no app, quero que o novo parceiro de qualquer um de nós não veja nossas listas.

### Escopo
**In**
- Tabela `couples` criada no `completePairing` (mesma transação) e encerrada no `unpair`.
- Backfill para pares existentes.
- `anniversaryDate`, `timezone`, `User.birthDate` e datas customizadas.
- Cálculo de `daysTogether` e de "próximas datas".
- `coupleId` em `PartnerList`, com backfill.
- Guard de item de lista (correção do IDOR).
- `ValidationPipe` global.
- `GET /auth/me` passa a retornar `coupleId`.

**Out**
- Foto do casal (Storage fica para depois).
- Exportar ou arquivar dados de casal encerrado.
- Reativar casal antigo (um re-pairing das mesmas pessoas gera um casal novo).
- Lembretes por push: o modelo e a regra ficam aqui, o envio vem em #2.

### Modelo de dados
```prisma
enum CoupleStatus { ACTIVE ENDED }
enum CoupleDateType { CUSTOM }            // aniversário de namoro e birthdays não ficam aqui
enum Recurrence { NONE YEARLY }

model Couple {
  id              String       @id @default(uuid())
  userAId         String                     // menor UUID do par (ordem canônica)
  userBId         String
  userA           User         @relation("CoupleUserA", fields: [userAId], references: [id])
  userB           User         @relation("CoupleUserB", fields: [userBId], references: [id])
  members         User[]       @relation("ActiveCouple")
  status          CoupleStatus @default(ACTIVE)
  pairedAt        DateTime     @default(now())
  endedAt         DateTime?
  anniversaryDate DateTime?    @db.Date      // início do relacionamento (informado pelo casal)
  timezone        String       @default("America/Sao_Paulo") // IANA
  dates           CoupleDate[]
  lists           PartnerList[]
  createdAt       DateTime     @default(now())
  updatedAt       DateTime     @updatedAt
  @@index([userAId, status])
  @@index([userBId, status])
  @@map("couples")
}

model CoupleDate {
  id          String         @id @default(uuid())
  coupleId    String
  couple      Couple         @relation(fields: [coupleId], references: [id], onDelete: Cascade)
  type        CoupleDateType @default(CUSTOM)
  title       String         // ≤ 60
  date        DateTime       @db.Date
  recurrence  Recurrence     @default(YEARLY)
  createdById String
  createdAt   DateTime       @default(now())
  updatedAt   DateTime       @updatedAt
  @@index([coupleId])
  @@map("couple_dates")
}

// User (adições)
//   birthDate   DateTime? @db.Date
//   coupleId    String?                      // casal ATIVO atual (espelha partnerId)
//   couple      Couple?   @relation("ActiveCouple", fields: [coupleId], references: [id])
//   couplesAsA  Couple[]  @relation("CoupleUserA")
//   couplesAsB  Couple[]  @relation("CoupleUserB")

// PartnerList (adição)
//   coupleId    String?                      // nullable só durante o backfill; NOT NULL na migration seguinte
//   couple      Couple?   @relation(fields: [coupleId], references: [id])
//   @@index([coupleId])
```

**Migrations**
1. Cria `couples`/`couple_dates` e as colunas novas.
2. Backfill em SQL: para cada par com `u.id < u.partnerId`, cria um `Couple ACTIVE` com `pairedAt = LEAST(updatedAt)` e atualiza `users.coupleId` dos dois. Depois, `partner_lists.coupleId` recebe o `coupleId` do owner. Listas de usuários sem par ficam `NULL`.
3. Índices únicos parciais `WHERE status='ACTIVE'` em `userAId` e em `userBId`.
4. Numa release seguinte, `coupleId NOT NULL` (as listas órfãs de usuários sem par são associadas no próximo pairing).

### API
| Método | Rota | Guards | Notas |
|---|---|---|---|
| — | `POST /pairing/pair` (existente) | `JwtAuthGuard` | `completePairing` cria o `Couple` e grava `users.coupleId` na mesma `$transaction`. Também associa as listas `coupleId NULL` dos dois ao casal novo. |
| — | `DELETE /pairing/unpair` (existente) | `JwtAuthGuard`, `PairingGuard` | Na mesma transação: `status=ENDED`, `endedAt=now()`, `users.coupleId=null`. |
| GET | `/auth/me` (existente) | `JwtAuthGuard` | Passa a incluir `coupleId` e `user.birthDate` (aditivo, não quebra). |
| GET | `/couple` | `JwtAuthGuard`, `CoupleGuard` | Retorna `{ id, pairedAt, anniversaryDate, timezone, daysTogether, partner{ id,name,picture,birthDate }, upcoming: [{kind, title, date, inDays}] }`. `upcoming` cobre os próximos 60 dias (anniversary, birthdays dos dois, CoupleDates). |
| PATCH | `/couple` | `JwtAuthGuard`, `CoupleGuard` | `{ anniversaryDate?, timezone? }`. Qualquer um dos dois pode editar. `timezone` é validado contra a lista IANA. |
| PATCH | `/users/me` | `JwtAuthGuard` | `{ birthDate? }`. Novo `UsersController`. Só o próprio usuário edita. |
| GET/POST | `/couple/dates` | `JwtAuthGuard`, `CoupleGuard` | Lista e cria. |
| PATCH/DELETE | `/couple/dates/:id` | `JwtAuthGuard`, `CoupleGuard` | Escopo por `coupleId` (404 fora do casal). |
| — | `/lists*` (existente) | `JwtAuthGuard`, **`CoupleGuard`** (substitui `PairingGuard`) | `getLists`/`createList` passam a usar `coupleId`. `SharedListGuard` compara `list.coupleId === user.coupleId`. |
| — | `PATCH/DELETE /lists/items/:id` | + **`SharedListItemGuard`** (novo) | Resolve item → lista → `coupleId`. Item inexistente ou de outro casal → 404. |

**`CoupleGuard` (novo, em `src/couple/guards`):** exige `user.partnerId && user.coupleId`, senão 403 com a mesma mensagem do `PairingGuard`. Carrega o `Couple` ACTIVE e o coloca em `request.couple`. Vem com o decorator `@GetCouple()`, no padrão de `@GetPartner()`.

**`daysTogether`:** diferença em dias de calendário entre `anniversaryDate` (ou `pairedAt`, se nulo) e "hoje" em `couple.timezone`, contando o primeiro dia como 1. Lib: `date-fns-tz` (dependência nova).

### App Flutter
- **Novo módulo `couple`** (via `create_module.sh`): `data/couple_repository.dart` (`ICoupleRepository`), `couple_providers.dart`, `domain/entities/couple.dart` e `couple_date.dart`, e `ui/pages/...`.
- **Sessão:** novo `sessionProvider` (`AsyncNotifier`) que chama `GET /auth/me` no boot, no resume e depois do pairing. Ele substitui a leitura estática de `currentUserProvider`, o que corrige o `partnerId` desatualizado.
- **Home:** card "**X dias juntos**" + "Próxima data: aniversário de B em 12 dias". O aniversário de quem está vendo a Home sai como "Seu aniversário" (`upcoming.self`); o do parceiro continua "aniversário de \<nome\>". Se não houver `anniversaryDate`, mostra o CTA "Quando vocês começaram?". Salvar `/couple` aberto direto (sem pilha) volta para a Home. Datas importantes: tocar a linha ou o lápis edita; excluir pede confirmação.
- **Telas:**
  - `CoupleSettingsPage`: data de início (DatePicker) e fuso (default = fuso do device).
  - `ImportantDatesPage`: lista de próximas datas + bottom sheet para adicionar/editar CoupleDate.
  - Campo "Meu aniversário" em `ProfileSheet`, aberta pelo avatar da AppBar.
- **Rotas:** `CoupleRoutes.settings = '/couple'` e `CoupleRoutes.dates = '/couple/dates'`, registradas em `router.dart` com `...coupleRoutes`.
- **Lists:** sem mudança de UI. Com a troca de guard, o 403 de "sem par" deve abrir o fluxo P0.

### Critérios de aceite
1. Pairing completo → existe exatamente 1 `couples` ACTIVE com os dois usuários, e os dois têm `users.coupleId` igual. Falha no meio da transação → nem `partnerId` nem `Couple` persistem.
2. `unpair` → casal com `status=ENDED` e `endedAt` preenchido, os dois com `coupleId=null`. `GET /couple` → 403.
3. A pareia com B, cria a lista L, faz unpair e pareia com C → `GET /lists` de C **não** contém L, e `GET /lists/L` / `POST /lists/L/items` por C → 404.
4. Usuário de outro casal chama `PATCH /lists/items/:id` ou `DELETE /lists/items/:id` com um ID válido → 404, e o item não muda.
5. Rodar a migration de backfill num banco com N pares → N casais criados. Rodar de novo não cria duplicatas (idempotente).
6. `anniversaryDate = 2024-10-05` com `timezone = America/Sao_Paulo` → em 05/10/2026 às 23:30 PT, `daysTogether = 731`. Às 00:10 do dia seguinte → 732.
7. Birthday em 29/02 em ano não bissexto → aparece em `upcoming` como 28/02.
8. `PATCH /users/me` com `birthDate` no futuro ou campo desconhecido → 400 (ValidationPipe com whitelist).
9. Home mostra o card de dias juntos depois do pairing sem precisar de logout/login.

### Dependências
- P0 (telas de pairing).
- Base para #2, #3, #4, #5 e #6.

### Riscos / notas
- **Decisão de produto (CEO, vinculante, implementada):** depois do unpair, as listas do casal encerrado ficam inacessíveis para os dois. Não há arquivo de 30 dias. Um re-pairing cria um casal novo e só herda listas com `coupleId` NULL.
- `partnerId` continua sendo a fonte do `PairingGuard`. Durante a transição, `partnerId` e `coupleId` precisam ser escritos sempre juntos. Teste e2e cobrindo isso é obrigatório.
- A lista `MILESTONES` continua existindo e serve para conquistas. As datas recorrentes ficam em `CoupleDate`. A UI deixa a diferença clara.
- `timezone` divergente entre os dois parceiros: v1 usa um fuso por casal.

---
