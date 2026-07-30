import 'package:flutter/material.dart';

/// Shown only while [AuthController] restores the session on cold start
/// (AuthStatus.restoring) — the router redirects away as soon as that
/// resolves to unauthenticated/authenticated/pendingVerification.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // No explicit backgroundColor: Scaffold falls back to
    // Theme.of(context).scaffoldBackgroundColor, the same base color
    // AmbientBackground paints under the login screen.
    return const Scaffold(
      body: Center(
        child: Image(image: AssetImage('assets/images/agri_logo.png'), width: 180),
      ),
    );
  }
}
