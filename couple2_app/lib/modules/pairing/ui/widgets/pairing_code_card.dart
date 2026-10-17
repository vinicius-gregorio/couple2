import 'package:couple2_app/design_system/design_system.dart';
import 'package:flutter/material.dart';

import 'generate_pairing_code_button.dart';

class PairingCodeCard extends StatelessWidget {
  const PairingCodeCard({
    super.key,
    required this.code,
    this.expiryLabel,
    this.onCopy,
    this.onShare,
    this.actionsEnabled = true,
    this.allowGenerate = true,
    this.loading = false,
    this.missingMessage,
  });

  final String? code;
  final String? expiryLabel;
  final VoidCallback? onCopy;
  final VoidCallback? onShare;
  final bool actionsEnabled;
  final bool loading;

  /// Shown when there is no code and [allowGenerate] is false.
  final String? missingMessage;

  /// The waiting step already has a request, so it does not offer a second
  /// primary "Gerar código".
  final bool allowGenerate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = code;

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 200),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Column(
            children: [
              if (value == null && allowGenerate) ...[
                const AppText('Sem código ainda.', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                GeneratePairingCodeButton(enabled: actionsEnabled),
              ] else if (value == null && loading)
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (value == null)
                AppText(
                  missingMessage ?? 'Buscando o seu código…',
                  textAlign: TextAlign.center,
                )
              else
                Semantics(
                  label: 'Seu código de pareamento $value',
                  child: AppText(
                    value,
                    key: const Key('pairing-code'),
                    textAlign: TextAlign.center,
                    style:
                        (theme.textTheme.headlineMedium ??
                                const TextStyle(fontSize: 32))
                            .copyWith(
                              fontFamily: kAppFontFamily,
                              fontFamilyFallback: kAppFontFallbacks,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 8,
                            ),
                  ),
                ),
              if (expiryLabel != null) ...[
                const SizedBox(height: 12),
                AppText(
                  expiryLabel!,
                  key: const Key('pairing-expiry'),
                  textAlign: TextAlign.center,
                ),
              ],
              if (value != null) ...[
                const SizedBox(height: 20),
                LoadingButton(
                  key: const Key('copy-pairing-code'),
                  variant: LoadingButtonVariant.outlined,
                  icon: const Icon(Icons.copy),
                  onPressed: actionsEnabled ? onCopy : null,
                  child: const Text('Copiar'),
                ),
                const SizedBox(height: 12),
                LoadingButton(
                  key: const Key('share-pairing-code'),
                  variant: LoadingButtonVariant.outlined,
                  icon: const Icon(Icons.share),
                  onPressed: actionsEnabled ? onShare : null,
                  child: const Text('Compartilhar'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
