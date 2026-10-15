import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../app/routing/app_back_button.dart';
import '../../../../../app/session_provider.dart';
import '../../../../../design_system/design_system.dart';
import '../../../../pairing/routing/routes.dart';
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
  'SHOPPING_CART': 'Carrinho',
  'MOVIES': 'Filmes',
  'MILESTONES': 'Marcos',
  'TRAVEL': 'Viagem',
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
      appBar: AppBar(leading: AppBackButton(), title: AppText('Nossas listas')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateListSheet(context, ref, partnerName),
        child: const Icon(Icons.add),
      ),
      body: _buildBody(context, state),
    );
  }

  Widget _buildBody(BuildContext context, ListsState state) {
    if (state.needsPairing) {
      return EmptyView(
        message: 'Você precisa estar pareado para ver as listas.',
        action: LoadingButton(
          onPressed: () async {
            await ref.read(sessionProvider.notifier).refresh();
            if (!context.mounted) return;
            context.go(PairingRoutes.hub);
          },
          child: const Text('Ir para o pareamento'),
        ),
      );
    }

    return Column(
      children: [
        MutationErrorBanner(message: state.actionError),
        Expanded(
          child: AsyncBody(
            isLoading: state.isLoading,
            hasData: state.lists.isNotEmpty,
            error: state.errorMessage,
            errorMessage: 'Não foi possível carregar as listas.',
            onRetry: _refresh,
            isEmpty: state.lists.isEmpty,
            emptyMessage: 'Nenhuma lista ainda. Crie uma!',
            child: _ListsBody(state: state),
          ),
        ),
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
          return ref
              .read(listsViewModelProvider.notifier)
              .createList(type, name, visibility: visibility);
        },
      ),
    );
  }
}

class _ListsBody extends StatelessWidget {
  const _ListsBody({required this.state});

  final ListsState state;

  @override
  Widget build(BuildContext context) {
    final privateLists = state.lists
        .where((list) => list.visibility == 'PRIVATE_FROM_PARTNER')
        .toList();
    final sharedLists = state.lists
        .where((list) => list.visibility != 'PRIVATE_FROM_PARTNER')
        .toList();
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (final list in sharedLists) _ListCard(list: list),
        if (privateLists.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
            child: AppText(
              'Minhas listas privadas',
              style: theme.textTheme.titleMedium,
            ),
          ),
          for (final list in privateLists) _ListCard(list: list),
        ],
      ],
    );
  }
}

Future<void> _confirmDeleteList(
  BuildContext context,
  WidgetRef ref,
  PartnerList list,
) async {
  final accepted = await confirmDestructive(
    context,
    title: 'Excluir lista?',
    message:
        '“${list.name}” e os itens somem para os dois. Não há como desfazer.',
    confirmLabel: 'Excluir',
    confirmKey: const Key('confirm-delete-list'),
  );
  if (!accepted || !context.mounted) return;
  await ref.read(listsViewModelProvider.notifier).deleteList(list.id);
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
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: IgnorePointer(child: AppText(list.name)),
        subtitle: IgnorePointer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText('$label · $done/$total feitos'),
              if (isPrivate) const AppText('🔒 Só você vê'),
            ],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AbsorbPointer(
              absorbing: ref.watch(listsViewModelProvider).deletingListIds.contains(
                list.id,
              ),
              child: LoadingIconButton(
                tooltip: 'Excluir lista',
                loading: ref
                    .watch(listsViewModelProvider)
                    .deletingListIds
                    .contains(list.id),
                icon: const Icon(Icons.delete_outline),
                onPressed:
                    ref.watch(listsViewModelProvider).deletingListIds.contains(
                      list.id,
                    )
                    ? null
                    : () => _confirmDeleteList(context, ref, list),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Theme.of(context).colorScheme.primary,
            ),
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

  final Future<String?> Function(String type, String name, String? visibility)
  onConfirm;
  final String? partnerName;

  @override
  State<_CreateListSheet> createState() => _CreateListSheetState();
}

class _CreateListSheetState extends State<_CreateListSheet> {
  String _selectedType = _listTypes.first;
  bool _hideFromPartner = true;
  String? _error;
  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_onNameChanged);
  }

  void _onNameChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _nameController.removeListener(_onNameChanged);
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
          AppText('Nova lista', style: Theme.of(context).textTheme.titleLarge),
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
            decoration: const InputDecoration(labelText: 'Tipo'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Nome'),
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
          MutationErrorBanner(message: _error),
          LoadingButton(
            onPressed: _nameController.text.trim().isEmpty
                ? null
                : () async {
                    final name = _nameController.text.trim();
                    final visibility = isGift
                        ? (_hideFromPartner ? 'PRIVATE_FROM_PARTNER' : 'SHARED')
                        : null;
                    final message = await widget.onConfirm(
                      _selectedType,
                      name,
                      visibility,
                    );
                    if (!context.mounted) return;
                    if (message == null) {
                      Navigator.of(context).pop();
                      return;
                    }
                    setState(() => _error = message);
                  },
            child: const Text('Criar'),
          ),
        ],
      ),
    );
  }
}
