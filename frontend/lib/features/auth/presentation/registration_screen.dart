import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/auth_controller.dart';
import '../data/models/register_request.dart';
import '../data/models/user_role.dart';
import 'widgets/auth_visuals.dart';

/// Checklist 1.2: shared fields for every role, plus fields specific to
/// [role]. Client-side validation before submit; submit disabled in-flight.
/// Shares its visual language (widgets/auth_visuals.dart) with login and
/// role selection.
class RegistrationScreen extends ConsumerStatefulWidget {
  const RegistrationScreen({super.key, required this.role});

  final UserRole role;

  @override
  ConsumerState<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends ConsumerState<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _regionController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _businessTypeController = TextEditingController();
  final _vehicleCapacityController = TextEditingController();
  final _operatingRegionController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _regionController.dispose();
    _businessNameController.dispose();
    _businessTypeController.dispose();
    _vehicleCapacityController.dispose();
    _operatingRegionController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    ref
        .read(authControllerProvider.notifier)
        .register(
          RegisterRequest(
            role: widget.role,
            name: _nameController.text.trim(),
            phone: _phoneController.text.trim(),
            password: _passwordController.text,
            region: widget.role == UserRole.farmer
                ? _regionController.text.trim()
                : null,
            businessName: widget.role == UserRole.buyer
                ? _businessNameController.text.trim()
                : null,
            businessType: widget.role == UserRole.buyer
                ? _businessTypeController.text.trim()
                : null,
            vehicleCapacity: widget.role == UserRole.driver
                ? _vehicleCapacityController.text.trim()
                : null,
            operatingRegion: widget.role == UserRole.driver
                ? _operatingRegionController.text.trim()
                : null,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authControllerProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final accent = widget.role.colorOf(colorScheme);

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
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AuthBackButton(colorScheme: colorScheme, onPressed: () => context.pop()),
                    const SizedBox(height: 20),
                    Text(
                      'Sign up as ${widget.role.label}',
                      style: TextStyle(color: colorScheme.onSurface, fontSize: 24, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(widget.role.icon, size: 16, color: accent),
                          const SizedBox(width: 6),
                          Text(
                            widget.role.label,
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: accent),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    AuthGlassCard(
                      colorScheme: colorScheme,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _Field(
                            label: 'Full name',
                            controller: _nameController,
                            hint: 'Enter your full name',
                            colorScheme: colorScheme,
                          ),
                          _Field(
                            label: 'Phone number',
                            controller: _phoneController,
                            hint: '024 000 0000',
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
                          if (widget.role == UserRole.farmer)
                            _Field(
                              label: 'Region / District',
                              controller: _regionController,
                              hint: 'e.g. Ashanti, Kumasi',
                              colorScheme: colorScheme,
                            ),
                          if (widget.role == UserRole.buyer) ...[
                            _Field(
                              label: 'Business name (optional)',
                              controller: _businessNameController,
                              hint: 'Enter your business name',
                              colorScheme: colorScheme,
                              required: false,
                            ),
                            _Field(
                              label: 'Business type',
                              controller: _businessTypeController,
                              hint: 'e.g. Wholesaler, Retailer',
                              colorScheme: colorScheme,
                            ),
                          ],
                          if (widget.role == UserRole.driver) ...[
                            _Field(
                              label: 'Vehicle capacity',
                              controller: _vehicleCapacityController,
                              hint: 'e.g. 2 tonnes',
                              colorScheme: colorScheme,
                            ),
                            _Field(
                              label: 'Operating region',
                              controller: _operatingRegionController,
                              hint: 'e.g. Greater Accra',
                              colorScheme: colorScheme,
                            ),
                          ],
                          _Field(
                            label: 'Password',
                            controller: _passwordController,
                            hint: 'Create a password',
                            obscureText: _obscurePassword,
                            colorScheme: colorScheme,
                            onToggleObscure: () =>
                                setState(() => _obscurePassword = !_obscurePassword),
                            validator: (value) => (value == null || value.length < 6)
                                ? 'At least 6 characters'
                                : null,
                          ),
                          _Field(
                            label: 'Confirm password',
                            controller: _confirmPasswordController,
                            hint: 'Re-enter your password',
                            obscureText: _obscureConfirmPassword,
                            colorScheme: colorScheme,
                            onToggleObscure: () => setState(
                              () => _obscureConfirmPassword = !_obscureConfirmPassword,
                            ),
                            validator: (value) => value != _passwordController.text
                                ? 'Passwords do not match'
                                : null,
                          ),
                          const SizedBox(height: 6),
                          AuthPillButton(
                            label: 'Create Account',
                            loading: session.isSubmitting,
                            onPressed: _submit,
                            colorScheme: colorScheme,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
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

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    required this.hint,
    required this.colorScheme,
    this.keyboardType,
    this.obscureText = false,
    this.onToggleObscure,
    this.validator,
    this.required = true,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final ColorScheme colorScheme;
  final TextInputType? keyboardType;
  final bool obscureText;
  final VoidCallback? onToggleObscure;
  final String? Function(String?)? validator;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AuthFieldLabel(label, colorScheme),
          const SizedBox(height: 8),
          AuthTextField(
            controller: controller,
            hint: hint,
            colorScheme: colorScheme,
            keyboardType: keyboardType,
            obscureText: obscureText,
            suffixIcon: onToggleObscure == null
                ? null
                : IconButton(
                    icon: Icon(
                      obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    onPressed: onToggleObscure,
                  ),
            validator:
                validator ??
                (required
                    ? (value) => (value == null || value.trim().isEmpty)
                          ? 'This field is required'
                          : null
                    : null),
          ),
        ],
      ),
    );
  }
}
