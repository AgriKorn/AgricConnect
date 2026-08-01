import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_mode_controller.dart';
import '../../../core/widgets/account_settings_screen.dart';
import '../../../core/widgets/agri_dialog.dart';
import '../../../core/widgets/coming_soon_screen.dart';
import '../../../core/widgets/edit_profile_screen.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/help_support_screen.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/data/models/account_status.dart';
import '../application/buyer_profile_providers.dart';
import '../data/address_repository.dart';
import '../data/buyer_profile_mock.dart';
import 'edit_address_screen.dart';

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

Widget Function(double size) _buyerAvatarBuilder(BuyerProfileDetails profile) {
  return (size) => Builder(
        builder: (context) {
          final colorScheme = Theme.of(context).colorScheme;
          return ClipOval(
            child: ColoredBox(
              color: colorScheme.primary,
              child: Center(
                child: Text(
                  profile.initials,
                  style: TextStyle(color: colorScheme.onPrimary, fontWeight: FontWeight.w800, fontSize: size * 0.34),
                ),
              ),
            ),
          );
        },
      );
}

void _openBuyerAccountSettings(BuildContext context, BuyerProfileDetails profile, bool verified) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => AccountSettingsScreen(
        avatarBuilder: _buyerAvatarBuilder(profile),
        roleBadgeLabel: verified ? 'Verified Buyer' : 'Buyer',
        onHelpTap: () => _openBuyerHelp(context),
        locationLabel: 'Location',
        locationHint: 'e.g. Accra, Ghana',
        verifiedSubtitle: 'Your profile badge is visible to all farmers.',
      ),
    ),
  );
}

void _openBuyerEditProfile(BuildContext context, BuyerProfileDetails profile) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => EditProfileScreen(
        avatarBuilder: _buyerAvatarBuilder(profile),
        locationLabel: 'Location',
        locationHint: 'e.g. Accra, Ghana',
        verifiedSubtitle: 'Your profile badge is visible to all farmers.',
      ),
    ),
  );
}

void _openBuyerHelp(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => HelpSupportScreen(
        roleLabel: 'Buyers',
        heroSubtitle:
            'Our AI assistant and support team are ready to assist you with your shopping and orders needs.',
        contactMethods: const [
          HelpContactMethod(icon: Icons.chat_bubble_outline_rounded, label: 'Live Chat', detail: 'Chat with our support team'),
          HelpContactMethod(icon: Icons.call_rounded, label: 'Call Support', detail: '+233 30 123 4567'),
          HelpContactMethod(icon: Icons.email_outlined, label: 'Email Us', detail: 'support@agriconnect.com'),
        ],
        faqItems: const [
          'How does escrow protect my payment?',
          'How do I track my order?',
          'What if my produce arrives damaged?',
          'How do I add a new delivery address?',
        ],
        resourceLinks: const [
          HelpResourceLink(icon: Icons.description_outlined, label: 'Terms of Service'),
          HelpResourceLink(icon: Icons.verified_user_outlined, label: 'Privacy Policy'),
          HelpResourceLink(icon: Icons.assignment_return_outlined, label: 'Refund Policy'),
        ],
      ),
    ),
  );
}

/// Buyer-specific Profile tab: hero (avatar/tier), Delivery Addresses,
/// Payment Methods, Preferences (notification toggles), Help & Privacy
/// links, and Log Out. Farmer/Driver have their own equivalents — this
/// one replicates the buyer-specific reference.
class BuyerProfileScreen extends ConsumerWidget {
  const BuyerProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final profile = ref.watch(buyerProfileProvider);
    final addressesAsync = ref.watch(deliveryAddressesProvider);
    final preferences = ref.watch(buyerPreferencesProvider);
    final verified = ref.watch(authControllerProvider).user?.status == AccountStatus.verified;
    final themeMode = ref.watch(themeModeControllerProvider);

