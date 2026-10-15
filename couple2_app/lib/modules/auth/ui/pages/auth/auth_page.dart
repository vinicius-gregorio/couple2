import 'dart:async';

import 'package:couple2_app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/apple_sign_in_button.dart';
import '../../widgets/google_sign_in_button.dart';
import 'auth_viewmodel.dart';

class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({super.key});

  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage> {
  void _handleGoogleSignIn() {
    // signInWithGoogle sets loading synchronously, before its first await.
    unawaited(ref.read(authViewModelProvider.notifier).signInWithGoogle());
  }

  Future<void> _handleAppleSignIn() async {
    await ref.read(authViewModelProvider.notifier).signInWithApple();
    // Router redireciona automaticamente em caso de sucesso.
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authViewModelProvider);

    ref.listen(authViewModelProvider, (previous, next) {
      final message = next.errorMessage;
      if (message == null || message == previous?.errorMessage) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    });

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: const AppText('Login')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.favorite, size: 80, color: scheme.primary),
              const SizedBox(height: 24),
              AppText(
                'Couple App',
                style: theme.textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              AppText(
                'Conecte-se com seu parceiro',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              GoogleSignInButton(
                onPressed: _handleGoogleSignIn,
                isLoading: authState.isLoading,
              ),
              const SizedBox(height: 16),
              AppleSignInButton(
                onPressed: authState.isLoading ? null : _handleAppleSignIn,
                isLoading: authState.isLoading,
              ),

              if (authState.errorMessage != null) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: scheme.error),
                  ),
                  child: AppText(
                    authState.errorMessage!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onErrorContainer,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
