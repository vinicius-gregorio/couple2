import 'package:couple2_app/design_system/design_system.dart';
import 'package:flutter/material.dart';

/// Styled "Sign in with Google" button. Sign-in runs through Firebase Auth.
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Image.network(
        'https://www.google.com/favicon.ico',
        height: 24,
        errorBuilder: (context, error, stackTrace) {
          return const Icon(Icons.login);
        },
      ),
      label: const AppText('Entrar com Google'),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        textStyle: const TextStyle(fontSize: 16),
      ),
    );
  }
}
