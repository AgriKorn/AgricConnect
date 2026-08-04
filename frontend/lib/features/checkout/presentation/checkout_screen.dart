import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/utils/currency.dart';
import '../../../core/utils/freshness.dart';
import '../../../core/widgets/ambient_background.dart';
import '../../../core/widgets/responsive_content.dart';
import '../../marketplace/data/marketplace_mock.dart';
import '../../orders/data/orders_repository.dart';
import '../application/checkout_providers.dart';
import '../data/checkout_mock.dart';

/// Secure Checkout: escrow explainer -> order summary -> delivery choice ->
/// payment method -> sticky "Pay & Confirm Escrow" footer.
///
/// Handles one or more listings selected together on the marketplace grid.
/// The backend purchases one whole listing per call (no partial quantity,
/// no multi-item basket endpoint), so each selected listing is bought for
/// its full available quantity via a separate, sequential real API call —
/// there is no editable quantity stepper because there is nothing to adjust.
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key, required this.listings});

  final List<MarketplaceListing> listings;

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  bool _hasOwnTransport = false;
  bool _submitting = false;
  String? _error;

  Future<void> _pay() async {
    setState(() {
      _submitting = true;
      _error = null;
    });

    final results = <_PurchaseOutcome>[];
    for (final listing in widget.listings) {
      try {
        final result = await ref.read(ordersRepositoryProvider).purchaseListing(
              listingId: listing.id,
              hasOwnTransport: _hasOwnTransport,
            );
        results.add(_PurchaseOutcome(listing: listing, result: result));
      } on ApiException catch (e) {
        results.add(_PurchaseOutcome(listing: listing, error: e.message));
      }
    }

    if (!mounted) return;
    setState(() => _submitting = false);

    // "Pay & Confirm Escrow" IS the payment step, so the order that was just
    // created has to redirect to Paystack on its own — it can't depend on
    // the buyer noticing and tapping a second "Open Payment Link" button
    // buried inside the outcome dialog below. Only one listing's checkout
    // opens automatically: each listing is its own separate Paystack
    // transaction, so auto-launching more than one would fire multiple
    // external browser tabs at once.
    PurchaseResult? firstPayable;
    for (final outcome in results) {
      if (outcome.error == null && (outcome.result?.authorizationUrl.isNotEmpty ?? false)) {
        firstPayable = outcome.result;
        break;
      }
    }
    if (firstPayable != null) {
      await _openPaymentLink(firstPayable.authorizationUrl);
    }

    if (!mounted) return;
    await _showOutcomeDialog(results);
  }

  Future<void> _openPaymentLink(String url) async {
    var launched = false;
    try {
      launched = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      launched = false;
    }
    if (!launched && mounted) {
      setState(() {
        _error = 'Could not open the Paystack payment page automatically. Use "Open Payment Link" below, or find this order in your Orders tab to try again.';
      });
    }
  }

  Future<void> _showOutcomeDialog(List<_PurchaseOutcome> results) async {
    final colorScheme = Theme.of(context).colorScheme;
    final allSucceeded = results.every((r) => r.error == null);

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          allSucceeded ? 'Order placed' : 'Some items could not be purchased',
          style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w800),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final outcome in results) ...[
                Text(
                  outcome.listing.name,
                  style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                if (outcome.error != null)
                  Text(
                    outcome.error!,
                    style: TextStyle(color: colorScheme.error, fontSize: 13),
                  )
                else ...[
                  Text(
                    _hasOwnTransport
                        ? 'Complete payment to confirm your order for ${formatGhs(outcome.result!.amount)}. You\'ll collect the produce yourself.'
                        : 'Complete payment to confirm your order for ${formatGhs(outcome.result!.amount)}. A driver will be assigned automatically.',
                    style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13, height: 1.4),
                  ),
                  if (outcome.result!.authorizationUrl.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    TextButton(
                      onPressed: () => _openPaymentLink(outcome.result!.authorizationUrl),
                      child: const Text('Open Payment Link'),
                    ),
                  ] else ...[
                    const SizedBox(height: 6),
                    Text(
                      'This order was already started moments ago — check the Orders tab to finish payment.',
                      style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12, fontStyle: FontStyle.italic),
                    ),
                  ],
                ],
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: colorScheme.primary, foregroundColor: colorScheme.onPrimary),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              if (mounted) Navigator.of(context).pop();
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
    final method = ref.watch(selectedPaymentMethodProvider);
    final listings = widget.listings;

    final total = listings.fold<double>(
      0,
      (sum, listing) => sum + listing.pricePerUnit * (listing.quantityAvailable ?? 0),
    );

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          AmbientBackground(colorScheme: colorScheme),
          SafeArea(
            child: ResponsiveContent(
              child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 20, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(Icons.chevron_left_rounded, color: colorScheme.onSurface),
                        style: IconButton.styleFrom(
                          backgroundColor: colorScheme.surfaceContainerHighest,
                          shape: const CircleBorder(),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Secure Checkout',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: colorScheme.onSurface, fontSize: 21, fontWeight: FontWeight.w800),
                        ),
                      ),
                      Icon(Icons.gpp_good_rounded, color: colorScheme.primary, size: 26),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                    children: [
                      _EscrowBanner(colorScheme: colorScheme),
                      const SizedBox(height: 24),
                      _OrderSummaryCard(colorScheme: colorScheme, listings: listings, total: total),
                      const SizedBox(height: 24),
                      Text(
                        'Delivery',
                        style: TextStyle(color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600, fontSize: 13.5),
                      ),
                      const SizedBox(height: 12),
                      _TransportChoice(
                        colorScheme: colorScheme,
                        hasOwnTransport: _hasOwnTransport,
                        onChanged: (value) => setState(() => _hasOwnTransport = value),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Preferred Mobile Money Network',
                        style: TextStyle(color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600, fontSize: 13.5),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _PaymentMethodCard(
                              colorScheme: colorScheme,
                              method: PaymentMethod.mtnMomo,
                              selected: method == PaymentMethod.mtnMomo,
                              onTap: () => ref.read(selectedPaymentMethodProvider.notifier).state = PaymentMethod.mtnMomo,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _PaymentMethodCard(
                              colorScheme: colorScheme,
                              method: PaymentMethod.vodafone,
                              selected: method == PaymentMethod.vodafone,
                              onTap: () => ref.read(selectedPaymentMethodProvider.notifier).state = PaymentMethod.vodafone,
                              icon: Icons.circle_outlined,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'You\'ll confirm the exact network and complete payment on the secure Paystack page that opens next.',
                        style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12, height: 1.3),
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
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.lock_rounded, size: 14, color: colorScheme.onSurfaceVariant),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'End-to-end encrypted transaction',
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _CheckoutFooter(
                  colorScheme: colorScheme,
                  total: total,
                  submitting: _submitting,
                  onPay: _pay,
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

class _PurchaseOutcome {
  _PurchaseOutcome({required this.listing, this.result, this.error});
  final MarketplaceListing listing;
  final PurchaseResult? result;
  final String? error;
}

class _EscrowBanner extends StatelessWidget {
  const _EscrowBanner({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_rounded, color: colorScheme.onSurface, size: 24),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AgriConnect Escrow Protected',
                  style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w800, fontSize: 15.5),
                ),
                const SizedBox(height: 6),
                Text(
                  'Funds are held securely and only released once you confirm delivery of fresh produce.',
                  style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderSummaryCard extends StatelessWidget {
  const _OrderSummaryCard({required this.colorScheme, required this.listings, required this.total});

  final ColorScheme colorScheme;
  final List<MarketplaceListing> listings;
  final double total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order Summary',
            style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w800, fontSize: 17),
          ),
          const SizedBox(height: 14),
          Divider(color: colorScheme.outline.withValues(alpha: 0.2), height: 1),
          const SizedBox(height: 18),
          for (var i = 0; i < listings.length; i++) ...[
            _OrderItemRow(colorScheme: colorScheme, listing: listings[i]),
            if (i != listings.length - 1) const SizedBox(height: 18),
          ],
          const SizedBox(height: 20),
          Divider(color: colorScheme.outline.withValues(alpha: 0.2), height: 1),
          const SizedBox(height: 16),
          _SummaryRow(
            colorScheme: colorScheme,
            label: 'Total Amount',
            value: formatGhs(total),
            emphasized: true,
          ),
        ],
      ),
    );
  }
}

