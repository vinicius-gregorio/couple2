import 'package:couple2_app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/core.dart';
import '../../../feed/data/feed_providers.dart';
import '../../data/mood_providers.dart';
import '../../domain/domain.dart';

Future<void> showMoodPickerSheet(BuildContext context) async {
  await showAppSheet<void>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    builder: (_) => const MoodPickerSheet(),
  );
}

class MoodPickerSheet extends ConsumerStatefulWidget {
  const MoodPickerSheet({super.key});

  @override
  ConsumerState<MoodPickerSheet> createState() => _MoodPickerSheetState();
}

class _MoodPickerSheetState extends ConsumerState<MoodPickerSheet> {
  MoodLevel _mood = MoodLevel.good;
  final _note = TextEditingController();
  bool _saving = false;
  var _pointers = 0;
  String? _error;
  final _pop = PopGuard();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || _pop.used) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(moodRepositoryProvider)
          .create(mood: _mood, note: _note.text);
      ref.invalidate(currentMoodProvider);
      ref.invalidate(feedPreviewProvider);
      if (!mounted) return;
      // Stay up through a double tap so the second click does not hit Home.
      await Future<void>.delayed(const Duration(milliseconds: 320));
      if (!mounted || _pop.used) return;
      var spins = 0;
      while (_pointers > 0 && spins < 40 && mounted) {
        spins++;
        await Future<void>.delayed(const Duration(milliseconds: 16));
      }
      if (!mounted || _pop.used) return;
      await MutationScope.refreshOf(context);
      if (!mounted || _pop.used) return;
      _pop.pop(context);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = userFacingError(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return PopScope(
      canPop: !_saving,
      child: Listener(
        onPointerDown: (_) => _pointers++,
        onPointerUp: (_) => _pointers = (_pointers - 1).clamp(0, 99),
        onPointerCancel: (_) => _pointers = (_pointers - 1).clamp(0, 99),
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppText(
                'Como você está?',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const AppText(
                'Vale o que você sentir agora. Pode mudar quando quiser.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              IgnorePointer(
                ignoring: _saving,
                child: Opacity(
                  opacity: _saving ? 0.38 : 1,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (final level in MoodLevel.values)
                        _EmojiChoice(
                          level: level,
                          selected: level == _mood,
                          onTap: () => setState(() => _mood = level),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _note,
                enabled: !_saving,
                maxLength: 140,
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Uma nota, se quiser',
                  hintText: 'Opcional',
                ),
              ),
              ActionErrorReporter(message: _error),
              const SizedBox(height: 12),
              LoadingButton(
                variant: LoadingButtonVariant.filled,
                loading: _saving,
                onPressed: _saving || _pop.used ? null : _save,
                child: const Text('Compartilhar'),
              ),
              LoadingButton(
                variant: LoadingButtonVariant.text,
                onPressed: _saving || _pop.used
                    ? null
                    : () => Navigator.of(context).pop(),
                child: const Text('Fechar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmojiChoice extends StatelessWidget {
  const _EmojiChoice({
    required this.level,
    required this.selected,
    required this.onTap,
  });

  final MoodLevel level;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      enabled: onTap != null,
      label: level.label,
      onTap: onTap,
      child: ExcludeSemantics(
        child: AppInkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: selected ? color.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? color.primary : color.outline,
              ),
            ),
            child: Text(level.emoji, style: const TextStyle(fontSize: 36)),
          ),
        ),
      ),
    );
  }
}
