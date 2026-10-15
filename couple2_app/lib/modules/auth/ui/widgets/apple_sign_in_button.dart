import 'package:couple2_app/design_system/design_system.dart';
import 'package:flutter/material.dart';

/// Apple provider is disabled in Firebase (`OPERATION_NOT_ALLOWED`).
/// The login screen must not build [AppleSignInButton] while this is false.
const bool kAppleSignInEnabled = false;

/// "Entrar com Apple" button. Sign-in still runs through Firebase Auth.
///
/// Flutter web misses taps on a Material icon button and that control does not
/// show up as a button in the accessibility tree. This target is one opaque,
/// full-width button with explicit button semantics. Children cannot take the tap.
class AppleSignInButton extends StatelessWidget {
  const AppleSignInButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
  });

  final VoidCallback? onPressed;
  final bool isLoading;

  static const loadingIndicatorKey = Key('appleSignInLoading');
  static const double minHeight = 48;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = isLoading || onPressed != null;
    final enabled = !isLoading && onPressed != null;
    final background = active ? scheme.primary : disabledFill;
    final foreground = active
        ? scheme.onPrimary
        : scheme.onSurface.withValues(alpha: 0.38);
    return Semantics(
      button: true,
      enabled: enabled,
      label: 'Entrar com Apple',
      onTap: enabled ? onPressed : null,
      child: Material(
        color: background,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.largeRadius),
        clipBehavior: Clip.antiAlias,
        child: GestureDetector(
          excludeFromSemantics: true,
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? onPressed : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: minHeight),
            child: SizedBox(
              width: double.infinity,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                child: ExcludeSemantics(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _leading(foreground),
                      const SizedBox(width: 12),
                      Text(
                        'Entrar com Apple',
                        style: TextStyle(
                          color: foreground,
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
      ),
    );
  }

  Widget _leading(Color foreground) {
    if (isLoading) {
      return SizedBox(
        key: loadingIndicatorKey,
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2, color: foreground),
      );
    }
    return Icon(Icons.apple, size: 24, color: foreground);
  }
}
