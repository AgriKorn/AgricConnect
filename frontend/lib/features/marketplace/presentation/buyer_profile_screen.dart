import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/currency.dart';
import '../../../core/widgets/agri_dialog.dart';
import '../../../core/widgets/coming_soon_screen.dart';
import '../../../core/widgets/help_support_screen.dart';
import '../../auth/application/auth_controller.dart';
import '../application/buyer_profile_providers.dart';
import '../data/buyer_profile_mock.dart';

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

/// Buyer-specific Profile tab: hero (avatar/tier), Wallet Balance, Delivery
/// Addresses, Payment Methods, Preferences (notification toggles), Help &
/// Privacy links, and Log Out. Farmer/Driver have their own equivalents —
/// this one replicates the buyer-specific reference.
class BuyerProfileScreen extends ConsumerWidget {
  const BuyerProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final profile = ref.watch(buyerProfileProvider);
    final addresses = ref.watch(deliveryAddressesProvider);
    final paymentMethods = ref.watch(savedPaymentMethodsProvider);
    final preferences = ref.watch(buyerPreferencesProvider);

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
                    _WalletCard(
                      colorScheme: colorScheme,
                      balance: profile.walletBalance,
                      onTopUp: () => _openComingSoon(context, 'Top Up Wallet', Icons.account_balance_wallet_outlined),
                    ),
                    const SizedBox(height: 28),
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
                          onTap: () => _openComingSoon(context, 'Add Address', Icons.add_location_alt_outlined),
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
                    _InfoCard(
                      colorScheme: colorScheme,
                      children: [
                        for (var i = 0; i < addresses.length; i++)
                          _AddressRow(
                            colorScheme: colorScheme,
                            address: addresses[i],
                            isLast: i == addresses.length - 1,
                            onTap: () => _openComingSoon(context, addresses[i].label, addresses[i].type.icon),
                          ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Payment Methods',
                      style: TextStyle(color: colorScheme.onSurface, fontSize: 19, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    _InfoCard(
                      colorScheme: colorScheme,
                      children: [
                        for (var i = 0; i < paymentMethods.length; i++)
                          _PaymentMethodRow(
                            colorScheme: colorScheme,
                            method: paymentMethods[i],
                            isLast: i == paymentMethods.length - 1,
                            onTap: () => _openComingSoon(context, paymentMethods[i].label, Icons.credit_card_rounded),
                          ),
                      ],
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
                    const SizedBox(height: 20),
                    _InfoCard(
                      colorScheme: colorScheme,
                      children: [
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
                onTap: () => _openComingSoon(context, 'Edit Profile', Icons.edit_rounded),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(color: colorScheme.secondary, shape: BoxShape.circle),
                  child: Icon(Icons.edit_rounded, color: colorScheme.onSecondary, size: 16),
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
                  '${profile.tier} • ${profile.location}',
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

class _WalletCard extends StatelessWidget {
  const _WalletCard({required this.colorScheme, required this.balance, required this.onTopUp});

  final ColorScheme colorScheme;
  final double balance;
  final VoidCallback onTopUp;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: colorScheme.primary, borderRadius: BorderRadius.circular(24)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Wallet Balance',
                  style: TextStyle(color: colorScheme.onPrimary.withValues(alpha: 0.85), fontSize: 13),
                ),
                const SizedBox(height: 6),
                Text(
                  formatGhs(balance),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colorScheme.onPrimary, fontSize: 26, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: onTopUp,
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.secondary,
              foregroundColor: colorScheme.onSecondary,
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            ),
            child: const Text('Top Up', style: TextStyle(fontWeight: FontWeight.w700)),
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
              child: Icon(address.type.icon, color: colorScheme.onSurface, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    address.label,
                    style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    address.detail,
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

class _PaymentMethodRow extends StatelessWidget {
  const _PaymentMethodRow({
    required this.colorScheme,
    required this.method,
    required this.onTap,
    this.isLast = false,
  });

  final ColorScheme colorScheme;
  final SavedPaymentMethod method;
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
            SizedBox(
              width: 40,
              child: method.type == SavedPaymentType.visaCard
                  ? const Text('VISA', style: TextStyle(color: Color(0xFF1A1F71), fontWeight: FontWeight.w900, fontSize: 12))
                  : Icon(Icons.phone_android_rounded, color: colorScheme.onSurfaceVariant, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    method.label,
                    style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  Text(method.maskedNumber, style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12.5)),
                ],
              ),
            ),
            if (method.isDefault)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Default',
                  style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              )
            else
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
