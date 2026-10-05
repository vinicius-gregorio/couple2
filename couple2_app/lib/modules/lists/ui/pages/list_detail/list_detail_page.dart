import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

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

  void _addItem(PartnerList list) {
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

    ref
        .read(listsViewModelProvider.notifier)
        .addItem(list.id, content, metadata);
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
          if (list.visibility == 'PRIVATE_FROM_PARTNER')
            const ListTile(dense: true, title: Text('🔒 Só você vê')),
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
            listType: list.type,
            controller: _controller,
            priceController: _priceController,
            urlController: _urlController,
            occasion: _occasion,
            bought: _bought,
            onOccasion: (value) => setState(() => _occasion = value),
            onBought: (value) => setState(() => _bought = value),
            onAdd: () => _addItem(list),
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
        trailing: listTypeSupportsDatePlan(listType)
            ? TextButton(
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
              )
            : null,
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

class _AddItemBar extends StatelessWidget {
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
  });

  final String listType;
  final TextEditingController controller;
  final TextEditingController priceController;
  final TextEditingController urlController;
  final String? occasion;
  final bool bought;
  final ValueChanged<String?> onOccasion;
  final ValueChanged<bool> onBought;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final isGift = listType == 'GIFT_IDEAS';
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
                controller: priceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  hintText: 'Preço (opcional)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: urlController,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  hintText: 'Link (opcional)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String?>(
                key: ValueKey(occasion),
                initialValue: occasion,
                decoration: const InputDecoration(
                  labelText: 'Ocasião (opcional)',
                  border: OutlineInputBorder(),
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
                onChanged: onOccasion,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Já comprei'),
                value: bought,
                onChanged: onBought,
              ),
            ],
            Row(
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
          ],
        ),
      ),
    );
  }
}
