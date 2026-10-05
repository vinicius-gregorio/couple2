import 'package:couple2_app/design_system/design_system.dart';
import 'package:flutter/material.dart';

/// Styled "Sign in with Apple" button. Sign-in runs through Firebase Auth.
class AppleSignInButton extends StatelessWidget {
  const AppleSignInButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.apple, size: 24),
      label: const AppText('Entrar com Apple'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        textStyle: const TextStyle(fontSize: 16),
      ),
    );
  }
}
