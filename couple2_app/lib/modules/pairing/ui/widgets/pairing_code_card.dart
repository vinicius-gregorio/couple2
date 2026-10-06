import 'package:couple2_app/design_system/design_system.dart';
import 'package:flutter/material.dart';

class PairingCodeCard extends StatelessWidget {
  const PairingCodeCard({
    super.key,
    required this.code,
    this.expiryLabel,
    this.onCopy,
    this.onShare,
  });

  final String? code;
  final String? expiryLabel;
  final VoidCallback? onCopy;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = code;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Column(
          children: [
            if (value == null)
              const AppText(
                'Sem código ainda. Saia e entre de novo para gerar um.',
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
                            fontFamily: 'monospace',
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
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('copy-pairing-code'),
                      onPressed: onCopy,
                      icon: const Icon(Icons.copy),
                      label: const Text('Copiar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('share-pairing-code'),
                      onPressed: onShare,
                      icon: const Icon(Icons.share),
                      label: const Text('Compartilhar'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
