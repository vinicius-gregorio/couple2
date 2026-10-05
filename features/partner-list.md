# Feature: PartnerList

## Concept

A polymorphic shared list system. A `PartnerList` belongs to a **pair**, not an individual user. Either partner can create, read, and update items on any list. The pair relationship already exists on the `users` table via `partner_id` — no need to duplicate it on the list model.

### List Types

| Type | Fields on each item |
|---|---|
| `SHOPPING_CART` | content (item name), quantity, isCompleted (bought) |
| `MOVIES` | content (title), platform, isCompleted (watched) |
| `MILESTONES` | content (title), date, icon, isCompleted |
| `TRAVEL` | content (destination), country, plannedDate, isCompleted (visited) |

All types share a single `ListItem` model. Type-specific fields (quantity, platform, date, etc.) are stored in a `metadata: Json?` column. `isCompleted` is universal.

---

## Backend Plan (`couple2_backend`)

### 1. Prisma Schema

Add to `prisma/schema.prisma`:

```prisma
enum ListType {
  SHOPPING_CART
  MOVIES
  MILESTONES
  TRAVEL
}

model PartnerList {
  id        String     @id @default(uuid())
  type      ListType
  name      String
  ownerId   String
  owner     User       @relation(fields: [ownerId], references: [id])
  items     ListItem[]
  createdAt DateTime   @default(now())
  updatedAt DateTime   @updatedAt
}

model ListItem {
  id          String      @id @default(uuid())
  listId      String
  list        PartnerList @relation(fields: [listId], references: [id], onDelete: Cascade)
  content     String
  metadata    Json?
  isCompleted Boolean     @default(false)
  addedById   String
  createdAt   DateTime    @default(now())
}
```

Also add the reverse relation on the `User` model:
```prisma
// inside model User
lists PartnerList[]
```

Run: `npx prisma migrate dev --name add-partner-list`

---

### 2. Shared List Guard

Create `src/lists/guards/shared-list.guard.ts`.

This guard mirrors the pattern of `pairing.guard.ts`. It resolves the list from the route param and verifies the requesting user is either the owner or the owner's partner.

```typescript
// src/lists/guards/shared-list.guard.ts
@Injectable()
export class SharedListGuard implements CanActivate {
  constructor(private readonly prisma: PrismaService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest<RequestWithUser>();
    const user = request.user;
    const listId = request.params.id;

    const list = await this.prisma.partnerList.findUnique({
      where: { id: listId },
    });

    if (!list) throw new NotFoundException('List not found');

    const isOwner = list.ownerId === user.id;
    const isPartner = list.ownerId === user.partnerId;

    if (!isOwner && !isPartner) {
      throw new ForbiddenException('You do not have access to this list');
    }

    return true;
  }
}
```

---

### 3. DTOs

`src/lists/dto/create-list.dto.ts`
```typescript
export class CreateListDto {
  type: ListType;
  name: string;
}
```

`src/lists/dto/add-item.dto.ts`
```typescript
export class AddItemDto {
  content: string;
  metadata?: Record<string, unknown>;
}
```

---

### 4. Lists Service

Create `src/lists/lists.service.ts`. Follows the same constructor-injection pattern as `PairingService`.

**Methods:**

- `getLists(userId: string)` — fetch all lists where `ownerId === userId OR ownerId === user.partnerId`. Use `prisma.partnerList.findMany` with `include: { items: true }`.
- `createList(userId: string, dto: CreateListDto)` — `prisma.partnerList.create`.
- `addItem(listId: string, userId: string, dto: AddItemDto)` — `prisma.listItem.create`.
- `toggleItem(itemId: string)` — `prisma.listItem.update` flipping `isCompleted`.
- `deleteItem(itemId: string)` — `prisma.listItem.delete`.
- `deleteList(listId: string)` — `prisma.partnerList.delete` (cascades to items).

---

### 5. Lists Controller

Create `src/lists/lists.controller.ts`. Follows the exact same guard + decorator pattern as `PairingController`.

```typescript
@Controller('lists')
@UseGuards(JwtAuthGuard, PairingGuard)  // must be paired to use lists
export class ListsController {
  constructor(private readonly listsService: ListsService) {}

  @Get()
  getLists(@GetUser() user: UserWithPartner) { ... }

  @Post()
  createList(@GetUser() user: UserWithPartner, @Body() dto: CreateListDto) { ... }

  @Post(':id/items')
  @UseGuards(SharedListGuard)
  addItem(@Param('id') id: string, @GetUser() user: UserWithPartner, @Body() dto: AddItemDto) { ... }

  @Patch('items/:id')
  toggleItem(@Param('id') id: string) { ... }

  @Delete('items/:id')
  deleteItem(@Param('id') id: string) { ... }

  @Delete(':id')
  @UseGuards(SharedListGuard)
  deleteList(@Param('id') id: string) { ... }
}
```

---

### 6. Lists Module

Create `src/lists/lists.module.ts`. Follow the same pattern as `PairingModule`:

```typescript
@Module({
  imports: [PrismaModule],
  controllers: [ListsController],
  providers: [ListsService, SharedListGuard],
})
export class ListsModule {}
```

Register it in `app.module.ts` imports array.

---

## Frontend Plan (`couple2_app`)

### 1. Domain Entities

**`lib/modules/lists/domain/entities/partner_list.dart`**

Plain Dart class with `fromJson`/`toJson` and `copyWith`, following the exact pattern of `User` entity:

```dart
class PartnerList {
  final String id;
  final String type; // 'SHOPPING_CART' | 'MOVIES' | 'MILESTONES' | 'TRAVEL'
  final String name;
  final String ownerId;
  final List<ListItem> items;
  final DateTime createdAt;

  // fromJson, toJson, copyWith
}
```

