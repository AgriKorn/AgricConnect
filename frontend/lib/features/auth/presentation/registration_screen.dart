import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/agri_toast.dart';
import '../../../core/widgets/theme_toggle_button.dart';
import '../application/auth_controller.dart';
import '../application/session_state.dart';
import '../data/models/register_request.dart';
import '../data/models/user_role.dart';
import 'widgets/auth_visuals.dart';

const _markAsset = 'assets/images/agri_mark.png';

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
  final _emailController = TextEditingController();
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
  bool _agreedToTerms = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
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
    if (!_agreedToTerms) {
      showAgriToast(
        context,
        'Please agree to the Terms of Service and Privacy Policy',
        icon: Icons.error_outline_rounded,
        isError: true,
      );
      return;
    }
    ref
        .read(authControllerProvider.notifier)
        .register(
          RegisterRequest(
            role: widget.role,
            name: _nameController.text.trim(),
            email: _emailController.text.trim(),
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

    ref.listen(authControllerProvider, (previous, next) {
      if (next.errorMessage != null &&
          next.errorMessage != previous?.errorMessage) {
        showAgriToast(context, next.errorMessage!, icon: Icons.error_outline_rounded, isError: true);
      }
      // Registration success: show dialog then navigate to login
      if (next.successMessage != null &&
          next.successMessage != previous?.successMessage) {
        if (next.status == AuthStatus.unauthenticated) {
          // Buyer: auto-approved, direct to login
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => AlertDialog(
              title: const Text('Account Created! 🎉'),
              content: Text(next.successMessage!),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.go('/login');
                  },
                  child: const Text('Go to Login'),
                ),
              ],
            ),
          );
        }
        // For farmers/drivers (pendingVerification), the router's redirect
        // guard will automatically navigate to /pending-verification.
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
                    Row(
                      children: [
                        AuthBackButton(colorScheme: colorScheme, onPressed: () => context.pop()),
                        const Spacer(),
                        const ThemeToggleButton(),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Image.asset(_markAsset, height: 40, fit: BoxFit.contain),
                    const SizedBox(height: 14),
                    Text(
                      'Create Account',
                      style: TextStyle(color: colorScheme.onSurface, fontSize: 28, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Fill in your details to join the agricultural marketplace as a ${widget.role.label.toLowerCase()}.',
                      style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14.5, height: 1.4),
                    ),
                    const SizedBox(height: 24),
                    AuthGlassCard(
                      colorScheme: colorScheme,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Account Details',
                            style: TextStyle(color: colorScheme.onSurface, fontSize: 19, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 18),
                          _Field(
                            label: 'Full Name',
                            controller: _nameController,
                            hint: 'Enter your name',
                            icon: Icons.person_outline_rounded,
                            colorScheme: colorScheme,
                          ),
                          _Field(
                            label: 'Email',
                            controller: _emailController,
                            hint: 'Enter your email',
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            colorScheme: colorScheme,
                            validator: (value) {
                              final email = value?.trim() ?? '';
                              if (email.isEmpty) return 'Enter your email';
                              if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                                return 'Enter a valid email';
                              }
                              return null;
                            },
                          ),
                          _Field(
                            label: 'Phone Number',
                            controller: _phoneController,
                            hint: '+233 00 000 0000',
                            icon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                            colorScheme: colorScheme,
                            validator: (value) {
                              final phone = value?.trim().replaceAll(RegExp(r'\s+'), '') ?? '';
                              if (phone.isEmpty) return 'Enter your phone number';
                              // Mirrors the backend's normalizePhone + phoneSchema: accepts
                              // 0XXXXXXXXX, 233XXXXXXXXX, or +233XXXXXXXXX before rejecting —
                              // a looser client check here just means the server has the
                              // final say on a phone number that looks fine but isn't.
                              final isValidGhanaPhone = RegExp(r'^(0\d{9}|233\d{9}|\+233\d{9})$').hasMatch(phone);
                              if (!isValidGhanaPhone) {
                                return 'Enter a valid Ghana phone number (e.g. 024 123 4567)';
                              }
                              return null;
                            },
                          ),
                          if (widget.role == UserRole.farmer)
                            _Field(
                              label: 'Region / District',
                              controller: _regionController,
                              hint: 'e.g. Ashanti, Kumasi',
                              icon: Icons.location_on_outlined,
                              colorScheme: colorScheme,
                            ),
                          if (widget.role == UserRole.buyer) ...[
                            _Field(
                              label: 'Business name (optional)',
                              controller: _businessNameController,
                              hint: 'Enter your business name',
                              icon: Icons.storefront_outlined,
                              colorScheme: colorScheme,
                              required: false,
                            ),
                            _Field(
                              label: 'Business type',
                              controller: _businessTypeController,
                              hint: 'e.g. Wholesaler, Retailer',
                              icon: Icons.category_outlined,
                              colorScheme: colorScheme,
                            ),
                          ],
                          if (widget.role == UserRole.driver) ...[
                            _Field(
                              label: 'Vehicle capacity',
                              controller: _vehicleCapacityController,
                              hint: 'e.g. 2 tonnes',
                              icon: Icons.local_shipping_outlined,
                              colorScheme: colorScheme,
                            ),
                            _Field(
                              label: 'Operating region',
                              controller: _operatingRegionController,
                              hint: 'e.g. Greater Accra',
                              icon: Icons.map_outlined,
                              colorScheme: colorScheme,
                            ),
                          ],
                          _Field(
                            label: 'Password',
                            controller: _passwordController,
                            hint: 'Create a password',
                            icon: Icons.lock_outline_rounded,
                            obscureText: _obscurePassword,
                            colorScheme: colorScheme,
                            onToggleObscure: () =>
                                setState(() => _obscurePassword = !_obscurePassword),
                            validator: (value) => (value == null || value.length < 8)
                                ? 'At least 8 characters'
                                : null,
                          ),
                          _Field(
                            label: 'Confirm password',
                            controller: _confirmPasswordController,
                            hint: 'Re-enter your password',
                            icon: Icons.lock_outline_rounded,
                            obscureText: _obscureConfirmPassword,
                            colorScheme: colorScheme,
                            onToggleObscure: () => setState(
                              () => _obscureConfirmPassword = !_obscureConfirmPassword,
                            ),
                            validator: (value) => value != _passwordController.text
                                ? 'Passwords do not match'
                                : null,
                          ),
                          const SizedBox(height: 4),
                          _TermsCheckbox(
                            colorScheme: colorScheme,
                            value: _agreedToTerms,
                            onChanged: () => setState(() => _agreedToTerms = !_agreedToTerms),
                          ),
                          const SizedBox(height: 18),
                          AuthPillButton(
                            label: 'Create Account',
                            loading: session.isSubmitting,
                            onPressed: _submit,
                            colorScheme: colorScheme,
                          ),
                          const SizedBox(height: 18),
                          AuthOrDivider(colorScheme: colorScheme),
                          const SizedBox(height: 18),
                          AuthGoogleButton(
                            loading: session.isSubmitting,
                            colorScheme: colorScheme,
                            onPressed: () => ref
                                .read(authControllerProvider.notifier)
                                .loginWithGoogle(role: widget.role),
                          ),
                          const SizedBox(height: 18),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  'Already have an account? ',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                                ),
                              ),
                              GestureDetector(
                                onTap: () => context.pop(),
                                child: Text(
                                  'Log In',
                                  style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
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
    this.icon,
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
  final IconData? icon;
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
            icon: icon,
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

class _TermsCheckbox extends StatelessWidget {
  const _TermsCheckbox({required this.colorScheme, required this.value, required this.onChanged});

  final ColorScheme colorScheme;
  final bool value;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onChanged,
      behavior: HitTestBehavior.opaque,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: value ? colorScheme.primary : Colors.transparent,
              border: value ? null : Border.all(color: colorScheme.outline.withValues(alpha: 0.9)),
            ),
            child: value ? Icon(Icons.check_rounded, color: colorScheme.onPrimary, size: 16) : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'I agree to the Terms of Service and Privacy Policy',
              style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
