import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/agri_button.dart';
import '../application/auth_controller.dart';

/// Checklist 1.4: no access to core features until an Admin approves the
/// account. Real verification is push/poll-driven (Phase 10/9, not yet
/// built) — the debug approve action stands in for that so the flow can be
/// demonstrated end to end.
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
                if (kDebugMode) ...[
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => ref.read(authControllerProvider.notifier).debugApprove(),
                    child: const Text('(Debug) Simulate approval'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
