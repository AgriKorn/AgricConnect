import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/presentation/widgets/auth_visuals.dart';
import 'agri_dialog.dart';
import 'agri_toast.dart';
import 'coming_soon_screen.dart';

void _openComingSoon(BuildContext context, String title, IconData icon) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => ComingSoonScreen(
        title: title,
        icon: icon,
        message: '$title will be available in a future update.',
      ),
    ),
  );
}

/// Shared Edit Profile screen (same reuse pattern as [AccountSettingsScreen]
/// / [HelpSupportScreen]) — identity fields (name/phone/email) persist for
/// real via [AuthController.updateProfile]; location/bio are role-flavored
/// copy over the same mechanism. There's no `PATCH /users/me` endpoint yet
/// (checklist Phase 1 callout), so this is the full extent of what "saving"
/// can mean right now.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({
    super.key,
    required this.avatarBuilder,
    required this.locationLabel,
    required this.locationHint,
    required this.bioHint,
    required this.verifiedSubtitle,
  });

  final Widget Function(double size) avatarBuilder;
  final String locationLabel;
  final String locationHint;
  final String bioHint;
  final String verifiedSubtitle;

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _locationController;
  late final TextEditingController _bioController;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authControllerProvider).user;
    _nameController = TextEditingController(text: user?.name ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _locationController = TextEditingController(text: user?.region ?? '');
    _bioController = TextEditingController(text: user?.bio ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _locationController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    await ref.read(authControllerProvider.notifier).updateProfile(
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          email: _emailController.text.trim(),
          region: _locationController.text.trim().isEmpty ? null : _locationController.text.trim(),
          bio: _bioController.text.trim().isEmpty ? null : _bioController.text.trim(),
        );

    if (!mounted) return;
    showAgriToast(context, 'Profile updated');
    Navigator.of(context).pop();
  }

  Future<void> _deleteAccountData(BuildContext context) async {
    final confirmed = await showAgriDialog(
      context,
      title: 'Delete account data?',
      message: "This permanently removes your profile information. This can't be undone.",
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (confirmed == true && context.mounted) {
      _openComingSoon(context, 'Delete Account', Icons.delete_outline_rounded);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final verified = ref.watch(authControllerProvider).user?.status.name == 'verified';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              Row(
                children: [
                  _CircleIconButton(
                    colorScheme: colorScheme,
                    icon: Icons.close_rounded,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Text(
                      'Edit Profile',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colorScheme.onSurface, fontSize: 21, fontWeight: FontWeight.w800),
                    ),
                  ),
                  SizedBox(
                    height: 40,
                    child: FilledButton(
                      onPressed: _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                      ),
                      child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    SizedBox(width: 132, height: 132, child: widget.avatarBuilder(132)),
                    Positioned(
                      right: -4,
                      bottom: -4,
                      child: GestureDetector(
                        onTap: () => _openComingSoon(context, 'Change Profile Photo', Icons.camera_alt_outlined),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 3),
                          ),
                          child: Icon(Icons.camera_alt_rounded, color: colorScheme.onPrimary, size: 18),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Center(
                child: GestureDetector(
                  onTap: () => _openComingSoon(context, 'Change Profile Photo', Icons.camera_alt_outlined),
                  child: Text(
                    'Change Profile Photo',
                    style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w700, fontSize: 14.5),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              AuthFieldLabel('Full Name', colorScheme),
              const SizedBox(height: 8),
              AuthTextField(
                controller: _nameController,
                hint: 'Enter your name',
                icon: Icons.person_outline_rounded,
                colorScheme: colorScheme,
                validator: (value) => (value == null || value.trim().isEmpty) ? 'Enter your name' : null,
              ),
              const SizedBox(height: 18),
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
                  if (!RegExp(r'^[0-9+]{9,15}$').hasMatch(phone)) return 'Enter a valid phone number';
                  return null;
                },
              ),
              const SizedBox(height: 18),
              AuthFieldLabel('Email Address', colorScheme),
              const SizedBox(height: 8),
              AuthTextField(
                controller: _emailController,
                hint: 'Enter your email',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                colorScheme: colorScheme,
                validator: (value) {
                  final email = value?.trim() ?? '';
                  if (email.isEmpty) return 'Enter your email';
                  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) return 'Enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: 18),
              AuthFieldLabel(widget.locationLabel, colorScheme),
              const SizedBox(height: 8),
              AuthTextField(
                controller: _locationController,
                hint: widget.locationHint,
                icon: Icons.location_on_outlined,
                colorScheme: colorScheme,
                suffixIcon: Icon(Icons.map_outlined, color: colorScheme.onSurfaceVariant, size: 20),
              ),
              const SizedBox(height: 18),
              AuthFieldLabel('Bio', colorScheme),
              const SizedBox(height: 8),
              _BioField(controller: _bioController, hint: widget.bioHint, colorScheme: colorScheme),
              const SizedBox(height: 24),
              if (verified)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: colorScheme.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.verified_user_rounded, color: colorScheme.primary, size: 22),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Identity Verified',
                              style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w800, fontSize: 15.5),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.verifiedSubtitle,
                              style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13, height: 1.35),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 28),
              SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: () => _deleteAccountData(context),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: colorScheme.error.withValues(alpha: 0.12),
                    foregroundColor: colorScheme.error,
                    side: BorderSide(color: colorScheme.error.withValues(alpha: 0.4)),
                    shape: const StadiumBorder(),
                  ),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('Delete Account Data', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BioField extends StatelessWidget {
  const _BioField({required this.controller, required this.hint, required this.colorScheme});

  final TextEditingController controller;
  final String hint;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: 3,
      minLines: 3,
      style: TextStyle(color: colorScheme.onSurface),
      decoration: InputDecoration(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        hintText: hint,
        hintStyle: TextStyle(color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
        alignLabelWithHint: true,
        prefixIcon: Padding(
          padding: const EdgeInsets.only(bottom: 40),
          child: Icon(Icons.description_outlined, color: colorScheme.primary, size: 20),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      ),
    );
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
