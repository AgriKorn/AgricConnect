import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/marketplace_mock.dart';

enum ListingSort { freshnessDesc, priceAsc, priceDesc }

extension ListingSortX on ListingSort {
  String get label => switch (this) {
    ListingSort.freshnessDesc => 'Freshest first',
    ListingSort.priceAsc => 'Price: low to high',
    ListingSort.priceDesc => 'Price: high to low',
  };
}

final marketplaceListingsProvider = Provider<List<MarketplaceListing>>((ref) {
  return mockMarketplaceListings;
});

/// null means "All Crops".
final marketplaceCategoryFilterProvider = StateProvider<ProduceCategory?>((ref) => null);

final marketplaceSearchQueryProvider = StateProvider<String>((ref) => '');

final marketplaceSortProvider = StateProvider<ListingSort>((ref) => ListingSort.freshnessDesc);

/// Listings tapped/selected on the marketplace grid — driving the bottom
/// cart button that takes them all to checkout together.
final selectedMarketplaceListingsProvider = StateProvider<Set<MarketplaceListing>>((ref) => {});

final filteredMarketplaceListingsProvider = Provider<List<MarketplaceListing>>((ref) {
  final category = ref.watch(marketplaceCategoryFilterProvider);
  final query = ref.watch(marketplaceSearchQueryProvider).trim().toLowerCase();
  final sort = ref.watch(marketplaceSortProvider);

  final result = ref
      .watch(marketplaceListingsProvider)
      .where((listing) => category == null || listing.category == category)
      .where((listing) => query.isEmpty || listing.name.toLowerCase().contains(query))
      .toList();

  result.sort((a, b) => switch (sort) {
    ListingSort.freshnessDesc => b.freshnessScore.compareTo(a.freshnessScore),
    ListingSort.priceAsc => a.pricePerUnit.compareTo(b.pricePerUnit),
    ListingSort.priceDesc => b.pricePerUnit.compareTo(a.pricePerUnit),
  });

  return result;
});