class _OrderItemRow extends StatelessWidget {
  const _OrderItemRow({required this.colorScheme, required this.listing});

  final ColorScheme colorScheme;
  final MarketplaceListing listing;

  @override
  Widget build(BuildContext context) {
    final freshness = freshnessColorFor(listing.freshnessScore, Theme.of(context).brightness);
    final quantity = listing.quantityAvailable;
    final quantityLabel = quantity != null ? '${quantity.toStringAsFixed(0)} ${listing.unit}' : 'Full listing';
    final lineTotal = quantity != null ? listing.pricePerUnit * quantity : listing.pricePerUnit;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            width: 64,
            height: 64,
            child: listing.imageUrl != null
                ? Image.network(listing.imageUrl!, fit: BoxFit.cover)
                : listing.imageAsset != null
                ? Image.asset(listing.imageAsset!, fit: BoxFit.cover)
                : DecoratedBox(
                    decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest),
                    child: Icon(listing.category.icon, color: colorScheme.primary),
                  ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      listing.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    formatGhs(lineTotal),
                    style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: freshness, borderRadius: BorderRadius.circular(999)),
                child: Text(
                  '${listing.freshnessScore}% Fresh',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Buying: $quantityLabel (whole listing)',
                style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
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

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.colorScheme,
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final ColorScheme colorScheme;
  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final labelStyle = TextStyle(
      color: emphasized ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
      fontWeight: emphasized ? FontWeight.w800 : FontWeight.w500,
      fontSize: emphasized ? 16 : 14,
    );
    final valueStyle = TextStyle(
      color: colorScheme.onSurface,
      fontWeight: emphasized ? FontWeight.w800 : FontWeight.w700,
      fontSize: emphasized ? 17 : 14.5,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(child: Text(label, style: labelStyle)),
        const SizedBox(width: 8),
        Flexible(child: Text(value, style: valueStyle, textAlign: TextAlign.right)),
      ],
    );
  }
}

