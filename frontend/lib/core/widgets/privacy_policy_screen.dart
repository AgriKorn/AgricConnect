import 'package:flutter/material.dart';

class _PolicySection {
  const _PolicySection(this.title, this.body);
  final String title;
  final String body;
}

const _sections = [
  _PolicySection(
    'What we collect',
    'To run your account we collect your name, phone number, email address, and region. '
        'Farmers and drivers additionally provide Mobile Money payout details and, for drivers, '
        'vehicle capacity and operating region. If you upload a profile or crop photo, that photo '
        'and its storage location are collected too. We also record device push-notification tokens '
        'so we can notify you about orders and deliveries.',
  ),
  _PolicySection(
    'Location data',
    'When you create a produce listing, its GPS coordinates are recorded so buyers and drivers can '
        'see where it is. We do not track your location in the background — only what you provide '
        'when creating a listing or delivery address.',
  ),
  _PolicySection(
    'Payments',
    'Payments are processed by Paystack, a third-party payment provider — we never see or store your '
        'card or Mobile Money PIN. Funds for an order are held in escrow until delivery is confirmed, '
        'then released to the farmer\'s Mobile Money account. A record of each transaction is kept for '
        'dispute resolution and accounting.',
  ),
  _PolicySection(
    'Who can see your data',
    'The other party in a transaction can see what they need to complete it — for example, a farmer '
        'sees a buyer\'s delivery address once an order is placed, and an assigned driver sees pickup '
        'and drop-off details for jobs they accept. We don\'t sell your data or share it with '
        'advertisers.',
  ),
  _PolicySection(
    'Account approval',
    'Farmer and driver accounts are reviewed by an admin before they can transact, which means an '
        'admin sees your registration details as part of that review.',
  ),
  _PolicySection(
    'Security',
    'Passwords are hashed and never stored in plain text. Login sessions use short-lived access '
        'tokens with a separate refresh token, and all traffic to our servers is encrypted in transit.',
  ),
  _PolicySection(
    'Your choices',
    'You can update your name and region at any time from Edit Profile, and control which '
        'notifications you receive from your Profile settings. To request a copy of your data or ask '
        'us to delete your account, contact support — this isn\'t yet a fully self-serve in-app action.',
  ),
];

/// Real policy content — not a legal document reviewed by counsel, but an
/// honest, specific description of what AgriConnect actually collects and
/// does with it, replacing what used to be a "Coming Soon" placeholder.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Text(
              'How AgriConnect handles your data',
              style: TextStyle(color: colorScheme.onSurface, fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Plain-language summary of what we collect and why.',
              style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 24),
            for (final section in _sections) ...[
              Text(
                section.title,
                style: TextStyle(color: colorScheme.onSurface, fontSize: 15.5, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                section.body,
                style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13.5, height: 1.5),
              ),
              const SizedBox(height: 20),
            ],
          ],
        ),
      ),
    );
  }
}
