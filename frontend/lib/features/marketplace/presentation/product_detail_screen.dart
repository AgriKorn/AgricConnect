import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/currency.dart';
import '../../../core/utils/freshness.dart';
import '../../../core/widgets/ambient_background.dart';
import '../../../core/widgets/empty_state.dart';
import '../../auth/application/auth_controller.dart';
import '../../checkout/presentation/checkout_screen.dart';
import '../application/marketplace_providers.dart';
import '../data/marketplace_mock.dart';

/// Full detail view for a single marketplace listing — GET /marketplace/:id,
/// including fields the grid tile has no room for (farmer region, shelf
/// life). Reached by tapping a listing card; "Add to Cart" reuses the same
/// [selectedMarketplaceListingsProvider] the grid's multi-select does, so a
/// buyer can mix items picked from the grid and from detail views into one
/// checkout.
class ProductDetailScreen extends ConsumerWidget {
  const ProductDetailScreen({super.key, required this.listingId});

  final String listingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final detailAsync = ref.watch(marketplaceListingDetailProvider(listingId));

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
                    ],
                  ),
                ),
                Expanded(
                  child: detailAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (error, _) => Center(
                      child: EmptyState(
                        icon: Icons.error_outline_rounded,
                        message: 'Could not load this listing.',
                      ),
                    ),
                    data: (listing) => _ProductDetailBody(colorScheme: colorScheme, listing: listing),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductDetailBody extends ConsumerWidget {
  const _ProductDetailBody({required this.colorScheme, required this.listing});

  final ColorScheme colorScheme;
  final MarketplaceListingDetail listing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final freshness = freshnessColorFor(listing.freshnessScore, Theme.of(context).brightness);
    final asSelectable = listing.toMarketplaceListing();
    final selected = ref.watch(selectedMarketplaceListingsProvider).contains(asSelectable);
    final isOwnListing = listing.farmerId != null && listing.farmerId == ref.watch(authControllerProvider).user?.id;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: listing.imageUrl != null
                ? Image.network(listing.imageUrl!, fit: BoxFit.cover)
                : DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          colorScheme.primary.withValues(alpha: 0.35),
                          colorScheme.primary.withValues(alpha: 0.12),
                        ],
                      ),
                    ),
                    child: Center(
                      child: Icon(listing.category.icon, size: 60, color: colorScheme.primary.withValues(alpha: 0.8)),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                listing.name,
                style: TextStyle(color: colorScheme.onSurface, fontSize: 24, fontWeight: FontWeight.w800),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: freshness, borderRadius: BorderRadius.circular(999)),
              child: Text(
                '${listing.freshnessScore}% Fresh',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '${formatGhs(listing.pricePerUnit)} / ${listing.unit}',
          style: TextStyle(color: colorScheme.primary, fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 20),
        _InfoCard(
          colorScheme: colorScheme,
          rows: [
            (Icons.storefront_rounded, 'Farmer', listing.farmerName),
            if (listing.farmerRegion != null) (Icons.location_on_rounded, 'Location', listing.farmerRegion!),
            if (listing.quantityAvailable != null)
              (Icons.inventory_2_rounded, 'Available Quantity', '${listing.quantityAvailable!.toStringAsFixed(0)} ${listing.unit}'),
            if (listing.shelfLifeDays != null)
              (Icons.hourglass_bottom_rounded, 'Shelf Life', '${listing.shelfLifeDays} days'),
          ],
        ),
        const SizedBox(height: 24),
        if (isOwnListing)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, color: colorScheme.onSurfaceVariant, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "This is your own listing — you can't purchase it.",
                    style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          )
        else
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton.icon(
              onPressed: () => selected
                  ? Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => CheckoutScreen(listings: [asSelectable])),
                    )
                  : _addToCart(context, ref, asSelectable),
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                shape: const StadiumBorder(),
              ),
              icon: Icon(selected ? Icons.shopping_cart_checkout_rounded : Icons.add_shopping_cart_rounded, size: 18),
              label: Text(
                selected ? 'Proceed to Checkout' : 'Add to Cart',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
          ),
      ],
    );
  }

  void _addToCart(BuildContext context, WidgetRef ref, MarketplaceListing listing) {
    final notifier = ref.read(selectedMarketplaceListingsProvider.notifier);
    notifier.state = {...notifier.state, listing};
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Added to cart')),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.colorScheme, required this.rows});

  final ColorScheme colorScheme;
  final List<(IconData, String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: i == rows.length - 1
                    ? null
                    : Border(bottom: BorderSide(color: colorScheme.outline.withValues(alpha: 0.15))),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(color: colorScheme.primary.withValues(alpha: 0.15), shape: BoxShape.circle),
                    child: Icon(rows[i].$1, color: colorScheme.primary, size: 17),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      rows[i].$2,
                      style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
                    ),
                  ),
                  Text(
                    rows[i].$3,
                    style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
