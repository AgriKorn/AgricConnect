import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/models/user_role.dart';
import 'widgets/auth_visuals.dart';

/// Checklist 1.1: large icon-led cards. Admin has no self-registration path
/// per PRD 3.4, so it never appears here. Shares its visual language
/// (widgets/auth_visuals.dart) with login and registration.
class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  static const _selectableRoles = [UserRole.farmer, UserRole.buyer, UserRole.driver];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          AmbientBackground(colorScheme: colorScheme),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AuthBackButton(
                    colorScheme: colorScheme,
                    onPressed: () => context.canPop() ? context.pop() : context.go('/login'),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Join AgriConnect',
                    style: TextStyle(color: colorScheme.onSurface, fontSize: 26, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'How will you use AgriConnect?',
                    style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14.5),
                  ),
                  const SizedBox(height: 24),
                  for (final role in _selectableRoles) ...[
                    _RoleOptionCard(
                      role: role,
                      colorScheme: colorScheme,
                      onTap: () => context.push('/register/${role.pathSegment}'),
                    ),
                    const SizedBox(height: 14),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleOptionCard extends StatelessWidget {
  const _RoleOptionCard({required this.role, required this.colorScheme, required this.onTap});

  final UserRole role;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = role.colorOf(colorScheme);
    return AuthGlassCard(
      colorScheme: colorScheme,
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(32),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(role.icon, color: accent, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "I'm a ${role.label}",
                      style: TextStyle(color: colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      role.description,
                      style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
