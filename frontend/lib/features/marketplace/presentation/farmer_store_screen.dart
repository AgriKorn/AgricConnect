import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/ambient_background.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/responsive_content.dart';
import '../../checkout/presentation/checkout_screen.dart';
import '../application/marketplace_providers.dart';
import 'widgets/listing_grid_tile.dart';

/// A single farmer's store — every active listing from one farmer, reached
/// by tapping their name on a product detail page. Reuses the same grid
/// tile and cart-selection state as the main Marketplace, so a buyer can mix
/// items picked here with items picked from the general browse view into
/// one checkout.
class FarmerStoreScreen extends ConsumerWidget {
  const FarmerStoreScreen({
    super.key,
    required this.farmerId,
    required this.farmerName,
    this.farmerRegion,
  });

  final String farmerId;
  final String farmerName;
  final String? farmerRegion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final listingsAsync = ref.watch(farmerStoreListingsProvider(farmerId));
    final selected = ref.watch(selectedMarketplaceListingsProvider);

    return Scaffold(
      floatingActionButton: selected.isEmpty
          ? null
          : MarketplaceCartFab(
              colorScheme: colorScheme,
              count: selected.length,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => CheckoutScreen(listings: selected.toList())),
              ),
            ),
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
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: _StoreHeader(colorScheme: colorScheme, farmerName: farmerName, farmerRegion: farmerRegion),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () => ref.refresh(farmerStoreListingsProvider(farmerId).future),
                      child: listingsAsync.when(
                        loading: () => ListView(
                          children: const [
                            SizedBox(height: 120),
                            Center(child: CircularProgressIndicator()),
                          ],
                        ),
                        error: (error, _) => ListView(
                          children: [
                            const SizedBox(height: 60),
                            EmptyState(
                              icon: Icons.wifi_off_rounded,
                              message: "Could not load this farmer's listings. Pull down to retry.",
                            ),
                          ],
                        ),
                        data: (listings) => listings.isEmpty
                            ? ListView(
                                children: [
                                  const SizedBox(height: 60),
                                  EmptyState(
                                    icon: Icons.storefront_outlined,
                                    message: 'This farmer has no active listings right now.',
                                  ),
                                ],
                              )
                            : LayoutBuilder(
                                builder: (context, constraints) => GridView.builder(
                                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: crossAxisCountForWidth(constraints.maxWidth),
                                    mainAxisSpacing: 14,
                                    crossAxisSpacing: 14,
                                    childAspectRatio: 0.74,
                                  ),
                                  itemCount: listings.length,
                                  itemBuilder: (context, index) =>
                                      ListingGridTile(listing: listings[index], colorScheme: colorScheme),
                                ),
                              ),
                      ),
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

class _StoreHeader extends StatelessWidget {
  const _StoreHeader({required this.colorScheme, required this.farmerName, this.farmerRegion});

  final ColorScheme colorScheme;
  final String farmerName;
  final String? farmerRegion;

  @override
  Widget build(BuildContext context) {
    final initial = farmerName.trim().isEmpty ? '?' : farmerName.trim()[0].toUpperCase();
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: colorScheme.primary.withValues(alpha: 0.15), shape: BoxShape.circle),
          child: Text(
            initial,
            style: TextStyle(color: colorScheme.primary, fontSize: 20, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                farmerName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: colorScheme.onSurface, fontSize: 19, fontWeight: FontWeight.w800),
              ),
              if (farmerRegion != null) ...[
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.location_on_rounded, size: 13, color: colorScheme.onSurfaceVariant),
                    const SizedBox(width: 3),
                    Text(
                      farmerRegion!,
                      style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12.5),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
