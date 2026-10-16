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
import '../../widgets/pairing_poller.dart';
import '../../widgets/pairing_scaffold.dart';

class EnterCodePage extends ConsumerStatefulWidget {
  const EnterCodePage({super.key});

  @override
  ConsumerState<EnterCodePage> createState() => _EnterCodePageState();
}

class _EnterCodePageState extends ConsumerState<EnterCodePage> {
  final _controller = TextEditingController();
  var _submitting = false;
  var _typed = false;
  String? _error;
  final _pop = PopGuard();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onCodeChanged);
    // Browser autofill can refill a code from a previous visit. Clear that
    // once, before the user types. A later keystroke is kept.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _typed || _controller.text.isEmpty) return;
      _controller.clear();
    });
  }

  void _onCodeChanged() {
    if (mounted) setState(() => _error = null);
  }

  @override
  void dispose() {
    _controller.removeListener(_onCodeChanged);
    _controller.dispose();
    super.dispose();
  }

  bool get _controlsLocked => ref.read(pairingControlsLockedProvider) > 0;

  bool get _canSubmit =>
      !_submitting &&
      !_controlsLocked &&
      validatePartnerCode(_controller.text, myCode: _myCode) == null;

  /// Format and self-code errors show once the field has 6 characters.
  /// Shorter input stays quiet and the button stays disabled.
  String? get _shownError {
    if (_error != null) return _error;
    if (normalizePairingCode(_controller.text).length < 6) return null;
    return validatePartnerCode(_controller.text, myCode: _myCode);
  }

  String? get _myCode {
    final sessionCode = ref.read(sessionProvider).asData?.value?.pairingCode;
    if (sessionCode != null && sessionCode.isNotEmpty) return sessionCode;
    return ref.read(pairingStatusProvider).asData?.value.pairingCode;
  }

  Future<void> _submit() async {
    if (_submitting) return;
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
    final status = statusAsync.asData?.value;
    final controlsLocked = ref.watch(pairingControlsLockedProvider) > 0;
    final incoming =
        ref.watch(incomingPairingRequestsProvider).asData?.value ?? const [];
    final acceptIsPrimary = incoming.isNotEmpty;
    if (statusAsync.isLoading && !statusAsync.hasValue) {
      return PairingPoller(
        enabled: true,
        child: PairingScaffold(
          step: 2,
          actionsEnabled: !_submitting && !controlsLocked,
          onRefresh: () => ref.read(pairingStatusProvider.notifier).reload(),
          children: const [CardSkeleton(lines: 2)],
        ),
      );
    }

    return PairingPoller(
      enabled: status?.phase != PairingPhase.paired,
      child: PairingScaffold(
        step: 2,
        actionsEnabled: !_submitting && !controlsLocked,
        onRefresh: () => ref.read(pairingStatusProvider.notifier).reload(),
        children: [
          const AppText(
            'Código do par',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const AppText(
            'Digite o código de 6 caracteres que a outra pessoa mostrou. O pedido também pode ser aceito ou recusado na tela de pareamento.',
          ),
          const SizedBox(height: 20),
          if (status?.phase == PairingPhase.pending) ...[
            AppText(
              pairingRequestNotice(status!),
              style: TextStyle(color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 16),
          ],
          TextField(
            key: const Key('partner-code-field'),
            controller: _controller,
            enabled: !_submitting && !controlsLocked,
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            enableSuggestions: false,
            autofillHints: const [],
            onChanged: (_) => _typed = true,
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
              if (_canSubmit) _submit();
            },
          ),
          MutationErrorBanner(message: _shownError),
          const SizedBox(height: 24),
          LoadingButton(
            key: const Key('submit-partner-code'),
            variant: acceptIsPrimary
                ? LoadingButtonVariant.outlined
                : LoadingButtonVariant.filled,
            loading: _submitting,
            onPressed: _canSubmit ? _submit : null,
            child: Text(_submitting ? 'Enviando…' : 'Enviar pedido'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _submitting || controlsLocked
                ? null
                : () => popOrGo(context, PairingRoutes.hub, guard: _pop),
            child: const Text('Voltar ao meu código'),
          ),
        ],
      ),
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
