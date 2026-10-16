import 'package:couple2_app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

import '../../../../../app/routing/app_back_button.dart';
import '../../../../../core/core.dart';
import '../../../../../app/routing/pop_or_go.dart';
import '../../../../../app/routing/routes.dart';
import '../../../../pairing/ui/widgets/unpair_button.dart';
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

const _timezoneLabels = {
  'America/Sao_Paulo': 'Brasília (São Paulo)',
  'America/Manaus': 'Manaus',
  'America/Belem': 'Belém',
  'America/Fortaleza': 'Fortaleza',
  'America/Recife': 'Recife',
  'America/Noronha': 'Fernando de Noronha',
  'America/Rio_Branco': 'Rio Branco',
  'America/New_York': 'Nova York',
  'America/Chicago': 'Chicago',
  'America/Denver': 'Denver',
  'America/Los_Angeles': 'Los Angeles',
  'Europe/Lisbon': 'Lisboa',
  'Europe/London': 'Londres',
  'UTC': 'UTC',
};

String timezoneLabel(String zone) {
  return _timezoneLabels[zone] ??
      zone.replaceAll('_', ' ').replaceAll('/', ' · ');
}

class CoupleSettingsPage extends ConsumerStatefulWidget {
  const CoupleSettingsPage({super.key});

  @override
  ConsumerState<CoupleSettingsPage> createState() => _CoupleSettingsPageState();
}

class _CoupleSettingsPageState extends ConsumerState<CoupleSettingsPage> {
  DateTime? _anniversary;
  String _timezone = 'America/Sao_Paulo';
  bool _saving = false;
  bool _unpairing = false;
  String? _error;
  bool _initialized = false;
  final _pop = PopGuard();

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
    final picked = await showAppDatePicker(
      context: context,
      initialDate: _anniversary ?? now,
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null) setState(() => _anniversary = picked);
  }

  bool get _locked => _saving || _unpairing;

  Future<void> _save() async {
    if (_locked || _pop.used) return;
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
      try {
        await ref.read(coupleProvider.future);
      } catch (_) {
        // The save landed. Home refetches if this read failed.
      }
      if (!mounted || _pop.used) return;
      popOrGo(context, APPRoutes.home, guard: _pop);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = userFacingError(error);
        });
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

    if (coupleAsync.isLoading && !coupleAsync.hasValue) {
      return Scaffold(
        appBar: AppBar(
          leading: AppBackButton(),
          title: AppText('Nosso começo'),
        ),
        body: const FormSkeleton(),
      );
    }
    if (coupleAsync.hasError && !coupleAsync.hasValue) {
      return Scaffold(
        appBar: AppBar(
          leading: AppBackButton(),
          title: AppText('Nosso começo'),
        ),
        body: ErrorView(
          message: 'Não foi possível carregar o casal.',
          onRetry: () => ref.invalidate(coupleProvider),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: AppBackButton(enabled: !_locked),
        title: AppText('Nosso começo'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const AppText('Data de início'),
          const SizedBox(height: 8),
          LoadingButton(
            variant: LoadingButtonVariant.outlined,
            onPressed: _locked
                ? null
                : () {
                    _pickDate();
                  },
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
                .map(
                  (zone) => DropdownMenuItem(
                    value: zone,
                    child: Text(timezoneLabel(zone)),
                  ),
                )
                .toList(),
            onChanged: _locked
                ? null
                : (value) {
                    if (value != null) setState(() => _timezone = value);
                  },
          ),
          MutationErrorBanner(message: _error),
          const SizedBox(height: 24),
          LoadingButton(
            loading: _saving,
            onPressed: _locked || _anniversary == null ? null : _save,
            child: const Text('Salvar'),
          ),
          const SizedBox(height: 48),
          const Divider(),
          const SizedBox(height: 16),
          const AppText('Desfazer o par'),
          const SizedBox(height: 8),
          const AppText(
            'As listas deste casal ficam inacessíveis para os dois. Não há arquivo.',
          ),
          const SizedBox(height: 12),
          UnpairButton(
            enabled: !_saving,
            onBusyChanged: (busy) {
              if (mounted) setState(() => _unpairing = busy);
            },
          ),
        ],
      ),
    );
  }
}
