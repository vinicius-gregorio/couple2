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
import '../../share_pairing_code.dart';
import '../../widgets/pairing_code_card.dart';
import '../../widgets/pairing_poller.dart';
import '../../widgets/pairing_scaffold.dart';

class WaitingPage extends ConsumerStatefulWidget {
  const WaitingPage({super.key});

  @override
  ConsumerState<WaitingPage> createState() => _WaitingPageState();
}

class _WaitingPageState extends ConsumerState<WaitingPage> {
  var _cancelling = false;
  var _confirming = false;
  var _loadingCode = true;
  String? _error;
  String? _codeError;
  final _pop = PopGuard();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureCode());
  }

  Future<void> _ensureCode() async {
    if (!mounted) return;
    final status = ref.read(pairingStatusProvider).asData?.value;
    final session = ref.read(sessionProvider).asData?.value;
    final shown = shownPairingCode(
      status: status,
      sessionCode: session?.pairingCode,
      sessionExpiresAt: session?.pairingCodeExpiresAt,
    );
    if (shown.code != null) {
      if (mounted) setState(() => _loadingCode = false);
      return;
    }
    setState(() {
      _loadingCode = true;
      _codeError = null;
    });
    try {
      await ref.read(pairingStatusProvider.notifier).ensureShownCode();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _codeError = pairingErrorMessage(error, action: PairingAction.generate);
      });
    } finally {
      if (mounted) setState(() => _loadingCode = false);
    }
  }

  Future<void> _refresh() async {
    final phase = await ref.read(pairingStatusProvider.notifier).poll();
    if (!mounted || phase != PairingPhase.paired) return;
    final session = ref.read(sessionProvider).asData?.value;
    if (sessionNeedsPairing(session)) {
      setState(() {
        _error =
            'Seu par confirmou, mas a sessão não atualizou. Tente de novo.';
      });
      return;
    }
    context.go(APPRoutes.home);
  }

  Future<void> _cancel() async {
    if (_cancelling || _confirming) return;
    setState(() {
      _confirming = true;
      _error = null;
    });
    final accepted = await confirmDestructive(
      context,
      title: 'Cancelar pedido?',
      message:
          'O pedido some para a outra pessoa. Vocês podem enviar outro depois.',
      confirmLabel: 'Cancelar pedido',
      confirmKey: const Key('confirm-cancel-pairing'),
    );
    if (!mounted) return;
    if (!accepted) {
      setState(() => _confirming = false);
      return;
    }
    setState(() {
      _confirming = false;
      _cancelling = true;
      _error = null;
    });
    try {
      await ref.read(pairingStatusProvider.notifier).cancelRequest();
      if (!mounted) return;
      context.go(PairingRoutes.hub);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = pairingErrorMessage(error, action: PairingAction.cancel);
      });
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(pairingStatusProvider, (previous, next) {
      final was = previous?.asData?.value.phase;
      final now = next.asData?.value.phase;
      if (next is AsyncData<PairingSnapshot> &&
          _error != null &&
          !_cancelling &&
          !_confirming &&
          !(was == PairingPhase.pending && now == PairingPhase.unpaired)) {
        setState(() => _error = null);
      }
      if (was != PairingPhase.pending || now != PairingPhase.unpaired) return;
      if (_cancelling || _confirming) return;
      ref
          .read(pairingDeclineMessageProvider.notifier)
          .show(declinedPairingMessage);
      context.go(PairingRoutes.hub);
    });
    final status = ref.watch(pairingStatusProvider).asData?.value;
    final session = ref.watch(sessionProvider).asData?.value;
    final controlsLocked = ref.watch(pairingControlsLockedProvider) > 0;
    final shown = shownPairingCode(
      status: status,
      sessionCode: session?.pairingCode,
      sessionExpiresAt: session?.pairingCodeExpiresAt,
    );
    final partnerName = status?.partner?.name;

    final busy = _cancelling || _confirming || controlsLocked;
    return PairingPoller(
      enabled: status?.phase != PairingPhase.paired,
      child: PairingScaffold(
        step: 3,
        actionsEnabled: !busy,
        onRefresh: _refresh,
        children: [
          const AppText(
            'Aguardando confirmação',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const AppText(
            'A outra pessoa vê o pedido na tela de pareamento e pode Aceitar ou Recusar. Ela também pode digitar o seu código.',
          ),
          const SizedBox(height: 8),
          if (status?.pendingCode != null) ...[
            const SizedBox(height: 16),
            AppText('Código que você enviou: ${status!.pendingCode}'),
          ],
          const SizedBox(height: 16),
          const AppText('Seu código'),
          const SizedBox(height: 8),
          PairingCodeCard(
            code: shown.code,
            allowGenerate: false,
            loading: shown.code == null && _loadingCode,
            missingMessage: _codeError,
            actionsEnabled: !busy,
            expiryLabel: pairingExpiryLabel(shown.expiresAt),
            onCopy: shown.code == null
                ? null
                : () async {
                    await Clipboard.setData(ClipboardData(text: shown.code!));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Código copiado')),
                    );
                  },
            onShare: shown.code == null
                ? null
                : () async {
                    final result = await sharePairingCode(shown.code!);
                    if (!context.mounted) return;
                    final message = result == PairingShareResult.opened
                        ? 'Abri o compartilhamento'
                        : 'Mensagem copiada para compartilhar';
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(message)));
                  },
          ),
          if (status?.phase == PairingPhase.paired) ...[
            const SizedBox(height: 16),
            AppText(
              partnerName == null || partnerName.isEmpty
                  ? 'Pareamento concluído. Abrindo a Home…'
                  : 'Pareados com $partnerName. Abrindo a Home…',
            ),
            const SizedBox(height: 12),
            LoadingButton(
              onPressed: _refresh,
              child: const Text('Ir para a Home'),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            child: Center(
              child: _error == null
                  ? const AppText('Atualizando automaticamente…')
                  : Text(
                      _error!,
                      key: MutationErrorBanner.bannerKey,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          LoadingButton(
            key: const Key('cancel-pairing-request'),
            variant: LoadingButtonVariant.outlined,
            loading: _cancelling,
            onPressed: busy
                ? null
                : () {
                    _cancel();
                  },
            child: const Text('Cancelar pedido'),
          ),
          const SizedBox(height: 8),
          LoadingButton(
            variant: LoadingButtonVariant.text,
            onPressed: busy
                ? null
                : () => popOrGo(context, PairingRoutes.hub, guard: _pop),
            child: const Text('Voltar ao meu código'),
          ),
        ],
      ),
    );
  }
}