**`lib/modules/lists/domain/entities/list_item.dart`**

```dart
class ListItem {
  final String id;
  final String listId;
  final String content;
  final Map<String, dynamic>? metadata;
  final bool isCompleted;
  final String addedById;
  final DateTime createdAt;

  // fromJson, toJson, copyWith
}
```

Export both from `lib/modules/lists/domain/domain.dart`.

---

### 2. Repository (Data Layer)

**`lib/modules/lists/data/lists_repository.dart`**

Abstract interface + implementation, following the same pattern as `IAuthRepository` / `AuthRepository`:

```dart
abstract class IListsRepository {
  Future<List<PartnerList>> getLists();
  Future<PartnerList> createList(String type, String name);
  Future<ListItem> addItem(String listId, String content, Map<String, dynamic>? metadata);
  Future<ListItem> toggleItem(String itemId);
  Future<void> deleteItem(String itemId);
  Future<void> deleteList(String listId);
}

class ListsRepository implements IListsRepository {
  final ICPLHttpClient _httpClient;
  ListsRepository({required ICPLHttpClient httpClient}) : _httpClient = httpClient;

  // implementations calling the API
}
```

**`lib/modules/lists/data/lists_providers.dart`**

```dart
final listsRepositoryProvider = Provider<IListsRepository>((ref) {
  return ListsRepository(httpClient: GetIt.I<ICPLHttpClient>());
});
```

---

### 3. ViewModel

**`lib/modules/lists/ui/pages/lists/lists_viewmodel.dart`**

Following the `AuthViewModel` / `NotifierProvider` pattern:

```dart
class ListsState {
  final bool isLoading;
  final String? errorMessage;
  final List<PartnerList> lists;

  // copyWith
}

class ListsViewModel extends Notifier<ListsState> {
  IListsRepository get _repo => ref.read(listsRepositoryProvider);

  @override
  ListsState build() {
    _fetchLists();
    return ListsState(isLoading: true, lists: []);
  }

  Future<void> _fetchLists() { ... }
  Future<void> createList(String type, String name) { ... }
  Future<void> addItem(String listId, String content, Map<String, dynamic>? metadata) { ... }
  Future<void> toggleItem(String listId, String itemId) { ... }
  Future<void> deleteItem(String listId, String itemId) { ... }
}

final listsViewModelProvider = NotifierProvider<ListsViewModel, ListsState>(ListsViewModel.new);
```

---

### 4. UI Pages

**`lib/modules/lists/ui/pages/lists/lists_page.dart`** — `ConsumerWidget`

- Shows all lists for the pair.
- Uses `ref.watch(listsViewModelProvider)` and `.when()` for AsyncValue handling.
- FloatingActionButton to create a new list (shows a bottom sheet to pick type + name).
- Tapping a list navigates to the list detail page.

**`lib/modules/lists/ui/pages/list_detail/list_detail_page.dart`** — `ConsumerStatefulWidget`

- Shows items for a specific list.
- TextField at the bottom to add a new item.
- Each item has a checkbox that calls `toggleItem`.
- Swipe-to-delete or trailing delete icon calls `deleteItem`.
- Renders metadata (e.g., quantity badge for Shopping, platform chip for Movies) based on `list.type`.

---

### 5. Routing

Add routes to the lists module following the pattern from `auth/routing/`:

**`lib/modules/lists/routing/routes.dart`**
```dart
abstract final class ListsRoutes {
  static const lists = '/lists';
  static const listDetail = '/lists/:id';
}
```

**`lib/modules/lists/routing/routing.dart`**
```dart
final listsRoutes = [
  GoRoute(path: ListsRoutes.lists, builder: (_, __) => const ListsPage()),
  GoRoute(path: ListsRoutes.listDetail, builder: (_, state) =>
    ListDetailPage(listId: state.pathParameters['id']!)),
];
```

Register `...listsRoutes` inside `router.dart`, within the authenticated shell route (where home already lives). The router redirect logic already handles auth — no changes needed there.

---

### 6. Home Page — Entry Point

Add a navigation button/card on `home_page.dart` that pushes to `ListsRoutes.lists`. No other changes needed to existing files.

---

## File Checklist

### Backend
- [x] `prisma/schema.prisma` — add `ListType` enum, `PartnerList`, `ListItem` models
- [x] `src/lists/dto/create-list.dto.ts`
- [x] `src/lists/dto/add-item.dto.ts`
- [x] `src/lists/guards/shared-list.guard.ts`
- [x] `src/lists/lists.service.ts`
- [x] `src/lists/lists.controller.ts`
- [x] `src/lists/lists.module.ts`
- [x] `src/app.module.ts` — import `ListsModule`

### Frontend
- [x] `lib/modules/lists/domain/entities/partner_list.dart`
- [x] `lib/modules/lists/domain/entities/list_item.dart`
- [x] `lib/modules/lists/domain/domain.dart`
- [x] `lib/modules/lists/data/lists_repository.dart`
- [x] `lib/modules/lists/data/lists_providers.dart`
- [x] `lib/modules/lists/ui/pages/lists/lists_page.dart`
- [x] `lib/modules/lists/ui/pages/lists/lists_viewmodel.dart`
- [x] `lib/modules/lists/ui/pages/list_detail/list_detail_page.dart`
- [x] `lib/modules/lists/routing/routes.dart`
- [x] `lib/modules/lists/routing/routing.dart`
- [x] `lib/app/routing/router.dart` — add `...listsRoutes`
- [x] `lib/app/ui/pages/home/home_page.dart` — add entry point to lists
