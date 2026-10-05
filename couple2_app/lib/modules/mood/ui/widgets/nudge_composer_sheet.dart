import 'package:couple2_app/design_system/design_system.dart';
import 'package:flutter/material.dart';

import '../../domain/domain.dart';

Future<NudgeDraft?> showNudgeComposerSheet(BuildContext context) {
  return showModalBottomSheet<NudgeDraft>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const NudgeComposerSheet(),
  );
}

class NudgeDraft {
  const NudgeDraft({required this.kind, this.message});

  final NudgeKind kind;
  final String? message;
}

class NudgeComposerSheet extends StatefulWidget {
  const NudgeComposerSheet({super.key});

  @override
  State<NudgeComposerSheet> createState() => _NudgeComposerSheetState();
}

class _NudgeComposerSheetState extends State<NudgeComposerSheet> {
  NudgeKind _kind = NudgeKind.thinkingOfYou;
  final _message = TextEditingController();

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppText(
            'Um carinho',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final kind in NudgeKind.values)
                ChoiceChip(
                  label: Text('${kind.emoji} ${kind.label}'),
                  selected: kind == _kind,
                  onSelected: (_) => setState(() => _kind = kind),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _message,
            maxLength: 80,
            decoration: const InputDecoration(
              labelText: 'Uma frase, se quiser',
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () {
              final text = _message.text.trim();
              Navigator.of(context).pop(
                NudgeDraft(kind: _kind, message: text.isEmpty ? null : text),
              );
            },
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
  }
}