    return Scaffold(
      body: ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              _ProfileHero(colorScheme: colorScheme, profile: profile),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Delivery Addresses',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: colorScheme.onSurface, fontSize: 19, fontWeight: FontWeight.w800),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (context) => const EditAddressScreen()),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add_rounded, color: colorScheme.primary, size: 18),
                              const SizedBox(width: 2),
                              Text(
                                'Add New',
                                style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w700, fontSize: 13.5),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    addressesAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (error, _) => _InfoCard(
                        colorScheme: colorScheme,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'Could not load your addresses.',
                              style: TextStyle(color: colorScheme.error, fontSize: 13.5, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      data: (addresses) => addresses.isEmpty
                          ? EmptyState(
                              icon: Icons.location_on_outlined,
                              message: 'No delivery addresses yet. Add one for faster checkout.',
                            )
                          : _InfoCard(
                              colorScheme: colorScheme,
                              children: [
                                for (var i = 0; i < addresses.length; i++)
                                  _AddressRow(
                                    colorScheme: colorScheme,
                                    address: addresses[i],
                                    isLast: i == addresses.length - 1,
                                    onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute(builder: (context) => EditAddressScreen(address: addresses[i])),
                                    ),
                                  ),
                              ],
                            ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Preferences',
                      style: TextStyle(color: colorScheme.onSurface, fontSize: 19, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    _InfoCard(
                      colorScheme: colorScheme,
                      children: [
                        _PreferenceRow(
                          colorScheme: colorScheme,
                          label: 'Order Status Updates',
                          value: preferences.orderStatusUpdates,
                          onChanged: (_) => ref.read(buyerPreferencesProvider.notifier).toggleOrderStatusUpdates(),
                        ),
                        _PreferenceRow(
                          colorScheme: colorScheme,
                          label: 'Price Alerts (GHS)',
                          value: preferences.priceAlerts,
                          onChanged: (_) => ref.read(buyerPreferencesProvider.notifier).togglePriceAlerts(),
                        ),
                        _PreferenceRow(
                          colorScheme: colorScheme,
                          label: 'Freshness Notifications',
                          value: preferences.freshnessNotifications,
                          onChanged: (_) => ref.read(buyerPreferencesProvider.notifier).toggleFreshnessNotifications(),
                        ),
                        _PreferenceRow(
                          colorScheme: colorScheme,
                          label: 'Marketing Offers',
                          value: preferences.marketingOffers,
                          onChanged: (_) => ref.read(buyerPreferencesProvider.notifier).toggleMarketingOffers(),
                          isLast: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Appearance',
                      style: TextStyle(color: colorScheme.onSurface, fontSize: 19, fontWeight: FontWeight.w800),
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
                    const SizedBox(height: 20),
                    _InfoCard(
                      colorScheme: colorScheme,
                      children: [
                        _LinkRow(
                          colorScheme: colorScheme,
                          icon: Icons.settings_outlined,
                          label: 'Account Settings',
                          onTap: () => _openBuyerAccountSettings(context, profile, verified),
                        ),
                        _LinkRow(
                          colorScheme: colorScheme,
                          icon: Icons.help_outline_rounded,
                          label: 'Help Center',
                          onTap: () => _openBuyerHelp(context),
                        ),
                        _LinkRow(
                          colorScheme: colorScheme,
                          icon: Icons.verified_user_outlined,
                          label: 'Privacy Policy',
                          onTap: () => _openComingSoon(context, 'Privacy Policy', Icons.verified_user_outlined),
                          isLast: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _LogOutButton(colorScheme: colorScheme),
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
  const _ProfileHero({required this.colorScheme, required this.profile});

  final ColorScheme colorScheme;
  final BuyerProfileDetails profile;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: () => _openBuyerEditProfile(context, profile),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(color: colorScheme.primary, shape: BoxShape.circle),
                  child: Icon(Icons.edit_rounded, color: colorScheme.onPrimary, size: 16),
                ),
              ),
            ],
          ),
          Transform.translate(
            offset: const Offset(0, -8),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 52,
                  backgroundColor: colorScheme.primary,
                  child: Text(
                    profile.initials,
                    style: TextStyle(color: colorScheme.onPrimary, fontWeight: FontWeight.w800, fontSize: 30),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  profile.name,
                  style: TextStyle(color: colorScheme.onSurface, fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  'Buyer • ${profile.location}',
                  style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
                ),
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

class _AddressRow extends StatelessWidget {
  const _AddressRow({
    required this.colorScheme,
    required this.address,
    required this.onTap,
    this.isLast = false,
  });

  final ColorScheme colorScheme;
  final DeliveryAddress address;
  final VoidCallback onTap;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: isLast ? null : Border(bottom: BorderSide(color: colorScheme.outline.withValues(alpha: 0.15))),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest, shape: BoxShape.circle),
              child: Icon(Icons.location_on_outlined, color: colorScheme.onSurface, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        address.label,
                        style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                      if (address.isDefault) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Default',
                            style: TextStyle(color: colorScheme.primary, fontSize: 10.5, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    address.addressLine,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12.5),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _PreferenceRow extends StatelessWidget {
  const _PreferenceRow({
    required this.colorScheme,
    required this.label,
    required this.value,
    required this.onChanged,
    this.isLast = false,
  });

  final ColorScheme colorScheme;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: isLast ? null : Border(bottom: BorderSide(color: colorScheme.outline.withValues(alpha: 0.15))),
      ),
      child: Row(
        children: [
          Switch(value: value, activeThumbColor: colorScheme.primary, onChanged: onChanged),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w600, fontSize: 14.5)),
          ),
        ],
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.colorScheme,
    required this.icon,
    required this.label,
    required this.onTap,
    this.isLast = false,
  });

  final ColorScheme colorScheme;
  final IconData icon;
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
            Icon(icon, color: colorScheme.onSurfaceVariant, size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label, style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w700, fontSize: 15)),
            ),
            Icon(Icons.open_in_new_rounded, color: colorScheme.onSurfaceVariant, size: 18),
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
    final background = Color.lerp(colorScheme.error, Colors.white, 0.35)!;
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton.icon(
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
        style: FilledButton.styleFrom(
          backgroundColor: background,
          foregroundColor: Colors.white,
          shape: const StadiumBorder(),
        ),
        icon: const Icon(Icons.logout_rounded, size: 18),
        label: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}
