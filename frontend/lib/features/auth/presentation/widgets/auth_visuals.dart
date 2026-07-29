import 'dart:ui';

import 'package:flutter/material.dart';

export '../../../../core/widgets/ambient_background.dart' show AmbientBackground;

/// Shared visual language for the auth flow (login, role selection,
/// registration): glass cards and pill-shaped fields/buttons layered over
/// [AmbientBackground] (core/widgets/ambient_background.dart, also used by
/// the marketplace screen). Fully [ColorScheme]-driven so it renders
/// correctly in both light and dark mode.
class AuthGlassCard extends StatelessWidget {
  const AuthGlassCard({
    super.key,
    required this.colorScheme,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = 32,
  });

  final ColorScheme colorScheme;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: colorScheme.surface.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: colorScheme.outline.withValues(alpha: 0.25)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class AuthFieldLabel extends StatelessWidget {
  const AuthFieldLabel(this.label, this.colorScheme, {super.key});

  final String label;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class AuthTextField extends StatelessWidget {
  const AuthTextField({
    super.key,
    required this.controller,
    required this.hint,
    required this.colorScheme,
    this.icon,
    this.keyboardType,
    this.obscureText = false,
    this.suffixIcon,
    this.validator,
  });

  final TextEditingController controller;
  final String hint;
  final ColorScheme colorScheme;
  final IconData? icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      style: TextStyle(color: colorScheme.onSurface),
      decoration: InputDecoration(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        hintText: hint,
        hintStyle: TextStyle(color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
        prefixIcon: icon == null ? null : Icon(icon, color: colorScheme.primary, size: 20),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      ),
    );
  }
}

class AuthPillButton extends StatelessWidget {
  const AuthPillButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.colorScheme,
    this.loading = false,
  });

  final String label;
  final VoidCallback onPressed;
  final ColorScheme colorScheme;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          shape: const StadiumBorder(),
        ),
        child: loading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.4, color: colorScheme.onPrimary),
              )
            : Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
      ),
    );
  }
}

/// "OR" divider between the password form and the Google sign-in option.
class AuthOrDivider extends StatelessWidget {
  const AuthOrDivider({super.key, required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final line = Expanded(child: Divider(color: colorScheme.outline.withValues(alpha: 0.3)));
    return Row(
      children: [
        line,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('OR', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w700)),
        ),
        line,
      ],
    );
  }
}

/// Outlined "Continue with Google" button sharing the pill shape of
/// [AuthPillButton] but styled as a secondary action.
class AuthGoogleButton extends StatelessWidget {
  const AuthGoogleButton({super.key, required this.onPressed, required this.colorScheme, this.loading = false});

  final VoidCallback? onPressed;
  final ColorScheme colorScheme;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: OutlinedButton(
        onPressed: loading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.onSurface,
          side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.4)),
          shape: const StadiumBorder(),
        ),
        child: loading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.4, color: colorScheme.primary),
              )
            : const Text('Continue with Google', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
      ),
    );
  }
}

/// Floating circular back button used instead of a default opaque AppBar,
/// so pushed auth screens keep the ambient/glass look edge-to-edge.
class AuthBackButton extends StatelessWidget {
  const AuthBackButton({super.key, required this.colorScheme, required this.onPressed});

  final ColorScheme colorScheme;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        shape: BoxShape.circle,
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.3)),
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: colorScheme.onSurface),
        onPressed: onPressed,
      ),
    );
  }
}
