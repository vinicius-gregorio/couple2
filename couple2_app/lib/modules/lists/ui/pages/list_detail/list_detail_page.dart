import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/domain.dart';
import '../../../../../../design_system/design_system.dart';
import '../lists/lists_viewmodel.dart';

class ListDetailPage extends ConsumerStatefulWidget {
  const ListDetailPage({super.key, required this.listId});
  final String listId;

  @override
  ConsumerState<ListDetailPage> createState() => _ListDetailPageState();
}

class _ListDetailPageState extends ConsumerState<ListDetailPage> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  PartnerList? _getList(ListsState state) {
    try {
      return state.lists.firstWhere((l) => l.id == widget.listId);
    } catch (_) {
      return null;
    }
  }

  void _addItem(String listId) {
    final content = _controller.text.trim();
    if (content.isEmpty) return;
    ref.read(listsViewModelProvider.notifier).addItem(listId, content, null);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(listsViewModelProvider);
    final list = _getList(state);

    if (list == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: AppText('List not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: AppText(list.name)),
      body: Column(
        children: [
          Expanded(
            child: list.items.isEmpty
                ? const Center(child: AppText('No items yet.'))
                : ListView.builder(
                    itemCount: list.items.length,
                    itemBuilder: (context, index) {
                      final item = list.items[index];
                      return _ItemTile(
                        item: item,
                        listId: list.id,
                        listType: list.type,
                      );
                    },
                  ),
          ),
          _AddItemBar(
            controller: _controller,
            onAdd: () => _addItem(list.id),
          ),
        ],
      ),
    );
  }
}

class _ItemTile extends ConsumerWidget {
  const _ItemTile({
    required this.item,
    required this.listId,
    required this.listType,
  });

  final ListItem item;
  final String listId;
  final String listType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.read(listsViewModelProvider.notifier);

    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => vm.deleteItem(listId, item.id),
      child: ListTile(
        leading: Checkbox(
          value: item.isCompleted,
          onChanged: (_) => vm.toggleItem(listId, item.id),
        ),
        title: Text(
          item.content,
          style: item.isCompleted
              ? const TextStyle(decoration: TextDecoration.lineThrough)
              : null,
        ),
        subtitle: _buildSubtitle(item, listType),
      ),
    );
  }

  Widget? _buildSubtitle(ListItem item, String type) {
    final meta = item.metadata;
    if (meta == null) return null;

    switch (type) {
      case 'SHOPPING_CART':
        final qty = meta['quantity'];
        if (qty != null) return Text('Qty: $qty');
      case 'MOVIES':
        final platform = meta['platform'];
        if (platform != null) return Chip(label: Text(platform.toString()));
      case 'MILESTONES':
        final date = meta['date'];
        if (date != null) return Text(date.toString());
      case 'TRAVEL':
        final country = meta['country'];
        final planned = meta['plannedDate'];
        if (country != null || planned != null) {
          return Text([
            if (country != null) country.toString(),
            if (planned != null) planned.toString(),
          ].join(' · '));
        }
    }
    return null;
  }
}

class _AddItemBar extends StatelessWidget {
  const _AddItemBar({required this.controller, required this.onAdd});
  final TextEditingController controller;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          12,
          8,
          12,
          MediaQuery.of(context).viewInsets.bottom + 8,
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: 'Add item...',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onSubmitted: (_) => onAdd(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
      ),
    );
  }
}
