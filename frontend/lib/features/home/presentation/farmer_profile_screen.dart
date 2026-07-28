import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/theme_mode_controller.dart';
import '../../../core/utils/currency.dart';
import '../../../core/widgets/agri_dialog.dart';
import '../../../core/widgets/coming_soon_screen.dart';
import '../../../core/widgets/help_support_screen.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/data/models/account_status.dart';
import '../../auth/data/models/user_model.dart';
import '../application/farmer_dashboard_providers.dart';
import '../data/farmer_dashboard_mock.dart';

const _heroImage = 'assets/images/farmer_hero.jpeg';

// Rec. 709 luma weights — desaturates the hero photo for the avatar so it
// reads as the reference's black & white portrait without a second asset.
const _grayscaleMatrix = <double>[
  0.2126, 0.7152, 0.0722, 0, 0,
  0.2126, 0.7152, 0.0722, 0, 0,
  0.2126, 0.7152, 0.0722, 0, 0,
  0, 0, 0, 1, 0,
];

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

void _openFarmerHelp(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => HelpSupportScreen(
        roleLabel: 'Farmers',
        heroSubtitle:
            'Our AI assistant and support team are ready to assist you with your agricultural needs.',
        onNotificationsTap: () => context.go('/farmer/alerts'),
        contactMethods: const [
          HelpContactMethod(icon: Icons.chat_bubble_outline_rounded, label: 'Live Chat', detail: 'Chat with our support team'),
          HelpContactMethod(icon: Icons.call_rounded, label: 'Call Support', detail: '+233 30 123 4567'),
          HelpContactMethod(icon: Icons.email_outlined, label: 'Email Us', detail: 'support@agriconnect.com'),
        ],
        faqItems: const [
          'How do I list my produce for sale?',
          'When will I receive payment after a sale?',
          'How does the freshness score work?',
          'How do I use the Scan feature to price my harvest?',
        ],
        resourceLinks: const [
          HelpResourceLink(icon: Icons.description_outlined, label: 'Terms of Service'),
          HelpResourceLink(icon: Icons.verified_user_outlined, label: 'Privacy Policy'),
          HelpResourceLink(icon: Icons.groups_outlined, label: 'Farmer Community Guidelines'),
        ],
      ),
    ),
  );
}

/// Farmer-specific Profile tab: hero card (rating/sales), Farm Details,
/// Account & Support, and Log Out. Driver/Buyer have their own equivalent
/// screens — this one replicates the farmer-specific reference.
class FarmerProfileScreen extends ConsumerWidget {
  const FarmerProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final user = ref.watch(authControllerProvider).user;
    final details = ref.watch(farmerProfileDetailsProvider);
    final themeMode = ref.watch(themeModeControllerProvider);

