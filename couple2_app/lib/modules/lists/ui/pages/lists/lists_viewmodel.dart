import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/external/http_client/exceptions/cpl_http_forbidden_exception.dart';
import '../../../data/lists_providers.dart';
import '../../../data/lists_repository.dart';
import '../../../domain/domain.dart';

final listsViewModelProvider =
    NotifierProvider<ListsViewModel, ListsState>(ListsViewModel.new);

class ListsState {
  final bool isLoading;
  final String? errorMessage;
  final List<PartnerList> lists;
  final bool needsPairing;

  const ListsState({
    this.isLoading = false,
    this.errorMessage,
    this.lists = const [],
    this.needsPairing = false,
  });

  ListsState copyWith({
    bool? isLoading,
    String? errorMessage,
    List<PartnerList>? lists,
    bool? needsPairing,
  }) {
    return ListsState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      lists: lists ?? this.lists,
      needsPairing: needsPairing ?? this.needsPairing,
    );
  }
}

class ListsViewModel extends Notifier<ListsState> {
  @override
  ListsState build() {
    _fetchLists();
    return const ListsState(isLoading: true);
  }

  IListsRepository get _repo => ref.read(listsRepositoryProvider);

  Future<void> _fetchLists() async {
    try {
      final lists = await _repo.getLists();
      state = ListsState(isLoading: false, lists: lists);
    } on CPLHttpForbiddenException {
      // P0 pairing screens are not in this build. This 403 is the hook they
      // should replace with the pairing flow.
      state = const ListsState(isLoading: false, needsPairing: true);
    } catch (e) {
      state = ListsState(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> refresh() => _fetchLists();

  Future<void> createList(String type, String name) async {
    try {
      final list = await _repo.createList(type, name);
      state = state.copyWith(lists: [list, ...state.lists]);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<void> addItem(
    String listId,
    String content,
    Map<String, dynamic>? metadata,
  ) async {
    try {
      final item = await _repo.addItem(listId, content, metadata);
      state = state.copyWith(
        lists: state.lists.map((l) {
          if (l.id != listId) return l;
          return l.copyWith(items: [...l.items, item]);
        }).toList(),
      );
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<void> toggleItem(String listId, String itemId) async {
    try {
      final updated = await _repo.toggleItem(itemId);
      state = state.copyWith(
        lists: state.lists.map((l) {
          if (l.id != listId) return l;
          return l.copyWith(
            items: l.items
                .map((i) => i.id == itemId ? updated : i)
                .toList(),
          );
        }).toList(),
      );
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<void> deleteItem(String listId, String itemId) async {
    try {
      await _repo.deleteItem(itemId);
      state = state.copyWith(
        lists: state.lists.map((l) {
          if (l.id != listId) return l;
          return l.copyWith(
            items: l.items.where((i) => i.id != itemId).toList(),
          );
        }).toList(),
      );
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<void> deleteList(String listId) async {
    try {
      await _repo.deleteList(listId);
      state = state.copyWith(
        lists: state.lists.where((l) => l.id != listId).toList(),
      );
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }
}
