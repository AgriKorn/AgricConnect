import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/utils/currency.dart';
import '../../../core/utils/freshness.dart';
import '../../auth/presentation/widgets/auth_visuals.dart';
import '../../orders/data/orders_repository.dart';
import '../data/marketplace_mock.dart';

/// Buyer-facing listing detail + checkout confirmation. Reached by tapping a
/// marketplace tile (listing passed via go_router `extra`, same pattern as
/// AddListingScreen's scan prefill).
class ListingDetailScreen extends ConsumerStatefulWidget {
  const ListingDetailScreen({super.key, required this.listing});

  final MarketplaceListing listing;

  @override
  ConsumerState<ListingDetailScreen> createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends ConsumerState<ListingDetailScreen> {
  bool _hasOwnTransport = false;
  bool _submitting = false;
  String? _error;

  Future<void> _buyNow() async {
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final result = await ref.read(ordersRepositoryProvider).purchaseListing(
            listingId: widget.listing.id,
            hasOwnTransport: _hasOwnTransport,
          );
      if (!mounted) return;
      await _showConfirmation(result);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _showConfirmation(PurchaseResult result) async {
    final colorScheme = Theme.of(context).colorScheme;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Order placed',
          style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w800),
        ),
        content: Text(
          result.hasOwnTransport
              ? 'Complete payment to confirm your order for ${formatGhs(result.amount)}. You\'ll collect the produce yourself.'
              : 'Complete payment to confirm your order for ${formatGhs(result.amount)}. A driver will be assigned automatically.',
          style: TextStyle(color: colorScheme.onSurfaceVariant, height: 1.4),
        ),
        actions: [
          if (result.authorizationUrl.isNotEmpty)
            TextButton(
              onPressed: () => launchUrl(Uri.parse(result.authorizationUrl), mode: LaunchMode.externalApplication),
              child: const Text('Open Payment Link'),
            ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: colorScheme.primary, foregroundColor: colorScheme.onPrimary),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.pop();
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final listing = widget.listing;
    final freshnessColor = freshnessColorFor(listing.freshnessScore, brightness);
    final quantity = listing.quantityAvailable;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          _CoverBackdrop(colorScheme: colorScheme, category: listing.category),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AuthBackButton(
                    colorScheme: colorScheme,
                    onPressed: () => context.canPop() ? context.pop() : context.go('/buyer/marketplace'),
                  ),
                  const SizedBox(height: 16),
                  AuthGlassCard(
                    colorScheme: colorScheme,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                listing.name,
                                style: TextStyle(color: colorScheme.onSurface, fontSize: 22, fontWeight: FontWeight.w800),
                              ),
                            ),
                            _FreshnessBadge(score: listing.freshnessScore, color: freshnessColor),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Sold by ${listing.farmerName}',
                          style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13.5, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: _StatTile(
                                colorScheme: colorScheme,
                                label: 'Price',
                                value: '${formatGhs(listing.pricePerUnit)}/${listing.unit}',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _StatTile(
                                colorScheme: colorScheme,
                                label: 'Available',
                                value: quantity != null ? '${quantity.toStringAsFixed(0)} ${listing.unit}' : '—',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        AuthFieldLabel('Delivery', colorScheme),
                        const SizedBox(height: 10),
                        _TransportChoice(
                          colorScheme: colorScheme,
                          hasOwnTransport: _hasOwnTransport,
                          onChanged: (value) => setState(() => _hasOwnTransport = value),
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
                        const SizedBox(height: 22),
                        AuthPillButton(
                          label: _submitting ? 'Placing order...' : 'Buy Now — ${formatGhs(listing.pricePerUnit)}',
                          loading: _submitting,
                          onPressed: _buyNow,
                          colorScheme: colorScheme,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoverBackdrop extends StatelessWidget {
  const _CoverBackdrop({required this.colorScheme, required this.category});

  final ColorScheme colorScheme;
  final ProduceCategory category;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [colorScheme.primary.withValues(alpha: 0.25), colorScheme.surface],
        ),
      ),
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 60),
          child: Icon(category.icon, size: 96, color: colorScheme.primary.withValues(alpha: 0.35)),
        ),
      ),
    );
  }
}

class _FreshnessBadge extends StatelessWidget {
  const _FreshnessBadge({required this.score, required this.color});

  final int score;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(999)),
      child: Text(
        '$score% ${freshnessStateLabel(score)}',
        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.colorScheme, required this.label, required this.value});

  final ColorScheme colorScheme;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: colorScheme.onSurface, fontSize: 15, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _TransportChoice extends StatelessWidget {
  const _TransportChoice({required this.colorScheme, required this.hasOwnTransport, required this.onChanged});

  final ColorScheme colorScheme;
  final bool hasOwnTransport;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ChoiceCard(
            colorScheme: colorScheme,
            icon: Icons.local_shipping_rounded,
            label: 'Need a driver',
            selected: !hasOwnTransport,
            onTap: () => onChanged(false),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ChoiceCard(
            colorScheme: colorScheme,
            icon: Icons.directions_walk_rounded,
            label: 'I\'ll collect it',
            selected: hasOwnTransport,
            onTap: () => onChanged(true),
          ),
        ),
      ],
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.colorScheme,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final ColorScheme colorScheme;
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: selected ? colorScheme.primary.withValues(alpha: 0.15) : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? colorScheme.primary : colorScheme.outline.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant, size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
