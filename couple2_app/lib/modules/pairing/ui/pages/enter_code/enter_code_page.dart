import 'package:couple2_app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../app/routing/pop_or_go.dart';
import '../../../../../app/routing/routes.dart';
import '../../../../../app/session.dart';
import '../../../../../app/session_provider.dart';
import '../../../data/pairing_providers.dart';
import '../../../domain/domain.dart';
import '../../../routing/routes.dart';
import '../../widgets/pairing_scaffold.dart';

class EnterCodePage extends ConsumerStatefulWidget {
  const EnterCodePage({super.key});

  @override
  ConsumerState<EnterCodePage> createState() => _EnterCodePageState();
}

class _EnterCodePageState extends ConsumerState<EnterCodePage> {
  final _controller = TextEditingController();
  var _submitting = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? get _myCode {
    final sessionCode = ref.read(sessionProvider).asData?.value?.pairingCode;
    if (sessionCode != null && sessionCode.isNotEmpty) return sessionCode;
    return ref.read(pairingStatusProvider).asData?.value.pairingCode;
  }

  Future<void> _submit() async {
    final validation = validatePartnerCode(_controller.text, myCode: _myCode);
    if (validation != null) {
      setState(() => _error = validation);
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(pairingStatusProvider.notifier)
          .submitCode(_controller.text);
      if (!mounted) return;
      if (result.phase == PairingPhase.paired) {
        final session = ref.read(sessionProvider).asData?.value;
        if (sessionNeedsPairing(session)) {
          setState(() {
            _error =
                'Pareou, mas a sessão não atualizou. Puxe para atualizar ou entre de novo.';
          });
          return;
        }
        context.go(APPRoutes.home);
        return;
      }
      context.pushReplacement(PairingRoutes.waiting);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = pairingErrorMessage(error));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusAsync = ref.watch(pairingStatusProvider);
    if (statusAsync.isLoading && !statusAsync.hasValue) {
      return const PairingScaffold(
        step: 2,
        children: [
          Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      );
    }

    return PairingScaffold(
      step: 2,
      children: [
        const AppText(
          'Código do par',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        const AppText(
          'Digite o código de 6 caracteres que a outra pessoa mostrou. Ela também precisa digitar o seu.',
        ),
        const SizedBox(height: 20),
        TextField(
          key: const Key('partner-code-field'),
          controller: _controller,
          enabled: !_submitting,
          textCapitalization: TextCapitalization.characters,
          autocorrect: false,
          enableSuggestions: false,
          maxLength: 6,
          textInputAction: TextInputAction.done,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
            const _UpperCaseFormatter(),
          ],
          decoration: const InputDecoration(
            labelText: 'Código de 6 caracteres',
            counterText: '',
          ),
          onSubmitted: (_) {
            if (!_submitting) _submit();
          },
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          AppText(_error!, style: TextStyle(color: theme.colorScheme.error)),
        ],
        const SizedBox(height: 24),
        ElevatedButton(
          key: const Key('submit-partner-code'),
          onPressed: _submitting ? null : _submit,
          child: Text(_submitting ? 'Enviando...' : 'Enviar pedido'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _submitting
              ? null
              : () => popOrGo(context, PairingRoutes.hub),
          child: const Text('Voltar ao meu código'),
        ),
      ],
    );
  }
}

class _UpperCaseFormatter extends TextInputFormatter {
  const _UpperCaseFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue old,
    TextEditingValue value,
  ) {
    return value.copyWith(text: value.text.toUpperCase());
  }
}
