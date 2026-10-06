import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// "Entrar com Google" button.
///
/// On Flutter web the canvas hit test misses [ElevatedButton] taps, and a
/// [SelectableText] label wins the gesture arena so the press never fires.
/// This target is one opaque, full-width control. Children cannot take the tap.
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
  });

  final VoidCallback? onPressed;
  final bool isLoading;

  static const loadingIndicatorKey = Key('googleSignInLoading');

  /// Dark rose on white text is about 8:1. The theme pink (#EDBAC7) is not.
  static const Color backgroundColor = Color(0xFF9D174D);
  static const Color foregroundColor = Color(0xFFFFFFFF);
  static const Color borderColor = Color(0xFF4A0A24);
  static const double minHeight = 48;

  @override
  Widget build(BuildContext context) {
    final enabled = !isLoading && onPressed != null;
    return Material(
      color: backgroundColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: borderColor, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onPressed : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: minHeight),
          child: SizedBox(
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: IgnorePointer(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _leading(),
                    const SizedBox(width: 12),
                    const Text(
                      'Entrar com Google',
                      style: TextStyle(
                        color: foregroundColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _leading() {
    if (isLoading) {
      return const SizedBox(
        key: loadingIndicatorKey,
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: foregroundColor,
        ),
      );
    }
    return SvgPicture.asset(
      'assets/images/google_logo.svg',
      width: 24,
      height: 24,
      errorBuilder: (context, error, stackTrace) {
        return const Icon(Icons.login, size: 24, color: foregroundColor);
      },
    );
  }
}
