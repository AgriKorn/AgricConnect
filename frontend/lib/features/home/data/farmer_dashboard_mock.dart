import 'package:flutter/material.dart';

/// Mock data standing in for the real endpoints (Dashboard summary, Listing
/// search / My Listings) until their backend contracts are confirmed — same
/// "build against a mock first" pattern used throughout the checklist.
class FarmerDashboardSummary {
  const FarmerDashboardSummary({
    required this.location,
    required this.weatherTempC,
    required this.weatherIcon,
    required this.marketTrendPercent,
    required this.todaysEarnings,
    required this.activeOrders,
    required this.profileViews,
  });

  final String location;
  final int weatherTempC;
  final IconData weatherIcon;
  final double marketTrendPercent;
  final double todaysEarnings;
  final int activeOrders;
  final int profileViews;
}

const mockDashboardSummary = FarmerDashboardSummary(
  location: 'Kumasi, GH',
  weatherTempC: 28,
  weatherIcon: Icons.wb_sunny_rounded,
  marketTrendPercent: 12.5,
  todaysEarnings: 1240,
  activeOrders: 14,
  profileViews: 128,
);

class FarmerProfileDetails {
  const FarmerProfileDetails({
    required this.rating,
    required this.salesCount,
    required this.location,
    required this.primaryCrops,
    required this.walletBalance,
  });

  final double rating;
  final int salesCount;
  final String location;
  final List<String> primaryCrops;
  final double walletBalance;
}

const mockFarmerProfileDetails = FarmerProfileDetails(
  rating: 4.9,
  salesCount: 128,
  location: 'Ejura, Ashanti Region',
  primaryCrops: ['Maize', 'Yam', 'Cassava'],
  walletBalance: 4250,
);

class FarmerListingSummary {
  const FarmerListingSummary({
    required this.id,
    required this.cropType,
    required this.freshnessScore,
    required this.price,
    required this.unit,
    required this.status,
    this.imageAsset,
    this.imagePath,
  });

  final String id;
  final String cropType;
  final int freshnessScore;
  final double price;
  final String unit;
  final String status; // Active | Pending | Sold
  final String? imageAsset; // bundled asset, used by mock listings
  final String? imagePath; // local file path, from a scan or user-picked photo
}

class FreshnessAlertItem {
  const FreshnessAlertItem({
    required this.listingId,
    required this.cropType,
    required this.hoursRemaining,
  });

  final String listingId;
  final String cropType;
  final int hoursRemaining;
}

const mockFarmerListings = [
  FarmerListingSummary(
    id: 'l1',
    cropType: 'Organic Roma Tomatoes',
    freshnessScore: 94,
    price: 35,
    unit: 'kg',
    status: 'Active',
    imageAsset: 'assets/images/roma tomatoes.png',
  ),
  FarmerListingSummary(
    id: 'l2',
    cropType: 'Sweet Yellow Maize',
    freshnessScore: 88,
    price: 25,
    unit: 'kg',
    status: 'Active',
    imageAsset: 'assets/images/yellow maize.png',
  ),
  FarmerListingSummary(
    id: 'l3',
    cropType: 'Haden Mangoes',
    freshnessScore: 91,
    price: 60,
    unit: 'box',
    status: 'Active',
    imageAsset: 'assets/images/haden mangoes.png',
  ),
  FarmerListingSummary(
    id: 'l4',
    cropType: 'Green Bell Peppers',
    freshnessScore: 82,
    price: 42,
    unit: 'kg',
    status: 'Active',
    imageAsset: 'assets/images/belll pepper.png',
  ),
  FarmerListingSummary(
    id: 'l5',
    cropType: 'Ripe Bananas',
    freshnessScore: 41,
    price: 15,
    unit: 'bunch',
    status: 'Active',
    imageAsset: 'assets/images/bananas.png',
  ),
  FarmerListingSummary(
    id: 'l6',
    cropType: 'Cassava',
    freshnessScore: 54,
    price: 18,
    unit: 'bag',
    status: 'Pending',
    imageAsset: 'assets/images/cassava.png',
  ),
  FarmerListingSummary(
    id: 'l7',
    cropType: 'Sweet Potatoes',
    freshnessScore: 76,
    price: 22,
    unit: 'bag',
    status: 'Sold',
    imageAsset: 'assets/images/sweet_potatoes.png',
  ),

];

const mockFreshnessAlerts = [
  FreshnessAlertItem(listingId: 'l5', cropType: 'Ripe Bananas', hoursRemaining: 6),
  FreshnessAlertItem(listingId: 'l6', cropType: 'Cassava', hoursRemaining: 14),
];
