import 'dart:ui';

import 'package:flutter/material.dart';

/// Shown only while [AuthController] restores the session on cold start
/// (AuthStatus.restoring) — the router redirects away as soon as that
/// resolves to unauthenticated/authenticated/pendingVerification.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                radius: 1.1,
                colors: [primary.withValues(alpha: 0.85), primary],
              ),
            ),
          ),
          Positioned(
            top: -70,
            left: -50,
            child: _GlowBlob(color: Colors.white.withValues(alpha: 0.18), size: 220),
          ),
          Positioned(
            bottom: -90,
            right: -60,
            child: _GlowBlob(color: Colors.black.withValues(alpha: 0.14), size: 260),
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
            child: const SizedBox.expand(),
          ),
          Center(
            child: Image.asset('assets/images/agri_logo.png', width: 180),
          ),
        ],
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  const _GlowBlob({required this.color, required this.size});

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
