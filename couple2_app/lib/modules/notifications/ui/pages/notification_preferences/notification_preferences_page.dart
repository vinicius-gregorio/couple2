import 'package:couple2_app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      final prefs =
          await ref.read(notificationsRepositoryProvider).getPreferences();
      if (!mounted) return;
      setState(() {
        _prefs = prefs;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _patch(Map<String, dynamic> patch) async {
    final previous = _prefs;
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
        _error = error.toString();
      });
    }
  }

  Future<void> _pickQuiet({required bool start}) async {
    final current = _prefs;
    if (current == null) return;
    final initialMinutes =
        start ? current.quietStartMin : current.quietEndMin;
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
      appBar: AppBar(title: const AppText('Notificações')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : prefs == null
              ? Center(child: AppText(_error ?? 'Não foi possível carregar'))
              : ListView(
                  children: [
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: AppText(_error!),
                      ),
                    SwitchListTile(
                      title: const Text('Push'),
                      value: prefs.pushEnabled,
                      onChanged: (value) => _patch({'pushEnabled': value}),
                    ),
                    SwitchListTile(
                      title: const Text('Listas'),
                      value: prefs.lists,
                      onChanged: (value) => _patch({'lists': value}),
                    ),
                    SwitchListTile(
                      title: const Text('Datas importantes'),
                      value: prefs.importantDates,
                      onChanged: (value) => _patch({'importantDates': value}),
                    ),
                    SwitchListTile(
                      title: const Text('Pergunta do dia'),
                      value: prefs.dailyQuestion,
                      onChanged: (value) => _patch({'dailyQuestion': value}),
                    ),
                    SwitchListTile(
                      title: const Text('Humor'),
                      value: prefs.mood,
                      onChanged: (value) => _patch({'mood': value}),
                    ),
                    SwitchListTile(
                      title: const Text('Carinhos'),
                      value: prefs.nudges,
                      onChanged: (value) => _patch({'nudges': value}),
                    ),
                    SwitchListTile(
                      title: const Text('Planos de date'),
                      value: prefs.datePlans,
                      onChanged: (value) => _patch({'datePlans': value}),
                    ),
                    const Divider(),
                    ListTile(
                      title: const Text('Silêncio começa'),
                      subtitle: Text(
                        prefs.quietStartMin == null
                            ? 'Desligado'
                            : formatQuietMinutes(prefs.quietStartMin!),
                      ),
                      onTap: () => _pickQuiet(start: true),
                    ),
                    ListTile(
                      title: const Text('Silêncio termina'),
                      subtitle: Text(
                        prefs.quietEndMin == null
                            ? 'Desligado'
                            : formatQuietMinutes(prefs.quietEndMin!),
                      ),
                      onTap: () => _pickQuiet(start: false),
                    ),
                    if (prefs.quietStartMin != null || prefs.quietEndMin != null)
                      TextButton(
                        onPressed: () => _patch({
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
