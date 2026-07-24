import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/agri_button.dart';
import '../../../core/widgets/agri_card.dart';

/// Checklist 1.3: stub screen is acceptable until the backend defines the
/// OTP/password-reset contract.
class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Forgot password')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            AgriCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lock_reset_rounded,
                    size: 40,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Password reset is coming soon',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'The backend team has not confirmed the OTP reset contract yet. For now, use the login screen or contact support.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            AgriButton(
              label: 'Back to login',
              onPressed: () => context.go('/login'),
            ),
          ],
        ),
      ),
    );
  }
}
