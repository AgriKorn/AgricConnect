import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/motion.dart';
import '../../../core/widgets/theme_toggle_button.dart';
import '../application/auth_controller.dart';
import 'widgets/auth_visuals.dart';

const _markAsset = 'assets/images/agri_mark.png';

/// Checklist 1.3: phone number / password (Mobile Money-linked accounts use
/// phone as the primary identifier, not email). Styled fully off
/// [ColorScheme] tokens (not fixed hex, unlike the splash/onboarding
/// screens) so it renders correctly in both light and dark mode. Shares its
/// visual language (widgets/auth_visuals.dart) with role selection and
/// registration.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    ref
        .read(authControllerProvider.notifier)
        .login(
          phone: _phoneController.text.trim(),
          password: _passwordController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authControllerProvider);
    final isSubmitting = session.isSubmitting;
    final colorScheme = Theme.of(context).colorScheme;

    ref.listen(authControllerProvider, (previous, next) {
      if (next.errorMessage != null &&
          next.errorMessage != previous?.errorMessage) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(next.errorMessage!)));
      }
    });

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          AmbientBackground(colorScheme: colorScheme),
          Positioned(
            top: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 12, 20, 0),
                child: const ThemeToggleButton(),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _BrandHeader(colorScheme: colorScheme),
                    const SizedBox(height: 32),
                    AuthGlassCard(
                      colorScheme: colorScheme,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _AuthTabs(
                            colorScheme: colorScheme,
                            onSignUp: () => context.push('/role-selection'),
                          ),
                          const SizedBox(height: 22),
                          AuthFieldLabel('Phone Number', colorScheme),
                          const SizedBox(height: 8),
                          AuthTextField(
                            controller: _phoneController,
                            hint: '+233 00 000 0000',
                            icon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                            colorScheme: colorScheme,
                            validator: (value) {
                              final phone = value?.trim() ?? '';
                              if (phone.isEmpty) return 'Enter your phone number';
                              if (!RegExp(r'^[0-9+]{9,15}$').hasMatch(phone)) {
                                return 'Enter a valid phone number';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 18),
                          AuthFieldLabel('Password', colorScheme),
                          const SizedBox(height: 8),
                          AuthTextField(
                            controller: _passwordController,
                            hint: 'Enter your password',
                            icon: Icons.lock_outline_rounded,
                            obscureText: _obscurePassword,
                            colorScheme: colorScheme,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              onPressed: () =>
                                  setState(() => _obscurePassword = !_obscurePassword),
                            ),
                            validator: (value) => (value == null || value.isEmpty)
                                ? 'Enter your password'
                                : null,
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () => context.push('/forgot-password'),
                              child: Text(
                                'Forgot password?',
                                style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          AuthPillButton(
                            label: 'Log In',
                            loading: isSubmitting,
                            onPressed: _submit,
                            colorScheme: colorScheme,
                          ),
                          const SizedBox(height: 18),
                          AuthOrDivider(colorScheme: colorScheme),
                          const SizedBox(height: 18),
                          AuthGoogleButton(
                            loading: isSubmitting,
                            colorScheme: colorScheme,
                            onPressed: () => ref.read(authControllerProvider.notifier).loginWithGoogle(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don't have an account? ",
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                        GestureDetector(
                          onTap: () => context.push('/role-selection'),
                          child: Text(
                            'Create Account',
                            style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    if (kDebugMode) ...[
                      const SizedBox(height: 20),
                      Center(
                        child: TextButton(
                          onPressed: () => context.push('/debug/components'),
                          child: const Text('Component gallery (debug)'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: colorScheme.outline.withValues(alpha: 0.4)),
          ),
          child: Image.asset(_markAsset, fit: BoxFit.contain),
        ),
        const SizedBox(height: 14),
        Text(
          'AgriConnect',
          style: TextStyle(color: colorScheme.onSurface, fontSize: 24, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          'Fresh from farm to you',
          style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13.5),
        ),
      ],
    );
  }
}

class _AuthTabs extends StatelessWidget {
  const _AuthTabs({required this.colorScheme, required this.onSignUp});

  final ColorScheme colorScheme;
  final VoidCallback onSignUp;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Expanded(child: _AuthTab(label: 'Log In', active: true, colorScheme: colorScheme, onTap: () {})),
          Expanded(
            child: _AuthTab(label: 'Sign Up', active: false, colorScheme: colorScheme, onTap: onSignUp),
          ),
        ],
      ),
    );
  }
}

class _AuthTab extends StatelessWidget {
  const _AuthTab({
    required this.label,
    required this.active,
    required this.colorScheme,
    required this.onTap,
  });

  final String label;
  final bool active;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: kAgriConnectDuration,
        curve: kAgriConnectCurve,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? colorScheme.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          boxShadow: active
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, 2))]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: active ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
