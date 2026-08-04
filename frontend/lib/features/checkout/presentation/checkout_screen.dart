import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/currency.dart';
import '../../../core/utils/freshness.dart';
import '../../../core/widgets/agri_dialog.dart';
import '../../../core/widgets/agri_toast.dart';
import '../../../core/widgets/ambient_background.dart';
import '../../marketplace/application/marketplace_providers.dart';
import '../../marketplace/data/marketplace_mock.dart';
import '../application/checkout_providers.dart';
import '../data/checkout_mock.dart';

/// Secure Checkout: escrow explainer -> order summary -> payment method ->
/// sticky "Pay & Confirm Escrow" footer. Handles one or more listings
/// selected together on the marketplace grid, each with its own +/-
/// adjustable quantity (starting from [quantity] as the initial stand-in —
/// there's no real cart quantity carried over from the marketplace yet).
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key, required this.listings, this.quantity = 25});

  final List<MarketplaceListing> listings;
  final double quantity;

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  late final Map<String, double> _quantities;

  @override
  void initState() {
    super.initState();
    _quantities = {for (final listing in widget.listings) listing.id: widget.quantity};
  }

  void _adjustQuantity(String listingId, double delta) {
    setState(() {
      final next = (_quantities[listingId] ?? widget.quantity) + delta;
      _quantities[listingId] = next.clamp(1, 999);
    });
  }

  Future<void> _clearCart() async {
    final confirmed = await showAgriDialog(
      context,
      title: 'Clear Cart?',
      message: 'This will remove all items from your cart.',
      confirmLabel: 'Clear Cart',
      destructive: true,
    );
    if (confirmed != true || !mounted) return;
    ref.read(selectedMarketplaceListingsProvider.notifier).state = {};
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final method = ref.watch(selectedPaymentMethodProvider);
    final listings = widget.listings;

    final subtotal = listings.fold<double>(
      0,
      (sum, listing) => sum + listing.pricePerUnit * (_quantities[listing.id] ?? widget.quantity),
    );
    final total = subtotal + mockDeliveryFee + mockEscrowServiceFee;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          AmbientBackground(colorScheme: colorScheme),
          SafeArea(
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
                      _OrderSummaryCard(
                        colorScheme: colorScheme,
                        listings: listings,
                        quantities: _quantities,
                        onAdjustQuantity: _adjustQuantity,
                        onClearCart: _clearCart,
                        subtotal: subtotal,
                        total: total,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Select Payment Method',
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
                  onPay: () {
                    ref.read(selectedMarketplaceListingsProvider.notifier).state = {};
                    showAgriToast(context, 'Payment confirmed — funds are held in escrow until delivery.');
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
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
  const _OrderSummaryCard({
    required this.colorScheme,
    required this.listings,
    required this.quantities,
    required this.onAdjustQuantity,
    required this.onClearCart,
    required this.subtotal,
    required this.total,
  });

  final ColorScheme colorScheme;
  final List<MarketplaceListing> listings;
  final Map<String, double> quantities;
  final void Function(String listingId, double delta) onAdjustQuantity;
  final VoidCallback onClearCart;
  final double subtotal;
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
          Row(
            children: [
              Expanded(
                child: Text(
                  'Order Summary',
                  style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w800, fontSize: 17),
                ),
              ),
              GestureDetector(
                onTap: onClearCart,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.delete_outline_rounded, size: 15, color: colorScheme.error),
                    const SizedBox(width: 4),
                    Text(
                      'Clear Cart',
                      style: TextStyle(color: colorScheme.error, fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(color: colorScheme.outline.withValues(alpha: 0.2), height: 1),
          const SizedBox(height: 18),
          for (var i = 0; i < listings.length; i++) ...[
            _OrderItemRow(
              colorScheme: colorScheme,
              listing: listings[i],
              quantity: quantities[listings[i].id]!,
              onDecrement: () => onAdjustQuantity(listings[i].id, -1),
              onIncrement: () => onAdjustQuantity(listings[i].id, 1),
            ),
            if (i != listings.length - 1) const SizedBox(height: 18),
          ],
          const SizedBox(height: 20),
          _SummaryRow(colorScheme: colorScheme, label: 'Subtotal', value: formatGhs(subtotal)),
          const SizedBox(height: 12),
          _SummaryRow(colorScheme: colorScheme, label: 'Delivery Fee', value: formatGhs(mockDeliveryFee)),
          const SizedBox(height: 12),
          _SummaryRow(colorScheme: colorScheme, label: 'Escrow Service Fee', value: formatGhs(mockEscrowServiceFee)),
          const SizedBox(height: 16),
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
  const _OrderItemRow({
    required this.colorScheme,
    required this.listing,
    required this.quantity,
    required this.onDecrement,
    required this.onIncrement,
  });

  final ColorScheme colorScheme;
  final MarketplaceListing listing;
  final double quantity;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  @override
  Widget build(BuildContext context) {
    final freshness = freshnessColorFor(listing.freshnessScore, Theme.of(context).brightness);
    final quantityLabel = quantity == quantity.roundToDouble() ? quantity.toStringAsFixed(0) : quantity.toString();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            width: 64,
            height: 64,
            child: listing.imageAsset != null
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
                    formatGhs(listing.pricePerUnit * quantity),
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
              const SizedBox(height: 10),
              _QuantityStepper(
                colorScheme: colorScheme,
                quantityLabel: '$quantityLabel ${listing.unit.toUpperCase()}',
                onDecrement: onDecrement,
                onIncrement: onIncrement,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
    required this.colorScheme,
    required this.quantityLabel,
    required this.onDecrement,
    required this.onIncrement,
  });

  final ColorScheme colorScheme;
  final String quantityLabel;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepperButton(icon: Icons.remove_rounded, colorScheme: colorScheme, onTap: onDecrement),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              quantityLabel,
              style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
          _StepperButton(icon: Icons.add_rounded, colorScheme: colorScheme, onTap: onIncrement),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.colorScheme, required this.onTap});

  final IconData icon;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(width: 30, height: 30, child: Icon(icon, size: 16, color: colorScheme.primary)),
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
  const _CheckoutFooter({required this.colorScheme, required this.total, required this.onPay});

  final ColorScheme colorScheme;
  final double total;
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
              onPressed: onPay,
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                shape: const StadiumBorder(),
              ),
              icon: const Icon(Icons.lock_rounded, size: 18),
              label: const Text('Pay & Confirm Escrow', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}
