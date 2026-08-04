import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/currency.dart';
import '../../../core/widgets/coming_soon_screen.dart';
import '../../../core/widgets/help_support_screen.dart';
import '../../auth/application/auth_controller.dart';
import '../../../core/widgets/agri_dialog.dart';
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
          HelpContactMethod(icon: Icons.call_rounded, label: 'Call Dispatch Support', detail: '0597741107'),
          HelpContactMethod(icon: Icons.email_outlined, label: 'Email Us', detail: 'addosakah@gmail.com'),
        ],
        faqItems: const [
          HelpFaqItem(
            question: 'How do I accept or decline a job?',
            answer:
                'New job requests appear as a pop-up with pickup and drop-off details. Tap Accept to claim it or Decline to pass it to the next available driver — you have a short window to respond before it\'s reassigned.',
          ),
          HelpFaqItem(
            question: "What happens if I'm delayed on a delivery?",
            answer:
                'Update your status in the app as soon as you know you\'ll be late so the buyer and dispatch are notified automatically. Significant delays should also be reported to Dispatch Support.',
          ),
          HelpFaqItem(
            question: 'How is my payout calculated?',
            answer: 'Payouts are based on distance, delivery time, and any applicable bonuses, calculated automatically per completed job and added to your weekly settlement.',
          ),
          HelpFaqItem(
            question: 'How do I update my vehicle details?',
            answer: 'Go to your Profile, select Vehicle Information, and edit your vehicle type, plate number, or capacity. Changes are reviewed before they take effect.',
          ),
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

String _initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  final first = parts.first[0];
  final last = parts.length > 1 ? parts.last[0] : '';
  return (first + last).toUpperCase();
}

/// Driver-specific Profile tab: hero (rating/deliveries), On-Time/Earnings
/// stats, Vehicle Details, Verified Documents, and Account Settings
/// (language, notifications, sign out). Farmer/Buyer still use their own
/// profile screens — this one replicates the driver-specific reference.
class DriverProfileScreen extends ConsumerWidget {
  const DriverProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final details = ref.watch(driverProfileDetailsProvider);
    final notificationsOn = ref.watch(driverNotificationsProvider);

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
                    _VehicleCard(colorScheme: colorScheme, vehicle: details.vehicle),
                    const SizedBox(height: 28),
                    Text(
                      'Verified Documents',
                      style: TextStyle(color: colorScheme.onSurface, fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    _InfoCard(
                      colorScheme: colorScheme,
                      children: [
                        for (var i = 0; i < details.documents.length; i++)
                          _ActionRow(
                            colorScheme: colorScheme,
                            label: details.documents[i],
                            onTap: () => _openComingSoon(context, details.documents[i], Icons.description_outlined),
                            isLast: i == details.documents.length - 1,
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

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.colorScheme, required this.details});

  final ColorScheme colorScheme;
  final DriverProfileDetails details;

  @override
  Widget build(BuildContext context) {
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
              CircleAvatar(
                radius: 56,
                backgroundColor: colorScheme.onPrimary.withValues(alpha: 0.2),
                child: Text(
                  _initialsOf(details.name),
                  style: TextStyle(color: colorScheme.onPrimary, fontWeight: FontWeight.w800, fontSize: 34),
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
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_rounded, color: Color(0xFFFFC107), size: 16),
                    const SizedBox(width: 6),
                    Text(
                      '${details.rating.toStringAsFixed(1)} (${details.deliveriesCount} deliveries)',
                      style: TextStyle(color: colorScheme.onPrimary, fontWeight: FontWeight.w700, fontSize: 13.5),
                    ),
                  ],
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
                  value: '${details.onTimePercent}%',
                  label: 'On-Time',
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

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({required this.colorScheme, required this.vehicle});

  final ColorScheme colorScheme;
  final DriverVehicle vehicle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.local_shipping_rounded, color: colorScheme.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vehicle.model,
                  style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w800, fontSize: 15.5),
                ),
                const SizedBox(height: 2),
                Text(
                  '${vehicle.category} • ${vehicle.capacityTons} Tons',
                  style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colorScheme.outline.withValues(alpha: 0.3)),
            ),
            child: Text(
              vehicle.plateNumber,
              style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w700, fontSize: 12.5),
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
