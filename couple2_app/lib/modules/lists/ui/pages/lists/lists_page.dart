import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/domain.dart';
import '../../../../../../design_system/design_system.dart';
import '../../../routing/routes.dart';
import 'lists_viewmodel.dart';

const _listTypes = ['SHOPPING_CART', 'MOVIES', 'MILESTONES', 'TRAVEL'];

const _typeLabels = {
  'SHOPPING_CART': 'Shopping Cart',
  'MOVIES': 'Movies',
  'MILESTONES': 'Milestones',
  'TRAVEL': 'Travel',
};

const _typeIcons = {
  'SHOPPING_CART': Icons.shopping_cart,
  'MOVIES': Icons.movie,
  'MILESTONES': Icons.flag,
  'TRAVEL': Icons.flight,
};

class ListsPage extends ConsumerWidget {
  const ListsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(listsViewModelProvider);

    return Scaffold(
      appBar: AppBar(title: const AppText('Our Lists')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateListSheet(context, ref),
        child: const Icon(Icons.add),
      ),
      body: _buildBody(context, state),
    );
  }

  Widget _buildBody(BuildContext context, ListsState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.needsPairing) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: AppText(
            'Você precisa estar pareado para ver as listas. O fluxo de pareamento (P0) ainda não está neste app.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (state.errorMessage != null) {
      return Center(child: AppText('Error: ${state.errorMessage}'));
    }

    if (state.lists.isEmpty) {
      return const Center(child: AppText('No lists yet. Create one!'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: state.lists.length,
      itemBuilder: (context, index) {
        final list = state.lists[index];
        return _ListCard(list: list);
      },
    );
  }

  void _showCreateListSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _CreateListSheet(
        onConfirm: (type, name) {
          ref.read(listsViewModelProvider.notifier).createList(type, name);
        },
      ),
    );
  }
}

class _ListCard extends ConsumerWidget {
  const _ListCard({required this.list});
  final PartnerList list;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final icon = _typeIcons[list.type] ?? Icons.list;
    final label = _typeLabels[list.type] ?? list.type;
    final done = list.items.where((i) => i.isCompleted).length;
    final total = list.items.length;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon),
        title: AppText(list.name),
        subtitle: AppText('$label · $done/$total done'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => ref
                  .read(listsViewModelProvider.notifier)
                  .deleteList(list.id),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: () => context.push(
          ListsRoutes.listDetail.replaceFirst(':id', list.id),
        ),
      ),
    );
  }
}

class _CreateListSheet extends StatefulWidget {
  const _CreateListSheet({required this.onConfirm});
  final void Function(String type, String name) onConfirm;

  @override
  State<_CreateListSheet> createState() => _CreateListSheetState();
}

class _CreateListSheetState extends State<_CreateListSheet> {
  String _selectedType = _listTypes.first;
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppText('New List', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _selectedType,
            items: _listTypes
                .map((t) => DropdownMenuItem(
                      value: t,
                      child: Text(_typeLabels[t] ?? t),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _selectedType = v!),
            decoration: const InputDecoration(labelText: 'Type'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Name'),
            autofocus: true,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              final name = _nameController.text.trim();
              if (name.isEmpty) return;
              widget.onConfirm(_selectedType, name);
              Navigator.of(context).pop();
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}
