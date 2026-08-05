import 'package:flutter/material.dart';

import '../../data/models/user_role.dart';
import 'google_signin/google_signin.dart';

/// "Continue with Google" entry point for the login/registration screens.
/// Resolves to a different implementation per platform at compile time
/// (see widgets/google_signin/) because the web SDK doesn't support
/// triggering sign-in the same way the native plugin does.
class GoogleAuthButton extends StatelessWidget {
  const GoogleAuthButton({super.key, required this.colorScheme, this.loading = false, this.role});

  final ColorScheme colorScheme;
  final bool loading;
  final UserRole? role;

  @override
  Widget build(BuildContext context) {
    return buildGoogleAuthButton(colorScheme: colorScheme, loading: loading, role: role);
  }
}
