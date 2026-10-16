import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/core.dart';
import '../../../data/lists_providers.dart';
import '../../../data/lists_repository.dart';
import '../../../domain/domain.dart';

final listsViewModelProvider = NotifierProvider<ListsViewModel, ListsState>(
  ListsViewModel.new,
);

class ListsState {
  final bool isLoading;
  final String? errorMessage;
  final String? actionError;
  final List<PartnerList> lists;
  final bool needsPairing;
  final Set<String> addingListIds;
  final Set<String> deletingListIds;

  const ListsState({
    this.isLoading = false,
    this.errorMessage,
    this.actionError,
    this.lists = const [],
    this.needsPairing = false,
    this.addingListIds = const {},
    this.deletingListIds = const {},
  });

  ListsState copyWith({
    bool? isLoading,
    String? errorMessage,
    String? actionError,
    bool clearActionError = false,
    List<PartnerList>? lists,
    bool? needsPairing,
    Set<String>? addingListIds,
    Set<String>? deletingListIds,
  }) {
    return ListsState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      actionError: clearActionError
          ? null
          : (actionError ?? this.actionError),
      lists: lists ?? this.lists,
      needsPairing: needsPairing ?? this.needsPairing,
      addingListIds: addingListIds ?? this.addingListIds,
      deletingListIds: deletingListIds ?? this.deletingListIds,
    );
  }
}

class ListsViewModel extends Notifier<ListsState> {
  final Set<String> _inflight = {};
  var _pendingSeq = 0;
  var _fetchGen = 0;

  @override
  ListsState build() {
    _fetchLists();
    return const ListsState(isLoading: true);
  }

  IListsRepository get _repo => ref.read(listsRepositoryProvider);

  Future<void> _fetchLists() async {
    final gen = ++_fetchGen;
    try {
      final lists = await _repo.getLists();
      if (gen != _fetchGen) return;
      state = ListsState(
        isLoading: false,
        lists: _keepPending(_preserveLocalItems(lists)),
        addingListIds: state.addingListIds,
        deletingListIds: state.deletingListIds,
      );
    } on CPLHttpForbiddenException {
      if (gen != _fetchGen) return;
      state = const ListsState(isLoading: false, needsPairing: true);
    } catch (e) {
      if (gen != _fetchGen) return;
      if (state.lists.isNotEmpty) {
        state = state.copyWith(isLoading: false);
        return;
      }
      state = ListsState(isLoading: false, errorMessage: userFacingError(e));
    }
  }

  Future<void> refresh() => _fetchLists();

  /// Returns null on success, or a PT-BR message when the request fails.
  Future<String?> createList(
    String type,
    String name, {
    String? visibility,
  }) async {
    const key = 'create-list';
    if (!_inflight.add(key)) {
      return 'Aguarde o pedido atual.';
    }
    state = state.copyWith(clearActionError: true);
    try {
      final list = await _repo.createList(type, name, visibility: visibility);
      state = state.copyWith(lists: [list, ...state.lists]);
      return null;
    } catch (error) {
      return userFacingError(error);
    } finally {
      _inflight.remove(key);
    }
  }

  /// Inserts a pending row immediately. On failure the row is removed and the
  /// caller should keep the draft so the person can try again.
  Future<bool> addItem(
    String listId,
    String content,
    Map<String, dynamic>? metadata,
  ) async {
    final key = 'add:$listId';
    if (!_inflight.add(key)) return false;
    _fetchGen++;
    final tempId = 'pending-${_pendingSeq++}';
    final temp = ListItem(
      id: tempId,
      listId: listId,
      content: content,
      metadata: metadata,
      isCompleted: false,
      addedById: 'pending',
      createdAt: DateTime.now(),
      pending: true,
    );
    state = state.copyWith(
      lists: _map(listId, (list) => list.copyWith(items: [...list.items, temp])),
      addingListIds: {...state.addingListIds, listId},
      clearActionError: true,
    );
    try {
      final item = await _repo.addItem(listId, content, metadata);
      _fetchGen++;
      state = state.copyWith(
        lists: _map(listId, (list) => _swapPending(list, tempId, item)),
        addingListIds: ({...state.addingListIds}..remove(listId)),
        clearActionError: true,
      );
      return true;
    } catch (error) {
      state = state.copyWith(
        lists: _map(
          listId,
          (list) => list.copyWith(
            items: [
              for (final current in list.items)
                if (current.id != tempId) current,
            ],
          ),
        ),
        addingListIds: ({...state.addingListIds}..remove(listId)),
        actionError: userFacingError(error),
      );
      return false;
    } finally {
      _inflight.remove(key);
    }
  }