class _PaymentMethodCard extends StatelessWidget {
  const _PaymentMethodCard({
    required this.colorScheme,
    required this.method,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final ColorScheme colorScheme;
  final PaymentMethod method;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 84,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? colorScheme.primary : colorScheme.outline.withValues(alpha: 0.25),
            width: selected ? 1.5 : 1,
          ),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, color: colorScheme.onSurfaceVariant, size: 26),
              const SizedBox(height: 8),
            ],
            Text(
              method.label,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontWeight: icon == null ? FontWeight.w800 : FontWeight.w600,
                fontSize: 14.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckoutFooter extends StatelessWidget {
  const _CheckoutFooter({
    required this.colorScheme,
    required this.total,
    required this.submitting,
    required this.onPay,
  });

  final ColorScheme colorScheme;
  final double total;
  final bool submitting;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: Border(top: BorderSide(color: colorScheme.outline.withValues(alpha: 0.2))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Total to Pay', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(
            formatGhs(total),
            style: TextStyle(color: colorScheme.primary, fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton.icon(
              onPressed: submitting ? null : onPay,
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                shape: const StadiumBorder(),
              ),
              icon: submitting
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.onPrimary),
                    )
                  : const Icon(Icons.lock_rounded, size: 18),
              label: Text(
                submitting ? 'Processing...' : 'Pay & Confirm Escrow',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
