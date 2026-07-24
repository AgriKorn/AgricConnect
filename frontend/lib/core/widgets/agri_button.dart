import 'package:flutter/material.dart';

/// Shared button (design system section 5.1 / checklist 0.4).
/// 52dp minimum height for primary CTAs used one-handed, outdoors.
enum AgriButtonVariant { primary, secondary, destructive }

class AgriButton extends StatelessWidget {
  const AgriButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = AgriButtonVariant.primary,
    this.expand = true,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AgriButtonVariant variant;
  final bool expand;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
    final minimumSize = expand ? const Size.fromHeight(52) : const Size(0, 52);
    final effectiveOnPressed = loading ? null : onPressed;

    final spinnerColor = switch (variant) {
      AgriButtonVariant.primary => colorScheme.onPrimary,
      AgriButtonVariant.secondary => colorScheme.primary,
      AgriButtonVariant.destructive => colorScheme.onErrorContainer,
    };

    final child = loading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.4, color: spinnerColor),
          )
        : icon == null
            ? Text(label)
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 20),
                  const SizedBox(width: 8),
                  Text(label),
                ],
              );

    switch (variant) {
      case AgriButtonVariant.primary:
        return FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            minimumSize: minimumSize,
            shape: shape,
          ),
          onPressed: effectiveOnPressed,
          child: child,
        );
      case AgriButtonVariant.secondary:
        return OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: colorScheme.primary,
            side: BorderSide(color: colorScheme.outline),
            minimumSize: minimumSize,
            shape: shape,
          ),
          onPressed: effectiveOnPressed,
          child: child,
        );
      case AgriButtonVariant.destructive:
        return FilledButton.tonal(
          style: FilledButton.styleFrom(
            backgroundColor: colorScheme.errorContainer,
            foregroundColor: colorScheme.onErrorContainer,
            minimumSize: minimumSize,
            shape: shape,
          ),
          onPressed: effectiveOnPressed,
          child: child,
        );
    }
  }
}
