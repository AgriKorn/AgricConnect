import 'dart:ui';

import 'package:flutter/material.dart';

/// Blurred ambient glow used behind the auth flow and marketplace screens:
/// two soft [colorScheme.primary]-tinted blobs behind a backdrop blur, over
/// the theme's own scaffold background. Fully [ColorScheme]-driven so it
/// renders correctly in both light and dark mode.
class AmbientBackground extends StatelessWidget {
  const AmbientBackground({super.key, required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final glow = colorScheme.primary;
    final glowAlpha = colorScheme.brightness == Brightness.dark ? 0.22 : 0.10;
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: Theme.of(context).scaffoldBackgroundColor),
        Positioned(top: -80, right: -60, child: _Blob(color: glow.withValues(alpha: glowAlpha), size: 240)),
        Positioned(
          bottom: -100,
          left: -70,
          child: _Blob(color: glow.withValues(alpha: glowAlpha * 0.75), size: 260),
        ),
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
          child: const SizedBox.expand(),
        ),
      ],
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
