import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../data/auth_repository.dart';
import 'widgets/auth_visuals.dart';

/// Two-step reset: request a reset token by email, then submit the token
/// (received out-of-band) with a new password. Both steps hit the real
/// /auth/forgot-password and /auth/reset-password endpoints.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _tokenController = TextEditingController();
  final _newPasswordController = TextEditingController();
  bool _requested = false;
  bool _submitting = false;
  String? _message;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _tokenController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  Future<void> _requestReset() async {
    if (_emailController.text.trim().isEmpty) {
      setState(() => _error = 'Enter your email.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final message = await ref.read(authRepositoryProvider).forgotPassword(_emailController.text.trim());
      if (!mounted) return;
      setState(() {
        _requested = true;
        _message = message;
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _submitReset() async {
    if (_tokenController.text.trim().isEmpty || _newPasswordController.text.length < 8) {
      setState(() => _error = 'Enter the reset code and a password of at least 8 characters.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).resetPassword(
            token: _tokenController.text.trim(),
            newPassword: _newPasswordController.text,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset. Please log in with your new password.')),
      );
      context.go('/login');
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          AmbientBackground(colorScheme: colorScheme),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      AuthBackButton(colorScheme: colorScheme, onPressed: () => context.pop()),
                      Expanded(
                        child: Text(
                          'Reset Password',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: colorScheme.onSurface, fontSize: 19, fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(width: 40),
                    ],
                  ),
                  const SizedBox(height: 20),
                  AuthGlassCard(
                    colorScheme: colorScheme,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!_requested) ...[
                          Text(
                            'Enter your email and we\'ll generate a reset code.',
                            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13.5, height: 1.4),
                          ),
                          const SizedBox(height: 18),
                          AuthFieldLabel('Email', colorScheme),
                          const SizedBox(height: 8),
                          AuthTextField(
                            controller: _emailController,
                            hint: 'you@example.com',
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            colorScheme: colorScheme,
                          ),
                        ] else ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              _message ?? '',
                              style: TextStyle(color: colorScheme.onSurface, fontSize: 13, height: 1.4),
                            ),
                          ),
                          const SizedBox(height: 18),
                          AuthFieldLabel('Reset Code', colorScheme),
                          const SizedBox(height: 8),
                          AuthTextField(
                            controller: _tokenController,
                            hint: 'Code from email',
                            icon: Icons.confirmation_number_outlined,
                            colorScheme: colorScheme,
                          ),
                          const SizedBox(height: 16),
                          AuthFieldLabel('New Password', colorScheme),
                          const SizedBox(height: 8),
                          AuthTextField(
                            controller: _newPasswordController,
                            hint: 'At least 8 characters',
                            icon: Icons.lock_outline_rounded,
                            obscureText: true,
                            colorScheme: colorScheme,
                          ),
                        ],
                        if (_error != null) ...[
                          const SizedBox(height: 14),
                          Text(_error!, style: TextStyle(color: colorScheme.error, fontSize: 13, fontWeight: FontWeight.w600)),
                        ],
                        const SizedBox(height: 20),
                        AuthPillButton(
                          label: _submitting ? 'Please wait...' : (_requested ? 'Reset Password' : 'Send Reset Code'),
                          loading: _submitting,
                          onPressed: _requested ? _submitReset : _requestReset,
                          colorScheme: colorScheme,
                        ),
                        if (_requested) ...[
                          const SizedBox(height: 12),
                          Center(
                            child: TextButton(
                              onPressed: () => setState(() {
                                _requested = false;
                                _error = null;
                              }),
                              child: Text(
                                'Use a different email',
                                style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w600, fontSize: 12.5),
                              ),
                            ),
                          ),
                        ],
                      ],
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
