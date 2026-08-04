import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/application/auth_controller.dart';

/// Real uploaded profile photo when the logged-in user has one, otherwise a
/// colored initials circle — replaces the old per-role static stock photos
/// (every farmer used to show the exact same asset as if it were their own
/// picture).
class UserAvatar extends ConsumerWidget {
  const UserAvatar({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final colorScheme = Theme.of(context).colorScheme;
    final photoUrl = user?.photoUrl;

    if (photoUrl != null && photoUrl.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          photoUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _InitialsCircle(name: user?.name, size: size, colorScheme: colorScheme),
          loadingBuilder: (context, child, progress) =>
              progress == null ? child : _InitialsCircle(name: user?.name, size: size, colorScheme: colorScheme),
        ),
      );
    }

    return _InitialsCircle(name: user?.name, size: size, colorScheme: colorScheme);
  }
}

String _initialsFor(String? name) {
  final trimmed = name?.trim() ?? '';
  if (trimmed.isEmpty) return '?';
  final parts = trimmed.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
}

class _InitialsCircle extends StatelessWidget {
  const _InitialsCircle({required this.name, required this.size, required this.colorScheme});

  final String? name;
  final double size;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: colorScheme.primary, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        _initialsFor(name),
        style: TextStyle(
          color: colorScheme.onPrimary,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.38,
        ),
      ),
    );
  }
}
