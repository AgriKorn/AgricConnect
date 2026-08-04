import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/currency.dart';
import '../../../../core/utils/freshness.dart';
import '../../application/marketplace_providers.dart';
import '../../data/marketplace_mock.dart';
import '../product_detail_screen.dart';

/// One marketplace listing card: photo, freshness badge, cart-select toggle,
/// name, price. Shared by the main Marketplace grid and a farmer's store
/// page grid so a fix to one applies to both instead of drifting apart.
class ListingGridTile extends ConsumerWidget {
  const ListingGridTile({super.key, required this.listing, required this.colorScheme});

  final MarketplaceListing listing;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final freshness = freshnessColorFor(listing.freshnessScore, Theme.of(context).brightness);
    final accent = colorScheme.primary;
    final selected = ref.watch(selectedMarketplaceListingsProvider).contains(listing);

    void toggleSelected() {
      final notifier = ref.read(selectedMarketplaceListingsProvider.notifier);
      final next = Set<MarketplaceListing>.from(notifier.state);
      if (!next.remove(listing)) next.add(listing);
      notifier.state = next;
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: selected ? Border.all(color: colorScheme.primary, width: 3) : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(selected ? 19 : 22),
        child: Material(
          color: colorScheme.surface.withValues(alpha: 0.6),
          child: InkWell(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => ProductDetailScreen(listingId: listing.id)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: listing.imageUrl != null
                            ? Image.network(listing.imageUrl!, fit: BoxFit.cover)
                            : listing.imageAsset != null
                            ? Image.asset(listing.imageAsset!, fit: BoxFit.cover)
                            : DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [accent.withValues(alpha: 0.35), accent.withValues(alpha: 0.12)],
                                  ),
                                ),
                                child: Center(
                                  child: Icon(listing.category.icon, size: 44, color: accent.withValues(alpha: 0.8)),
                                ),
                              ),
                      ),
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: freshness, borderRadius: BorderRadius.circular(999)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.eco_rounded, size: 11, color: Colors.white),
                              const SizedBox(width: 3),
                              Text(
                                '${listing.freshnessScore}% Fresh',
                                style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(999),
                            onTap: toggleSelected,
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: selected ? colorScheme.primary : Colors.black.withValues(alpha: 0.4),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                selected ? Icons.check_rounded : Icons.add_shopping_cart_rounded,
                                size: 15,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        listing.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${formatGhs(listing.pricePerUnit)} / ${listing.unit}',
                        style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w600, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Same 2/3/4/5-column responsive rule the Marketplace grid uses — kept here
/// so a farmer's store page grid matches it exactly.
int crossAxisCountForWidth(double width) {
  if (width >= 1100) return 5;
  if (width >= 800) return 4;
  if (width >= 560) return 3;
  return 2;
}

/// Floating "go to checkout with N selected items" button — shared by the
/// main Marketplace grid and a farmer's store page grid, since both let a
/// buyer add to the same cart selection.
class MarketplaceCartFab extends StatelessWidget {
  const MarketplaceCartFab({super.key, required this.colorScheme, required this.count, required this.onPressed});

  final ColorScheme colorScheme;
  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        FloatingActionButton(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          onPressed: onPressed,
          child: const Icon(Icons.shopping_cart_rounded),
        ),
        Positioned(
          top: -4,
          right: -4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            constraints: const BoxConstraints(minWidth: 22),
            decoration: BoxDecoration(
              color: colorScheme.error,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: colorScheme.surface, width: 2),
            ),
            child: Text(
              '$count',
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.onError, fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }
}
