import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/auth_controller.dart';
import '../../../data/models/user_role.dart';
import '../auth_visuals.dart';

/// Android/iOS: the existing pill button triggers GoogleSignIn.signIn()
/// directly, same as before this file existed.
Widget buildGoogleAuthButton({
  required ColorScheme colorScheme,
  required bool loading,
  UserRole? role,
}) {
  return Consumer(
    builder: (context, ref, _) => AuthGoogleButton(
      loading: loading,
      colorScheme: colorScheme,
      onPressed: () => ref.read(authControllerProvider.notifier).loginWithGoogle(role: role),
    ),
  );
}
