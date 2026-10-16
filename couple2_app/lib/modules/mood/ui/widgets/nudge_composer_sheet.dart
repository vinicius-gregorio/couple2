import 'package:couple2_app/core/core.dart';
import 'package:couple2_app/design_system/design_system.dart';
import 'package:flutter/material.dart';

import '../../domain/domain.dart';

/// The sheet stays open until [onSend] succeeds, so a failure keeps the
/// phrase and the selected chip.
Future<void> showNudgeComposerSheet(
  BuildContext context, {
  required Future<void> Function(NudgeDraft draft) onSend,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    builder: (_) => NudgeComposerSheet(onSend: onSend),
  );
}

class NudgeDraft {
  const NudgeDraft({required this.kind, this.message});

  final NudgeKind kind;
  final String? message;
}

class NudgeComposerSheet extends StatefulWidget {
  const NudgeComposerSheet({super.key, required this.onSend});

  final Future<void> Function(NudgeDraft draft) onSend;

  @override
  State<NudgeComposerSheet> createState() => _NudgeComposerSheetState();
}

class _NudgeComposerSheetState extends State<NudgeComposerSheet> {
  NudgeKind _kind = NudgeKind.thinkingOfYou;
  final _message = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return MutationScope(
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + bottom),
        child: Builder(
          builder: (context) {
            final locked = MutationScope.busyOf(context);
            return Column(
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
                        onSelected: locked
                            ? null
                            : (_) => setState(() => _kind = kind),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _message,
                  enabled: !locked,
                  maxLength: 80,
                  decoration: const InputDecoration(
                    labelText: 'Uma frase, se quiser',
                  ),
                ),
                MutationErrorBanner(message: _error),
                const SizedBox(height: 8),
                LoadingButton(
                  onPressed: () async {
                    final text = _message.text.trim();
                    try {
                      await widget.onSend(
                        NudgeDraft(
                          kind: _kind,
                          message: text.isEmpty ? null : text,
                        ),
                      );
                      if (context.mounted) Navigator.of(context).pop();
                    } catch (error) {
                      if (!mounted) return;
                      setState(() => _error = userFacingError(error));
                    }
                  },
                  child: const Text('Enviar'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
