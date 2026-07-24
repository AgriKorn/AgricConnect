import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_mode_controller.dart';
import '../../../core/widgets/agri_button.dart';
import '../../../core/widgets/agri_card.dart';
import '../../../core/widgets/agri_dialog.dart';
import '../application/auth_controller.dart';
import '../data/models/user_role.dart';

/// Shared Profile tab across all three roles. Houses the dark/light/system
/// toggle (claude.md Theme Toggle: "lives in each role's Profile/Settings
/// screen") and Logout (checklist 1.5 exit criteria).
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final session = ref.watch(authControllerProvider);
    final user = session.user;
    final themeMode = ref.watch(themeModeControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AgriCard(
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: colorScheme.primaryContainer,
                    child: Text(
                      (user?.name.isNotEmpty == true ? user!.name[0] : '?').toUpperCase(),
                      style: TextStyle(color: colorScheme.onPrimaryContainer, fontWeight: FontWeight.w800, fontSize: 20),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user?.name ?? 'Unknown', style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 2),
                        Text(user?.phone ?? '', style: Theme.of(context).textTheme.bodyMedium),
                        if (user != null) ...[
                          const SizedBox(height: 2),
                          Text(user.role.label, style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w600, fontSize: 12.5)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text('Appearance', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            AgriCard(
              child: SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(value: ThemeMode.system, label: Text('System'), icon: Icon(Icons.brightness_auto_outlined)),
                  ButtonSegment(value: ThemeMode.light, label: Text('Light'), icon: Icon(Icons.light_mode_outlined)),
                  ButtonSegment(value: ThemeMode.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode_outlined)),
                ],
                selected: {themeMode},
                onSelectionChanged: (selection) =>
                    ref.read(themeModeControllerProvider.notifier).setThemeMode(selection.first),
              ),
            ),
            const SizedBox(height: 24),
            AgriButton(
              label: 'Log Out',
              variant: AgriButtonVariant.destructive,
              onPressed: () async {
                final confirmed = await showAgriDialog(
                  context,
                  title: 'Log out?',
                  message: "You'll need to log in again to access your account.",
                  confirmLabel: 'Log Out',
                  destructive: true,
                );
                if (confirmed == true) {
                  await ref.read(authControllerProvider.notifier).logout();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
