import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/application/auth_controller.dart';

/// Renders the signed-in user's picked profile photo
/// ([UserModel.avatarPath]) when one exists, otherwise falls back to
/// [fallback] (typically a [GreenInitialsAvatar]). The single place that
/// decides "does this user have a custom photo", so every avatar across the
/// app (dashboard header, profile hero, account settings, edit profile)
/// stays in sync the moment [AuthController.updateAvatar] is called.
class UserAvatar extends ConsumerWidget {
  const UserAvatar({super.key, required this.size, required this.fallback});

  final double size;
  final WidgetBuilder fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avatarPath = ref.watch(authControllerProvider.select((s) => s.user?.avatarPath));
    if (avatarPath == null || kIsWeb) {
      return fallback(context);
    }
    return ClipOval(
      child: Image.file(
        File(avatarPath),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallback(context),
      ),
    );
  }
}

/// Default avatar for a new user: a green circle with their initials —
/// no bundled headshot placeholder.
class GreenInitialsAvatar extends StatelessWidget {
  const GreenInitialsAvatar({super.key, required this.name, required this.size, required this.colorScheme});

  final String? name;
  final double size;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: ColoredBox(
        color: colorScheme.primary,
        child: Center(
          child: Text(
            initialsOf(name),
            style: TextStyle(color: colorScheme.onPrimary, fontWeight: FontWeight.w800, fontSize: size * 0.34),
          ),
        ),
      ),
    );
  }
}

/// Shared "first + last initial" derivation, e.g. "Ama Owusu" -> "AO".
String initialsOf(String? name) {
  final trimmed = name?.trim() ?? '';
  if (trimmed.isEmpty) return '?';
  final parts = trimmed.split(RegExp(r'\s+'));
  final first = parts.first[0];
  final last = parts.length > 1 ? parts.last[0] : '';
  return (first + last).toUpperCase();
}
