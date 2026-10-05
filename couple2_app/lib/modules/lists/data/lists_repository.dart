import '../../../core/core.dart';
import '../domain/domain.dart';

abstract class IListsRepository {
  Future<List<PartnerList>> getLists();
  Future<PartnerList> createList(
    String type,
    String name, {
    String? visibility,
  });
  Future<ListItem> addItem(
    String listId,
    String content,
    Map<String, dynamic>? metadata,
  );
  Future<ListItem> toggleItem(String itemId);
  Future<void> deleteItem(String itemId);
  Future<void> deleteList(String listId);
}

class ListsRepository implements IListsRepository {
  ListsRepository({required ICPLHttpClient httpClient})
    : _httpClient = httpClient;

  final ICPLHttpClient _httpClient;

  @override
  Future<List<PartnerList>> getLists() async {
    final response = await _httpClient.get<List<dynamic>>('/lists');
    return (response.data as List<dynamic>)
        .map((e) => PartnerList.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<PartnerList> createList(
    String type,
    String name, {
    String? visibility,
  }) async {
    final response = await _httpClient.post<Map<String, dynamic>>(
      '/lists',
      data: {
        'type': type,
        'name': name,
        if (visibility != null) 'visibility': visibility,
      },
    );
    return PartnerList.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<ListItem> addItem(
    String listId,
    String content,
    Map<String, dynamic>? metadata,
  ) async {
    final response = await _httpClient.post<Map<String, dynamic>>(
      '/lists/$listId/items',
      data: {'content': content, if (metadata != null) 'metadata': metadata},
    );
    return ListItem.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<ListItem> toggleItem(String itemId) async {
    final response = await _httpClient.patch<Map<String, dynamic>>(
      '/lists/items/$itemId',
    );
    return ListItem.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<void> deleteItem(String itemId) async {
    await _httpClient.delete<void>('/lists/items/$itemId');
  }

  @override
  Future<void> deleteList(String listId) async {
    await _httpClient.delete<void>('/lists/$listId');
  }
}
