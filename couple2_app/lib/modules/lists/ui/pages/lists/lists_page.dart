import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../app/session_provider.dart';
import '../../../../../design_system/design_system.dart';
import '../../../domain/domain.dart';
import '../../../routing/routes.dart';
import 'lists_viewmodel.dart';

const _listTypes = [
  'SHOPPING_CART',
  'MOVIES',
  'MILESTONES',
  'TRAVEL',
  'GIFT_IDEAS',
];

const _typeLabels = {
  'SHOPPING_CART': 'Shopping Cart',
  'MOVIES': 'Movies',
  'MILESTONES': 'Milestones',
  'TRAVEL': 'Travel',
  'GIFT_IDEAS': 'Ideias de presente 🎁',
};

const _typeIcons = {
  'SHOPPING_CART': Icons.shopping_cart,
  'MOVIES': Icons.movie,
  'MILESTONES': Icons.flag,
  'TRAVEL': Icons.flight,
  'GIFT_IDEAS': Icons.card_giftcard,
};

class ListsPage extends ConsumerStatefulWidget {
  const ListsPage({super.key});

  @override
  ConsumerState<ListsPage> createState() => _ListsPageState();
}

class _ListsPageState extends ConsumerState<ListsPage>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future<void>.microtask(_refresh);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  void _refresh() {
    if (!mounted) return;
    ref.read(listsViewModelProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(listsViewModelProvider);
    final partnerName = ref.watch(sessionProvider).asData?.value?.partnerName;

    return Scaffold(
      appBar: AppBar(title: const AppText('Our Lists')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateListSheet(context, ref, partnerName),
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

    final privateLists = state.lists
        .where((list) => list.visibility == 'PRIVATE_FROM_PARTNER')
        .toList();
    final sharedLists = state.lists
        .where((list) => list.visibility != 'PRIVATE_FROM_PARTNER')
        .toList();

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (final list in sharedLists) _ListCard(list: list),
        if (privateLists.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 12, 4, 8),
            child: AppText(
              'Minhas listas privadas',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          for (final list in privateLists) _ListCard(list: list),
        ],
      ],
    );
  }

  void _showCreateListSheet(
    BuildContext context,
    WidgetRef ref,
    String? partnerName,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _CreateListSheet(
        partnerName: partnerName,
        onConfirm: (type, name, visibility) {
          ref
              .read(listsViewModelProvider.notifier)
              .createList(type, name, visibility: visibility);
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
    final isPrivate = list.visibility == 'PRIVATE_FROM_PARTNER';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon),
        title: AppText(list.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText('$label · $done/$total done'),
            if (isPrivate) const AppText('🔒 Só você vê'),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () =>
                  ref.read(listsViewModelProvider.notifier).deleteList(list.id),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: () async {
          await context.push(
            ListsRoutes.listDetail.replaceFirst(':id', list.id),
          );
          if (!context.mounted) return;
          await ref.read(listsViewModelProvider.notifier).refresh();
        },
      ),
    );
  }
}

class _CreateListSheet extends StatefulWidget {
  const _CreateListSheet({required this.onConfirm, required this.partnerName});

  final void Function(String type, String name, String? visibility) onConfirm;
  final String? partnerName;

  @override
  State<_CreateListSheet> createState() => _CreateListSheetState();
}

class _CreateListSheetState extends State<_CreateListSheet> {
  String _selectedType = _listTypes.first;
  bool _hideFromPartner = true;
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String get _partnerLabel {
    final name = widget.partnerName?.trim();
    if (name == null || name.isEmpty) return 'parceiro';
    return name;
  }

  @override
  Widget build(BuildContext context) {
    final isGift = _selectedType == 'GIFT_IDEAS';
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
          const AppText(
            'New List',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _selectedType,
            items: _listTypes
                .map(
                  (t) => DropdownMenuItem(
                    value: t,
                    child: Text(_typeLabels[t] ?? t),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() {
              _selectedType = v!;
              if (_selectedType == 'GIFT_IDEAS') _hideFromPartner = true;
            }),
            decoration: const InputDecoration(labelText: 'Type'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Name'),
            autofocus: true,
          ),
          if (isGift) ...[
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Esconder de $_partnerLabel'),
              subtitle: Text(
                '$_partnerLabel não verá esta lista nem receberá notificações',
              ),
              value: _hideFromPartner,
              onChanged: (value) => setState(() => _hideFromPartner = value),
            ),
          ],
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              final name = _nameController.text.trim();
              if (name.isEmpty) return;
              final visibility = isGift
                  ? (_hideFromPartner ? 'PRIVATE_FROM_PARTNER' : 'SHARED')
                  : null;
              widget.onConfirm(_selectedType, name, visibility);
              Navigator.of(context).pop();
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}
