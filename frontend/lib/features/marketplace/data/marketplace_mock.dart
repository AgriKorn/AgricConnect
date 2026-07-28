import 'package:flutter/material.dart';

/// Mock data standing in for the real Listing Search endpoint until its
/// backend contract is confirmed — same "build against a mock first"
/// pattern used throughout the checklist (see features/home/data).
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
    this.imageAsset,
  });

  final String id;
  final String name;
  final ProduceCategory category;
  final int freshnessScore;
  final double pricePerUnit;
  final String unit;
  final String farmerName;
  final String? imageAsset;
}

const mockMarketplaceListings = [
  MarketplaceListing(
    id: 'mp1',
    name: 'Organic Tomatoes',
    category: ProduceCategory.vegetables,
    freshnessScore: 96,
    pricePerUnit: 18,
    unit: 'kg',
    farmerName: 'Ama Boateng',
    imageAsset: 'assets/images/roma tomatoes.png',
  ),
  MarketplaceListing(
    id: 'mp2',
    name: 'Sweet Bell Peppers',
    category: ProduceCategory.vegetables,
    freshnessScore: 92,
    pricePerUnit: 22,
    unit: 'kg',
    farmerName: 'Kojo Mensah',
    imageAsset: 'assets/images/belll pepper.png',
  ),
  MarketplaceListing(
    id: 'mp3',
    name: 'Fresh Spinach',
    category: ProduceCategory.vegetables,
    freshnessScore: 85,
    pricePerUnit: 12,
    unit: 'bunch',
    farmerName: 'Efua Asante',
    imageAsset: 'assets/images/freah_spinach.webp',
  ),
  MarketplaceListing(
    id: 'mp4',
    name: 'Golden Pineapple',
    category: ProduceCategory.fruits,
    freshnessScore: 76,
    pricePerUnit: 15,
    unit: 'piece',
    farmerName: 'Yaw Owusu',
    imageAsset: 'assets/images/golden_pineapples.webp',
  ),
  MarketplaceListing(
    id: 'mp5',
    name: 'White Onions',
    category: ProduceCategory.vegetables,
    freshnessScore: 95,
    pricePerUnit: 14,
    unit: 'kg',
    farmerName: 'Abena Darko',
    imageAsset: 'assets/images/White_onion.webp',
  ),
  MarketplaceListing(
    id: 'mp6',
    name: 'Carrots (Bulk)',
    category: ProduceCategory.vegetables,
    freshnessScore: 89,
    pricePerUnit: 16,
    unit: 'kg',
    farmerName: 'Kwame Adjei',
    imageAsset: 'assets/images/carrots.jpg',
  ),
  MarketplaceListing(
    id: 'mp7',
    name: 'Ripe Mangoes',
    category: ProduceCategory.fruits,
    freshnessScore: 91,
    pricePerUnit: 20,
    unit: 'kg',
    farmerName: 'Adjoa Frimpong',
    imageAsset: 'assets/images/riped_mangoes.webp',
  ),
  MarketplaceListing(
    id: 'mp8',
    name: 'White Maize',
    category: ProduceCategory.grains,
    freshnessScore: 88,
    pricePerUnit: 9,
    unit: 'kg',
    farmerName: 'Kwabena Osei',
    imageAsset: 'assets/images/white_maize.jpg',
  ),
];
