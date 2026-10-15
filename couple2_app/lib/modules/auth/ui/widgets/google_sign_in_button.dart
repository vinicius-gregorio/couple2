import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'google_logo.dart';

/// "Entrar com Google" button.
///
/// On Flutter web the canvas hit test misses a Material button, and a
/// [SelectableText] label wins the gesture arena so the press never fires.
/// This target is one opaque, full-width control. Children cannot take the tap.
/// Colors come from the app [ColorScheme] so the label stays onPrimary.
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
  });

  final VoidCallback? onPressed;
  final bool isLoading;

  static const loadingIndicatorKey = Key('googleSignInLoading');
  static const double minHeight = 48;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = isLoading || onPressed != null;
    final enabled = !isLoading && onPressed != null;
    final background = active ? scheme.primary : scheme.surfaceContainerHighest;
    final foreground = active
        ? scheme.onPrimary
        : scheme.onSurface.withValues(alpha: 0.38);
    final border = active
        ? Color.alphaBlend(const Color(0x59000000), scheme.primary)
        : scheme.outline.withValues(alpha: 0.45);
    return Material(
      color: background,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: border, width: 2),
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
                    _leading(foreground),
                    const SizedBox(width: 12),
                    Text(
                      'Entrar com Google',
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
    );
  }

  Widget _leading(Color foreground) {
    if (isLoading) {
      return SizedBox(
        key: loadingIndicatorKey,
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: foreground,
        ),
      );
    }
    return SvgPicture(
      kGoogleLogoLoader,
      width: 24,
      height: 24,
      errorBuilder: (context, error, stackTrace) {
        return Icon(Icons.login, size: 24, color: foreground);
      },
    );
  }
}
