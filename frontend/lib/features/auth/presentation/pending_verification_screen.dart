import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/agri_button.dart';
import '../application/auth_controller.dart';

/// Checklist 1.4: no access to core features until an Admin approves the
/// account via the real admin panel. There is no push notification for
/// approval yet, so the user finds out by logging back in — logging out and
/// back in re-checks status against the server.
class PendingVerificationScreen extends ConsumerWidget {
  const PendingVerificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final session = ref.watch(authControllerProvider);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: colorScheme.tertiaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.hourglass_top_rounded, color: colorScheme.onTertiaryContainer, size: 38),
                ),
                const SizedBox(height: 24),
                Text('Your account is under review', style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.center),
                const SizedBox(height: 10),
                Text(
                  "We're verifying your details${session.user != null ? ' for ${session.user!.name}' : ''}. "
                  "You'll get access as soon as it's approved.",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 32),
                AgriButton(
                  label: 'Log Out',
                  variant: AgriButtonVariant.secondary,
                  onPressed: () => ref.read(authControllerProvider.notifier).logout(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
