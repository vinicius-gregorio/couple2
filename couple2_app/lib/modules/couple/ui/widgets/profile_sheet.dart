import 'package:couple2_app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/session.dart';
import '../../../../app/session_provider.dart';
import '../../data/couple_providers.dart';
import '../../domain/domain.dart';

class ProfileSheet extends ConsumerStatefulWidget {
  const ProfileSheet({super.key, required this.session});

  final Session session;

  @override
  ConsumerState<ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends ConsumerState<ProfileSheet> {
  DateTime? _birthDate;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _birthDate = parseDateOnly(widget.session.birthDate);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year, now.month, now.day),
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(coupleRepositoryProvider).updateMyBirthDate(
            _birthDate == null ? null : formatDateOnly(_birthDate!),
          );
      await ref.read(sessionProvider.notifier).refresh();
      ref.invalidate(coupleProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Não foi possível salvar o aniversário');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
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
          AppText(session.name, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          AppText(session.email),
          const SizedBox(height: 16),
          const AppText('Meu aniversário'),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _saving ? null : _pickDate,
            child: Text(
              _birthDate == null
                  ? 'Escolher data'
                  : formatDisplayDate(formatDateOnly(_birthDate!)),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            AppText(_error!),
          ],
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Salvando...' : 'Salvar'),
          ),
        ],
      ),
    );
  }
}
