import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/application/auth_controller.dart';
import 'edit_profile_screen.dart';

void _openEditProfile(
  BuildContext context, {
  required Widget Function(double size) avatarBuilder,
  required String locationLabel,
  required String locationHint,
  required String verifiedSubtitle,
}) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => EditProfileScreen(
        avatarBuilder: avatarBuilder,
        locationLabel: locationLabel,
        locationHint: locationHint,
        verifiedSubtitle: verifiedSubtitle,
      ),
    ),
  );
}

/// Shared Account Settings screen: one implementation reused across roles
/// (mirrors [HelpSupportScreen]'s pattern), parameterized with the
/// role-specific avatar and badge copy. Name/email come straight off the
/// session's [UserModel] since that shape is uniform across roles.
class AccountSettingsScreen extends ConsumerWidget {
  const AccountSettingsScreen({
    super.key,
    required this.avatarBuilder,
    required this.roleBadgeLabel,
    required this.onHelpTap,
    required this.locationLabel,
    required this.locationHint,
    required this.verifiedSubtitle,
  });

  final Widget Function(double size) avatarBuilder;
  final String roleBadgeLabel;
  final VoidCallback onHelpTap;
  final String locationLabel;
  final String locationHint;
  final String verifiedSubtitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final user = ref.watch(authControllerProvider).user;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          _Background(colorScheme: colorScheme),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _CircleIconButton(
                        colorScheme: colorScheme,
                        icon: Icons.arrow_back_rounded,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      Expanded(
                        child: Text(
                          'Account Settings',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: colorScheme.onSurface, fontSize: 21, fontWeight: FontWeight.w800),
                        ),
                      ),
                      _CircleIconButton(
                        colorScheme: colorScheme,
                        icon: Icons.help_outline_rounded,
                        onPressed: onHelpTap,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        SizedBox(width: 64, height: 64, child: avatarBuilder(64)),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.name ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: colorScheme.onSurface, fontSize: 19, fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                roleBadgeLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w700, fontSize: 13.5),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                user?.email ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _openEditProfile(
                            context,
                            avatarBuilder: avatarBuilder,
                            locationLabel: locationLabel,
                            locationHint: locationHint,
                            verifiedSubtitle: verifiedSubtitle,
                          ),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(Icons.edit_rounded, color: colorScheme.primary, size: 18),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'AgriConnect v2.4.0',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12.5, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'AI-Powered Agricultural Marketplace',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8), fontSize: 12.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Background extends StatelessWidget {
  const _Background({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: Theme.of(context).scaffoldBackgroundColor),
        Positioned(top: -80, right: -60, child: _Blob(color: colorScheme.primary.withValues(alpha: 0.22), size: 260)),
        Positioned(bottom: -100, left: -70, child: _Blob(color: colorScheme.secondary.withValues(alpha: 0.2), size: 280)),
        BackdropFilter(filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80), child: const SizedBox.expand()),
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
    return Container(width: size, height: size, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.colorScheme, required this.icon, required this.onPressed});

  final ColorScheme colorScheme;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
        shape: BoxShape.circle,
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.3)),
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, size: 18, color: colorScheme.onSurface),
        onPressed: onPressed,
      ),
    );
  }
}
