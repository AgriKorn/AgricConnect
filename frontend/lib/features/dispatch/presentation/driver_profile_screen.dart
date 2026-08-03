import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/utils/currency.dart';
import '../../../core/widgets/agri_bottom_sheet.dart';
import '../../../core/widgets/agri_dialog.dart';
import '../../../core/widgets/agri_toast.dart';
import '../../../core/widgets/coming_soon_screen.dart';
import '../../../core/widgets/help_support_screen.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/data/auth_repository.dart';
import '../application/dispatch_providers.dart';
import '../data/driver_profile_mock.dart';

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

void _openDriverHelp(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => HelpSupportScreen(
        roleLabel: 'Drivers',
        heroSubtitle:
            'Our AI assistant and support team are ready to assist you with your delivery and logistics needs.',
        contactMethods: const [
          HelpContactMethod(icon: Icons.chat_bubble_outline_rounded, label: 'Live Chat', detail: 'Chat with our support team'),
          HelpContactMethod(icon: Icons.call_rounded, label: 'Call Dispatch Support', detail: '+233 30 123 4567'),
          HelpContactMethod(icon: Icons.email_outlined, label: 'Email Us', detail: 'support@agriconnect.com'),
        ],
        faqItems: const [
          'How do I accept or decline a job?',
          "What happens if I'm delayed on a delivery?",
          'How is my payout calculated?',
          'How do I update my vehicle details?',
        ],
        resourceLinks: const [
          HelpResourceLink(icon: Icons.description_outlined, label: 'Terms of Service'),
          HelpResourceLink(icon: Icons.verified_user_outlined, label: 'Privacy Policy'),
          HelpResourceLink(icon: Icons.shield_outlined, label: 'Driver Safety Guidelines'),
        ],
      ),
    ),
  );
}

/// Driver-specific Profile tab: hero (verified badge/deliveries/earnings —
/// all real), Vehicle Details, Verified Documents, and Account Settings
/// (notifications, help, sign out). Vehicle details and document
/// verification have no backing system in the backend yet (no vehicle
/// registration or document upload flow exists), so both route to a
/// "coming soon" state instead of showing invented values — same as
/// Language, which was already honest about not being wired up.
class DriverProfileScreen extends ConsumerWidget {
  const DriverProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final details = ref.watch(driverProfileDetailsProvider);
    final notificationsOn = ref.watch(driverNotificationsProvider).valueOrNull ?? true;

