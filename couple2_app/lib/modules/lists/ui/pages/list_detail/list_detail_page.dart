import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../app/routing/app_back_button.dart';
import '../../../../../design_system/design_system.dart';
import '../../../../date_plans/domain/date_plan_copy.dart';
import '../../../../date_plans/routing/routes.dart';
import '../../../domain/domain.dart';
import '../lists/lists_viewmodel.dart';

class ListDetailPage extends ConsumerStatefulWidget {
  const ListDetailPage({super.key, required this.listId});
  final String listId;

  @override
  ConsumerState<ListDetailPage> createState() => _ListDetailPageState();
}

class _ListDetailPageState extends ConsumerState<ListDetailPage> {
  final _controller = TextEditingController();
  final _priceController = TextEditingController();
  final _urlController = TextEditingController();
  String? _occasion;
  bool _bought = false;

  @override
  void dispose() {
    _controller.dispose();
    _priceController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  PartnerList? _getList(ListsState state) {
    try {
      return state.lists.firstWhere((l) => l.id == widget.listId);
    } catch (_) {
      return null;
    }
  }

  Future<void> _addItem(PartnerList list) async {
    final content = _controller.text.trim();
    if (content.isEmpty) return;

    Map<String, dynamic>? metadata;
    if (list.type == 'GIFT_IDEAS') {
      final draft = buildGiftItemMetadata(
        priceText: _priceController.text,
        urlText: _urlController.text,
        occasion: _occasion,
        bought: _bought,
      );
      if (!draft.isValid) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(draft.error!)));
        return;
      }
      metadata = draft.metadata;
    }

    final saved = await ref
        .read(listsViewModelProvider.notifier)
        .addItem(list.id, content, metadata);
    if (!saved || !mounted) return;
    _controller.clear();
    _priceController.clear();
    _urlController.clear();
    setState(() {
      _occasion = null;
      _bought = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(listsViewModelProvider);
    final list = _getList(state);

    if (list == null && state.isLoading) {
      return Scaffold(
        appBar: AppBar(leading: AppBackButton(), title: AppText('Lista')),
        body: const ListSkeleton(),
      );
    }

    if (list == null && state.errorMessage != null) {
      return Scaffold(
        appBar: AppBar(leading: AppBackButton()),
        body: ErrorView(
          message: 'Não foi possível carregar a lista.',
          onRetry: () => ref.read(listsViewModelProvider.notifier).refresh(),
        ),
      );
    }

    if (list == null) {
      return Scaffold(
        appBar: AppBar(leading: AppBackButton()),
        body: const EmptyView(message: 'Lista não encontrada'),
      );
    }

    return Scaffold(
      appBar: AppBar(leading: const AppBackButton(), title: AppText(list.name)),
      body: Column(
        children: [
          MutationErrorBanner(message: state.actionError),
          if (list.visibility == 'PRIVATE_FROM_PARTNER')
            const ListTile(dense: true, title: Text('🔒 Só você vê')),
          Expanded(
            child: list.items.isEmpty
                ? const EmptyView(message: 'Nenhum item ainda.')
                : ListView.builder(
                    itemCount: list.items.length,
                    itemBuilder: (context, index) {
                      final item = list.items[index];
                      return _ItemTile(
                        item: item,
                        listId: list.id,
                        listType: list.type,
                        privateList: list.visibility == 'PRIVATE_FROM_PARTNER',
                      );
                    },
                  ),
          ),
          _AddItemBar(
            listType: list.type,
            controller: _controller,
            priceController: _priceController,
            urlController: _urlController,
            occasion: _occasion,
            bought: _bought,
            onOccasion: (value) => setState(() => _occasion = value),
            onBought: (value) => setState(() => _bought = value),
            busy: state.addingListIds.contains(list.id),
            onAdd: () => _addItem(list),
          ),
        ],
      ),
    );
  }
}

Future<void> _confirmDeleteItem(
  BuildContext context,
  WidgetRef ref,
  String listId,
  ListItem item, {
  required bool privateList,
}) async {
  final accepted = await confirmDestructive(
    context,
    title: 'Excluir item?',
    message: privateList
        ? '“${item.content}” é só seu. Seu par não vê este item. Não há como desfazer.'
        : '“${item.content}” será apagado para os dois.',
    confirmLabel: 'Excluir',
    confirmKey: Key('confirm-delete-${item.id}'),
  );
  if (!accepted || !context.mounted) return;
  await ref.read(listsViewModelProvider.notifier).deleteItem(listId, item.id);
}

class _ItemTile extends ConsumerWidget {
  const _ItemTile({
    required this.item,
    required this.listId,
    required this.listType,
    required this.privateList,
  });

  final ListItem item;
  final String listId;
  final String listType;
  final bool privateList;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.read(listsViewModelProvider.notifier);