    return Scaffold(
      body: ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              _ProfileHero(colorScheme: colorScheme, user: user, details: details),
              const SizedBox(height: 56),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Farm Details',
                      style: TextStyle(color: colorScheme.onSurface, fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    _InfoCard(
                      colorScheme: colorScheme,
                      children: [
                        _InfoRow(
                          colorScheme: colorScheme,
                          icon: Icons.location_on_rounded,
                          title: details.location,
                          subtitle: 'Location',
                        ),
                        _InfoRow(
                          colorScheme: colorScheme,
                          icon: Icons.agriculture_rounded,
                          title: details.primaryCrops.join(', '),
                          subtitle: 'Primary Crops',
                        ),
                        _InfoRow(
                          colorScheme: colorScheme,
                          icon: Icons.account_balance_wallet_rounded,
                          title: formatGhs(details.walletBalance),
                          subtitle: 'Wallet Balance',
                          isLast: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Account & Support',
                      style: TextStyle(color: colorScheme.onSurface, fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    _InfoCard(
                      colorScheme: colorScheme,
                      children: [
                        _ActionRow(
                          colorScheme: colorScheme,
                          label: 'Account Settings',
                          onTap: () => _openComingSoon(context, 'Account Settings', Icons.settings_outlined),
                        ),
                        _ActionRow(
                          colorScheme: colorScheme,
                          label: 'Payment Methods',
                          onTap: () => _openComingSoon(context, 'Payment Methods', Icons.payments_outlined),
                        ),
                        _ActionRow(
                          colorScheme: colorScheme,
                          label: 'Help & Support',
                          onTap: () => _openFarmerHelp(context),
                          isLast: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Appearance',
                      style: TextStyle(color: colorScheme.onSurface, fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    _InfoCard(
                      colorScheme: colorScheme,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: SegmentedButton<ThemeMode>(
                            segments: const [
                              ButtonSegment(value: ThemeMode.system, label: Text('System'), icon: Icon(Icons.brightness_auto_outlined)),
                              ButtonSegment(value: ThemeMode.light, label: Text('Light'), icon: Icon(Icons.light_mode_outlined)),
                              ButtonSegment(value: ThemeMode.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode_outlined)),
                            ],
                            selected: {themeMode},
                            onSelectionChanged: (selection) =>
                                ref.read(themeModeControllerProvider.notifier).setThemeMode(selection.first),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    _LogOutButton(colorScheme: colorScheme),
                    const SizedBox(height: 12),
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
  const _ProfileHero({required this.colorScheme, required this.user, required this.details});

  final ColorScheme colorScheme;
  final UserModel? user;
  final FarmerProfileDetails details;

  @override
  Widget build(BuildContext context) {
    final badgeColor = Color.lerp(colorScheme.primary, Colors.white, 0.6)!;
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomCenter,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color.lerp(colorScheme.primary, Colors.white, 0.15)!, colorScheme.primary],
            ),
            borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(36), bottomRight: Radius.circular(36)),
          ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              children: [
                Text(
                  user?.name ?? 'Farmer',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800),
                ),
                if (user?.status == AccountStatus.verified) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_rounded, color: badgeColor, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        'Verified Farmer',
                        style: TextStyle(color: badgeColor, fontWeight: FontWeight.w700, fontSize: 14.5),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 18),
                Divider(color: Colors.white.withValues(alpha: 0.2), height: 1),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _HeroStat(value: details.rating.toStringAsFixed(1), label: 'Rating'),
                    Container(
                      width: 1,
                      height: 34,
                      color: Colors.white.withValues(alpha: 0.2),
                      margin: const EdgeInsets.symmetric(horizontal: 28),
                    ),
                    _HeroStat(value: '${details.salesCount}', label: 'Sales'),
                  ],
                ),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: -44,
          child: Container(
            width: 96,
            height: 96,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).scaffoldBackgroundColor,
              border: Border.all(color: colorScheme.outline.withValues(alpha: 0.3)),
            ),
            child: ClipOval(
              child: ColorFiltered(
                colorFilter: const ColorFilter.matrix(_grayscaleMatrix),
                child: Image.asset(_heroImage, fit: BoxFit.cover),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12.5, fontWeight: FontWeight.w600)),
      ],
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.colorScheme,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.isLast = false,
  });

  final ColorScheme colorScheme;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: isLast ? null : Border(bottom: BorderSide(color: colorScheme.outline.withValues(alpha: 0.15))),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: colorScheme.primary.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: Icon(icon, color: colorScheme.primary, size: 19),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
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

class _LogOutButton extends ConsumerWidget {
  const _LogOutButton({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: () async {
          final confirmed = await showAgriDialog(
            context,
            title: 'Log out?',
            message: "You'll need to log in again to access your account.",
            confirmLabel: 'Log Out',
            destructive: true,
          );
          if (confirmed == true) {
            await ref.read(authControllerProvider.notifier).logout();
          }
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.error,
          side: BorderSide(color: colorScheme.error.withValues(alpha: 0.5)),
          shape: const StadiumBorder(),
        ),
        icon: const Icon(Icons.logout_rounded, size: 18),
        label: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}