    return Scaffold(
      body: ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              _ProfileHero(colorScheme: colorScheme, details: details),
              const SizedBox(height: 40),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vehicle Details',
                      style: TextStyle(color: colorScheme.onSurface, fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    _InfoCard(
                      colorScheme: colorScheme,
                      children: [
                        _ActionRow(
                          colorScheme: colorScheme,
                          label: 'Add your vehicle details',
                          onTap: () => _openComingSoon(context, 'Vehicle Details', Icons.local_shipping_outlined),
                          isLast: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Verified Documents',
                      style: TextStyle(color: colorScheme.onSurface, fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    _InfoCard(
                      colorScheme: colorScheme,
                      children: [
                        _ActionRow(
                          colorScheme: colorScheme,
                          label: 'Upload verification documents',
                          onTap: () => _openComingSoon(context, 'Document Verification', Icons.description_outlined),
                          isLast: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Account Settings',
                      style: TextStyle(color: colorScheme.onSurface, fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    _InfoCard(
                      colorScheme: colorScheme,
                      children: [
                        _SettingsRow(
                          colorScheme: colorScheme,
                          icon: Icons.language_rounded,
                          label: 'Language',
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'English',
                                style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w700, fontSize: 14),
                              ),
                              Icon(Icons.chevron_right_rounded, color: colorScheme.onSurfaceVariant),
                            ],
                          ),
                          onTap: () => _openComingSoon(context, 'Language', Icons.language_rounded),
                        ),
                        _SettingsRow(
                          colorScheme: colorScheme,
                          icon: Icons.notifications_none_rounded,
                          label: 'Notifications',
                          trailing: Switch(
                            value: notificationsOn,
                            activeThumbColor: colorScheme.primary,
                            onChanged: (_) => ref.read(driverNotificationsProvider.notifier).toggle(),
                          ),
                        ),
                        _SettingsRow(
                          colorScheme: colorScheme,
                          icon: Icons.help_outline_rounded,
                          label: 'Help & Support',
                          trailing: Icon(Icons.chevron_right_rounded, color: colorScheme.onSurfaceVariant),
                          onTap: () => _openDriverHelp(context),
                        ),
                        _SignOutRow(colorScheme: colorScheme),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileHero extends ConsumerStatefulWidget {
  const _ProfileHero({required this.colorScheme, required this.details});

  final ColorScheme colorScheme;
  final DriverProfileDetails details;

  @override
  ConsumerState<_ProfileHero> createState() => _ProfileHeroState();
}

class _ProfileHeroState extends ConsumerState<_ProfileHero> {
  final _imagePicker = ImagePicker();
  bool _uploadingPhoto = false;

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

  @override
  Widget build(BuildContext context) {
    final colorScheme = widget.colorScheme;
    final details = widget.details;
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomCenter,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 52),
          decoration: BoxDecoration(
            color: colorScheme.primary,
            borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(36), bottomRight: Radius.circular(36)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (details.verified)
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: colorScheme.onPrimary.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        border: Border.all(color: colorScheme.onPrimary.withValues(alpha: 0.4)),
                      ),
                      child: Icon(Icons.check_rounded, color: colorScheme.onPrimary, size: 18),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: _uploadingPhoto ? null : _changePhoto,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    SizedBox(
                      width: 112,
                      height: 112,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: colorScheme.onPrimary.withValues(alpha: 0.3), width: 3),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(3),
                          child: ClipOval(child: UserAvatar(size: 100)),
                        ),
                      ),
                    ),
                    if (_uploadingPhoto)
                      const Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
                          child: Center(child: CircularProgressIndicator(color: Colors.white)),
                        ),
                      ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.25),
                          shape: BoxShape.circle,
                          border: Border.all(color: colorScheme.primary, width: 2),
                        ),
                        child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 15),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                details.name,
                style: TextStyle(color: colorScheme.onPrimary, fontSize: 24, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  details.verified ? 'Verified Driver' : 'AgriConnect Driver',
                  style: TextStyle(color: colorScheme.onPrimary, fontWeight: FontWeight.w700, fontSize: 13.5),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          bottom: -34,
          left: 20,
          right: 20,
          child: Row(
            children: [
              Expanded(
                child: _StatPill(
                  colorScheme: colorScheme,
                  value: '${details.deliveriesCount}',
                  label: 'Deliveries',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatPill(
                  colorScheme: colorScheme,
                  value: formatGhs(details.totalEarnings),
                  label: 'Earnings',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.colorScheme, required this.value, required this.label});

  final ColorScheme colorScheme;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(width: 14, height: 14, decoration: BoxDecoration(color: colorScheme.primary, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w800, fontSize: 16),
                ),
                Text(label, style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 11.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.colorScheme, required this.children});

  final ColorScheme colorScheme;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.colorScheme,
    required this.label,
    required this.onTap,
    this.isLast = false,
  });

  final ColorScheme colorScheme;
  final String label;
  final VoidCallback onTap;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          border: isLast ? null : Border(bottom: BorderSide(color: colorScheme.outline.withValues(alpha: 0.15))),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(label, style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w700, fontSize: 15)),
            ),
            Icon(Icons.add_rounded, color: colorScheme.onSurfaceVariant, size: 20),
          ],
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.colorScheme,
    required this.icon,
    required this.label,
    required this.trailing,
    this.onTap,
  });

  final ColorScheme colorScheme;
  final IconData icon;
  final String label;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colorScheme.outline.withValues(alpha: 0.15))),
        ),
        child: Row(
          children: [
            Icon(icon, color: colorScheme.onSurfaceVariant, size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label, style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w700, fontSize: 15)),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}

class _SignOutRow extends ConsumerWidget {
  const _SignOutRow({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () async {
        final confirmed = await showAgriDialog(
          context,
          title: 'Sign out?',
          message: "You'll need to log in again to access your account.",
          confirmLabel: 'Sign Out',
          destructive: true,
        );
        if (confirmed == true) {
          await ref.read(authControllerProvider.notifier).logout();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(Icons.logout_rounded, color: colorScheme.error, size: 20),
            const SizedBox(width: 14),
            Text('Sign Out', style: TextStyle(color: colorScheme.error, fontWeight: FontWeight.w700, fontSize: 15)),
          ],
        ),
      ),
    );
  }
}