    return ListTile(
      key: Key('list-item-${item.id}'),
      leading: item.pending
          ? const SizedBox(
              key: Key('item-pending'),
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Checkbox(
              value: item.isCompleted,
              onChanged: (_) => vm.toggleItem(listId, item.id),
            ),
      title: Text(
        item.content,
        style: item.isCompleted
            ? const TextStyle(decoration: TextDecoration.lineThrough)
            : null,
      ),
      subtitle: item.pending
          ? const Text('Salvando…')
          : _buildSubtitle(item, listType),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (listTypeSupportsDatePlan(listType) && !item.pending)
            TextButton(
              onPressed: () {
                final query = Uri(
                  path: DatePlanRoutes.create,
                  queryParameters: {
                    'sourceListItemId': item.id,
                    'title': item.content,
                  },
                ).toString();
                context.push(query);
              },
              child: const Text('Planejar date'),
            ),
          LoadingIconButton(
            key: Key('delete-item-${item.id}'),
            tooltip: 'Excluir item',
            loading: item.pending,
            onPressed: item.pending
                ? null
                : () => _confirmDeleteItem(
                    context,
                    ref,
                    listId,
                    item,
                    privateList: privateList,
                  ),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }

  Widget? _buildSubtitle(ListItem item, String type) {
    final meta = item.metadata;
    if (type == 'GIFT_IDEAS') return _giftSubtitle(item);
    if (meta == null) return null;

    switch (type) {
      case 'SHOPPING_CART':
        final qty = meta['quantity'];
        if (qty != null) return Text('Qtd: $qty');
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
          return Text(
            [
              if (country != null) country.toString(),
              if (planned != null) planned.toString(),
            ].join(' · '),
          );
        }
    }
    return null;
  }

  Widget? _giftSubtitle(ListItem item) {
    final meta = item.metadata;
    final price = meta?['price'];
    final priceLabel = price is num ? formatGiftPrice(price) : null;
    final occasion = giftOccasionLabel(meta?['occasion']);
    final bought = meta?['status'] == 'BOUGHT';
    final url = meta?['url'];
    final link = isHttpGiftUrl(url) ? url as String : null;
    if (priceLabel == null && occasion == null && !bought && link == null) {
      return null;
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      children: [
        if (priceLabel != null) Text(priceLabel),
        if (occasion != null)
          Chip(
            label: Text(occasion),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        if (bought) const Text('comprado'),
        if (link != null)
          IconButton(
            tooltip: 'Abrir link',
            visualDensity: VisualDensity.compact,
            onPressed: () => launchUrl(
              Uri.parse(link),
              mode: LaunchMode.externalApplication,
            ),
            icon: const Icon(Icons.link),
          ),
      ],
    );
  }
}

class _AddItemBar extends StatefulWidget {
  const _AddItemBar({
    required this.listType,
    required this.controller,
    required this.priceController,
    required this.urlController,
    required this.occasion,
    required this.bought,
    required this.onOccasion,
    required this.onBought,
    required this.onAdd,
    required this.busy,
  });

  final String listType;
  final TextEditingController controller;
  final TextEditingController priceController;
  final TextEditingController urlController;
  final String? occasion;
  final bool bought;
  final ValueChanged<String?> onOccasion;
  final ValueChanged<bool> onBought;
  final Future<void> Function() onAdd;
  final bool busy;

  @override
  State<_AddItemBar> createState() => _AddItemBarState();
}

class _AddItemBarState extends State<_AddItemBar> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_rebuild);
    widget.priceController.addListener(_rebuild);
    widget.urlController.addListener(_rebuild);
  }

  @override
  void didUpdateWidget(covariant _AddItemBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_rebuild);
      widget.controller.addListener(_rebuild);
    }
    if (oldWidget.priceController != widget.priceController) {
      oldWidget.priceController.removeListener(_rebuild);
      widget.priceController.addListener(_rebuild);
    }
    if (oldWidget.urlController != widget.urlController) {
      oldWidget.urlController.removeListener(_rebuild);
      widget.urlController.addListener(_rebuild);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_rebuild);
    widget.priceController.removeListener(_rebuild);
    widget.urlController.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  bool get _canAdd {
    if (widget.controller.text.trim().isEmpty) return false;
    if (widget.listType != 'GIFT_IDEAS') return true;
    return buildGiftItemMetadata(
      priceText: widget.priceController.text,
      urlText: widget.urlController.text,
      occasion: widget.occasion,
      bought: widget.bought,
    ).isValid;
  }

  @override
  Widget build(BuildContext context) {
    final isGift = widget.listType == 'GIFT_IDEAS';
    final giftError = isGift && widget.controller.text.trim().isNotEmpty
        ? buildGiftItemMetadata(
            priceText: widget.priceController.text,
            urlText: widget.urlController.text,
            occasion: widget.occasion,
            bought: widget.bought,
          ).error
        : null;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          12,
          8,
          12,
          MediaQuery.of(context).viewInsets.bottom + 8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isGift) ...[
              TextField(
                controller: widget.priceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  hintText: 'Preço (opcional)',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: widget.urlController,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  hintText: 'Link (opcional)',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String?>(
                key: ValueKey(widget.occasion),
                initialValue: widget.occasion,
                decoration: const InputDecoration(
                  labelText: 'Ocasião (opcional)',
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Sem ocasião'),
                  ),
                  for (final entry in giftOccasions.entries)
                    DropdownMenuItem<String?>(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                ],
                onChanged: widget.onOccasion,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Já comprei'),
                value: widget.bought,
                onChanged: widget.onBought,
              ),
            ],
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    enabled: !widget.busy,
                    decoration: const InputDecoration(
                      hintText: 'Adicionar item…',
                      isDense: true,
                    ),
                    onSubmitted: (_) {
                      if (_canAdd && !widget.busy) widget.onAdd();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                LoadingIconButton(
                  key: const Key('add-item'),
                  tooltip: 'Adicionar',
                  loading: widget.busy,
                  onPressed: _canAdd && !widget.busy ? widget.onAdd : null,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            if (giftError != null) ...[
              const SizedBox(height: 8),
              AppText(
                giftError,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
