import 'package:couple2_app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../app/routing/app_back_button.dart';
import '../../../data/notifications_providers.dart';
import '../../../domain/domain.dart';

class NotificationPreferencesPage extends ConsumerStatefulWidget {
  const NotificationPreferencesPage({super.key});

  @override
  ConsumerState<NotificationPreferencesPage> createState() =>
      _NotificationPreferencesPageState();
}

class _NotificationPreferencesPageState
    extends ConsumerState<NotificationPreferencesPage> {
  NotificationPreferences? _prefs;
  String? _error;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final prefs = await ref
          .read(notificationsRepositoryProvider)
          .getPreferences();
      if (!mounted) return;
      setState(() {
        _prefs = prefs;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Não foi possível carregar as notificações.';
        _loading = false;
      });
    }
  }

  Future<void> _patch(Map<String, dynamic> patch) async {
    if (_saving) return;
    final previous = _prefs;
    setState(() => _saving = true);
    try {
      final next = await ref
          .read(notificationsRepositoryProvider)
          .updatePreferences(patch);
      if (!mounted) return;
      setState(() => _prefs = next);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _prefs = previous;
        _error = 'Não foi possível salvar as notificações.';
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickQuiet({required bool start}) async {
    final current = _prefs;
    if (current == null) return;
    final initialMinutes = start ? current.quietStartMin : current.quietEndMin;
    final picked = await showTimePicker(
      context: context,
      initialTime: _timeOf(initialMinutes ?? (start ? 23 * 60 : 7 * 60)),
    );
    if (picked == null) return;
    final minutes = quietMinutes(picked.hour, picked.minute);
    final startMin = start ? minutes : (current.quietStartMin ?? 23 * 60);
    final endMin = start ? (current.quietEndMin ?? 7 * 60) : minutes;
    await _patch({'quietStartMin': startMin, 'quietEndMin': endMin});
  }

  @override
  Widget build(BuildContext context) {
    final prefs = _prefs;
    return Scaffold(
      appBar: AppBar(leading: AppBackButton(), title: AppText('Notificações')),
      body: _loading && prefs == null
          ? const FormSkeleton()
          : prefs == null
          ? ErrorView(
              message: _error ?? 'Não foi possível carregar',
              onRetry: _load,
            )
          : ListView(
              children: [
                if (_saving)
                  const LinearProgressIndicator(key: LoadingButton.spinnerKey),
                MutationErrorBanner(message: _error),
                SwitchListTile(
                  title: const Text('Alertas'),
                  value: prefs.pushEnabled,
                  onChanged: _saving
                      ? null
                      : (value) => _patch({'pushEnabled': value}),
                ),
                SwitchListTile(
                  title: const Text('Listas'),
                  value: prefs.lists,
                  onChanged: _saving
                      ? null
                      : (value) => _patch({'lists': value}),
                ),
                SwitchListTile(
                  title: const Text('Datas importantes'),
                  value: prefs.importantDates,
                  onChanged: _saving
                      ? null
                      : (value) => _patch({'importantDates': value}),
                ),
                SwitchListTile(
                  title: const Text('Pergunta do dia'),
                  value: prefs.dailyQuestion,
                  onChanged: _saving
                      ? null
                      : (value) => _patch({'dailyQuestion': value}),
                ),
                SwitchListTile(
                  title: const Text('Humor'),
                  value: prefs.mood,
                  onChanged: _saving
                      ? null
                      : (value) => _patch({'mood': value}),
                ),
                SwitchListTile(
                  title: const Text('Carinhos'),
                  value: prefs.nudges,
                  onChanged: _saving
                      ? null
                      : (value) => _patch({'nudges': value}),
                ),
                SwitchListTile(
                  title: const Text('Planos de date'),
                  value: prefs.datePlans,
                  onChanged: _saving
                      ? null
                      : (value) => _patch({'datePlans': value}),
                ),
                const Divider(),
                ListTile(
                  title: const Text('Silêncio começa'),
                  subtitle: Text(
                    prefs.quietStartMin == null
                        ? 'Desligado'
                        : formatQuietMinutes(prefs.quietStartMin!),
                  ),
                  onTap: _saving ? null : () => _pickQuiet(start: true),
                ),
                ListTile(
                  title: const Text('Silêncio termina'),
                  subtitle: Text(
                    prefs.quietEndMin == null
                        ? 'Desligado'
                        : formatQuietMinutes(prefs.quietEndMin!),
                  ),
                  onTap: _saving ? null : () => _pickQuiet(start: false),
                ),
                if (prefs.quietStartMin != null || prefs.quietEndMin != null)
                  LoadingButton(
                    variant: LoadingButtonVariant.text,
                    loading: _saving,
                    onPressed: _saving
                        ? null
                        : () => _patch({
                            'quietStartMin': null,
                            'quietEndMin': null,
                          }),
                    child: const Text('Limpar horário de silêncio'),
                  ),
              ],
            ),
    );
  }
}

TimeOfDay _timeOf(int minutes) {
  return TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
}