  Future<void> toggleItem(String listId, String itemId) async {
    final key = 'toggle:$itemId';
    if (!_inflight.add(key)) return;
    final current = _find(listId, itemId);
    if (current == null || current.pending) {
      _inflight.remove(key);
      return;
    }
    state = state.copyWith(
      lists: _replace(
        listId,
        itemId,
        current.copyWith(isCompleted: !current.isCompleted),
      ),
      clearActionError: true,
    );
    try {
      final updated = await _repo.toggleItem(itemId);
      state = state.copyWith(lists: _replace(listId, itemId, updated));
    } catch (error) {
      state = state.copyWith(
        lists: _replace(listId, itemId, current),
        actionError: userFacingError(error),
      );
    } finally {
      _inflight.remove(key);
    }
  }

  Future<void> deleteItem(String listId, String itemId) async {
    final key = 'delete:$itemId';
    if (!_inflight.add(key)) return;
    final current = _find(listId, itemId);
    if (current == null || current.pending) {
      _inflight.remove(key);
      return;
    }
    state = state.copyWith(
      lists: _replace(listId, itemId, current.copyWith(pending: true)),
      clearActionError: true,
    );
    try {
      await _repo.deleteItem(itemId);
      state = state.copyWith(
        lists: _map(
          listId,
          (list) => list.copyWith(
            items: [
              for (final item in list.items)
                if (item.id != itemId) item,
            ],
          ),
        ),
      );
    } catch (error) {
      state = state.copyWith(
        lists: _replace(listId, itemId, current),
        actionError: userFacingError(error),
      );
    } finally {
      _inflight.remove(key);
    }
  }

  Future<void> deleteList(String listId) async {
    final key = 'delete-list:$listId';
    if (!_inflight.add(key)) return;
    state = state.copyWith(
      deletingListIds: {...state.deletingListIds, listId},
      clearActionError: true,
    );
    try {
      await _repo.deleteList(listId);
      final deleting = ({...state.deletingListIds}..remove(listId));
      state = state.copyWith(
        lists: state.lists.where((list) => list.id != listId).toList(),
        deletingListIds: deleting,
      );
    } catch (error) {
      final deleting = ({...state.deletingListIds}..remove(listId));
      state = state.copyWith(
        deletingListIds: deleting,
        actionError: userFacingError(error),
      );
    } finally {
      _inflight.remove(key);
    }
  }

  void clearActionError() {
    if (state.actionError == null) return;
    state = state.copyWith(clearActionError: true);
  }

  /// A payload that omits `items` must not wipe rows we already showed.
  /// An explicit empty list is the server's answer, including a partner delete.
  List<PartnerList> _preserveLocalItems(List<PartnerList> fresh) {
    return preserveLocalItems(state.lists, fresh);
  }

  List<PartnerList> _keepPending(List<PartnerList> fresh) {
    final pending = <String, List<ListItem>>{};
    for (final list in state.lists) {
      final rows = [
        for (final item in list.items)
          if (item.pending && item.id.startsWith('pending-')) item,
      ];
      if (rows.isNotEmpty) pending[list.id] = rows;
    }
    if (pending.isEmpty) return fresh;
    return [
      for (final list in fresh)
        if (pending[list.id] == null)
          list
        else
          list.copyWith(items: [...list.items, ...pending[list.id]!]),
    ];
  }

  PartnerList _swapPending(PartnerList list, String tempId, ListItem item) {
    final hasTemp = list.items.any((current) => current.id == tempId);
    if (hasTemp) {
      return list.copyWith(
        items: [
          for (final current in list.items)
            if (current.id == tempId) item else current,
        ],
      );
    }
    if (list.items.any((current) => current.id == item.id)) return list;
    return list.copyWith(items: [...list.items, item]);
  }

  ListItem? _find(String listId, String itemId) {
    for (final list in state.lists) {
      if (list.id != listId) continue;
      for (final item in list.items) {
        if (item.id == itemId) return item;
      }
    }
    return null;
  }

  List<PartnerList> _map(
    String listId,
    PartnerList Function(PartnerList list) update,
  ) {
    return [
      for (final list in state.lists)
        if (list.id == listId) update(list) else list,
    ];
  }

  List<PartnerList> _replace(String listId, String itemId, ListItem next) {
    return _map(
      listId,
      (list) => list.copyWith(
        items: [
          for (final item in list.items)
            if (item.id == itemId) next else item,
        ],
      ),
    );
  }
}
