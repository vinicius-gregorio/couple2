import 'package:couple2_app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

import '../../../../../app/routing/pop_or_go.dart';
import '../../../../../app/routing/routes.dart';
import '../../../data/couple_providers.dart';
import '../../../domain/domain.dart';

const _commonTimezones = [
  'America/Sao_Paulo',
  'America/Manaus',
  'America/Belem',
  'America/Fortaleza',
  'America/Recife',
  'America/Noronha',
  'America/Rio_Branco',
  'America/New_York',
  'America/Chicago',
  'America/Denver',
  'America/Los_Angeles',
  'Europe/Lisbon',
  'Europe/London',
  'UTC',
];

class CoupleSettingsPage extends ConsumerStatefulWidget {
  const CoupleSettingsPage({super.key});

  @override
  ConsumerState<CoupleSettingsPage> createState() => _CoupleSettingsPageState();
}

class _CoupleSettingsPageState extends ConsumerState<CoupleSettingsPage> {
  DateTime? _anniversary;
  String _timezone = 'America/Sao_Paulo';
  bool _saving = false;
  String? _error;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _loadDeviceTimezone();
  }

  Future<void> _loadDeviceTimezone() async {
    try {
      final local = await FlutterTimezone.getLocalTimezone();
      if (!mounted) return;
      final couple = ref.read(coupleProvider).asData?.value;
      if (couple?.anniversaryDate == null) {
        setState(() => _timezone = local);
      }
    } catch (_) {
      // Keep the couple timezone, or America/Sao_Paulo before the first save.
    }
  }

  void _syncFromCouple(Couple? couple) {
    if (_initialized || couple == null) return;
    _initialized = true;
    _anniversary = parseDateOnly(couple.anniversaryDate);
    if (couple.anniversaryDate != null) {
      _timezone = couple.timezone;
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _anniversary ?? now,
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null) setState(() => _anniversary = picked);
  }

  Future<void> _save() async {
    final anniversary = _anniversary;
    if (anniversary == null) {
      setState(() => _error = 'Escolha a data em que vocês começaram');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(coupleRepositoryProvider)
          .updateCouple(
            anniversaryDate: formatDateOnly(anniversary),
            timezone: _timezone,
          );
      ref.invalidate(coupleProvider);
      if (!mounted) return;
      popOrGo(context, APPRoutes.home);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Não foi possível salvar. Confira o fuso.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final coupleAsync = ref.watch(coupleProvider);
    _syncFromCouple(coupleAsync.asData?.value);
    final zones = {
      _timezone,
      ..._commonTimezones,
      if (coupleAsync.asData?.value != null)
        coupleAsync.asData!.value!.timezone,
    }.toList();

    return Scaffold(
      appBar: AppBar(title: const AppText('Nosso começo')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const AppText('Data de início'),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _saving ? null : _pickDate,
            child: Text(
              _anniversary == null
                  ? 'Escolher data'
                  : formatDisplayDate(formatDateOnly(_anniversary!)),
            ),
          ),
          const SizedBox(height: 24),
          const AppText('Fuso do casal'),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            key: ValueKey(_timezone),
            initialValue: zones.contains(_timezone) ? _timezone : zones.first,
            items: zones
                .map((zone) => DropdownMenuItem(value: zone, child: Text(zone)))
                .toList(),
            onChanged: _saving
                ? null
                : (value) {
                    if (value != null) setState(() => _timezone = value);
                  },
          ),
          if (_error != null) ...[const SizedBox(height: 12), AppText(_error!)],
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Salvando...' : 'Salvar'),
          ),
        ],
      ),
    );
  }
}
