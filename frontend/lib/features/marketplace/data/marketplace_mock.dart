import 'package:flutter/material.dart';

/// Despite the file name, these are the real marketplace types — mapped
/// from GET /marketplace and GET /marketplace/:id in marketplace_repository.dart.
enum ProduceCategory { vegetables, fruits, grains }

extension ProduceCategoryX on ProduceCategory {
  String get label => switch (this) {
    ProduceCategory.vegetables => 'Vegetables',
    ProduceCategory.fruits => 'Fruits',
    ProduceCategory.grains => 'Grains',
  };

  IconData get icon => switch (this) {
    ProduceCategory.vegetables => Icons.eco_rounded,
    ProduceCategory.fruits => Icons.spa_rounded,
    ProduceCategory.grains => Icons.grain_rounded,
  };
}

class MarketplaceListing {
  const MarketplaceListing({
    required this.id,
    required this.name,
    required this.category,
    required this.freshnessScore,
    required this.pricePerUnit,
    required this.unit,
    required this.farmerName,
    this.farmerId,
    this.quantityAvailable,
    this.imageAsset,
    this.imageUrl,
  });

  final String id;
  final String name;
  final ProduceCategory category;
  final int freshnessScore;
  final double pricePerUnit;
  final String unit;
  final String farmerName;
  final String? farmerId;
  final double? quantityAvailable;
  final String? imageAsset;
  /// Real S3 photo the farmer uploaded for this listing, if any.
  final String? imageUrl;

  // selectedMarketplaceListingsProvider is a Set<MarketplaceListing> that has
  // to recognize the same listing whether it was selected from the grid tile
  // or from a freshly-fetched ProductDetailScreen instance — default identity
  // equality would treat those as two different listings.
  @override
  bool operator ==(Object other) => other is MarketplaceListing && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// GET /marketplace/:id — everything [MarketplaceListing] has, plus the
/// fields only worth fetching for a single product detail view.
class MarketplaceListingDetail {
  const MarketplaceListingDetail({
    required this.id,
    required this.name,
    required this.category,
    required this.freshnessScore,
    required this.pricePerUnit,
    required this.unit,
    required this.farmerName,
    this.farmerId,
    this.farmerRegion,
    this.quantityAvailable,
    this.shelfLifeDays,
    this.imageUrl,
  });

  final String id;
  final String name;
  final ProduceCategory category;
  final int freshnessScore;
  final double pricePerUnit;
  final String unit;
  final String farmerName;
  final String? farmerId;
  final String? farmerRegion;
  final double? quantityAvailable;
  final int? shelfLifeDays;
  final String? imageUrl;
}

extension MarketplaceListingDetailX on MarketplaceListingDetail {
  /// For handing off to the cart/checkout flow, which only needs the
  /// [MarketplaceListing] subset of these fields.
  MarketplaceListing toMarketplaceListing() {
    return MarketplaceListing(
      id: id,
      name: name,
      category: category,
      freshnessScore: freshnessScore,
      pricePerUnit: pricePerUnit,
      unit: unit,
      farmerName: farmerName,
      farmerId: farmerId,
      quantityAvailable: quantityAvailable,
      imageUrl: imageUrl,
    );
  }
}
