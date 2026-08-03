import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/presentation/widgets/auth_visuals.dart';
import '../network/api_exception.dart';
import 'agri_bottom_sheet.dart';
import 'agri_dialog.dart';
import 'agri_toast.dart';
import 'coming_soon_screen.dart';
import 'user_avatar.dart';

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
/// / [HelpSupportScreen]). Name and location save for real via
/// [AuthController.updateProfile] -> PATCH /users/profile. Phone and email
/// are shown read-only: changing your login email needs its own verified
/// flow, not a plain text field, so there's nothing to wire up here yet —
/// showing them as editable without persisting them was the actual bug.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({
    super.key,
    required this.locationLabel,
    required this.locationHint,
    required this.verifiedSubtitle,
  });

  final String locationLabel;
  final String locationHint;
  final String verifiedSubtitle;

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _imagePicker = ImagePicker();
  late final TextEditingController _nameController;
  late final TextEditingController _locationController;
  late final String _phone;
  late final String _email;
  bool _saving = false;
  bool _uploadingPhoto = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authControllerProvider).user;
    _nameController = TextEditingController(text: user?.name ?? '');
    _locationController = TextEditingController(text: user?.region ?? '');
    _phone = user?.phone ?? '';
    _email = user?.email ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _changePhoto() async {
    final source = await showAgriBottomSheet<ImageSource>(
      context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Take a photo'),
            onTap: () => Navigator.of(context).pop(ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from gallery'),
            onTap: () => Navigator.of(context).pop(ImageSource.gallery),
          ),
        ],
      ),
    );
    if (source == null || !mounted) return;

    final picked = await _imagePicker.pickImage(source: source, maxWidth: 1024, imageQuality: 85);
    if (picked == null || !mounted) return;

    setState(() => _uploadingPhoto = true);
    try {
      final bytes = await picked.readAsBytes();
      final ext = picked.name.contains('.') ? picked.name.split('.').last.toLowerCase() : 'jpg';
      final contentType = ext == 'png' ? 'image/png' : 'image/jpeg';

      final publicUrl = await ref.read(authRepositoryProvider).uploadProfilePhoto(
            bytes: bytes,
            fileName: picked.name,
            contentType: contentType,
          );

      await ref.read(authControllerProvider.notifier).updatePhotoUrl(publicUrl);

      if (!mounted) return;
      showAgriToast(context, 'Profile photo updated');
    } on ApiException catch (e) {
      if (mounted) showAgriToast(context, e.message);
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await ref.read(authControllerProvider.notifier).updateProfile(
            name: _nameController.text.trim(),
            region: _locationController.text.trim(),
          );
      if (!mounted) return;
      showAgriToast(context, 'Profile updated');
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                      ),
                      child: _saving
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.onPrimary),
                            )
                          : const Text('Save', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const SizedBox(width: 132, height: 132, child: UserAvatar(size: 132)),
                    if (_uploadingPhoto)
                      const Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
                          child: Center(child: CircularProgressIndicator(color: Colors.white)),
                        ),
                      ),
                    Positioned(
                      right: -4,
                      bottom: -4,
                      child: GestureDetector(
                        onTap: _uploadingPhoto ? null : _changePhoto,
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
                  onTap: _uploadingPhoto ? null : _changePhoto,
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
              _ReadOnlyField(value: _phone, icon: Icons.phone_outlined, colorScheme: colorScheme),
              const SizedBox(height: 18),
              AuthFieldLabel('Email Address', colorScheme),
              const SizedBox(height: 8),
              _ReadOnlyField(value: _email, icon: Icons.email_outlined, colorScheme: colorScheme),
              const SizedBox(height: 6),
              Text(
                "Phone and email can't be changed here yet — contact support if either needs to change.",
                style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12, height: 1.3),
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
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    _error!,
                    style: TextStyle(color: colorScheme.onErrorContainer, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
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

/// Displays a field the backend has no endpoint to change yet, instead of
/// an editable box whose edits silently went nowhere.
class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({required this.value, required this.icon, required this.colorScheme});

  final String value;
  final IconData icon;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: colorScheme.onSurfaceVariant, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 15),
            ),
          ),
          Icon(Icons.lock_outline_rounded, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6), size: 16),
        ],
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
