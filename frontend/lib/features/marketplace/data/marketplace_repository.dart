import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../../home/data/farmer_dashboard_mock.dart';
import 'marketplace_mock.dart';

/// Approximate regional-capital coordinates, used as the listing's location
/// until real GPS capture is wired up — tied to the farmer's own registered
/// region (from their profile), not arbitrary.
const _regionCoordinates = {
  'Greater Accra': (5.6037, -0.1870),
  'Ashanti': (6.6885, -1.6244),
  'Northern': (9.4008, -0.8393),
  'Eastern': (6.0940, -0.2591),
  'Western': (4.9346, -1.7137),
  'Brong-Ahafo': (7.7398, -2.3237),
};

(double, double) coordinatesForRegion(String? region) {
  return _regionCoordinates[region] ?? _regionCoordinates['Greater Accra']!;
}

abstract class MarketplaceRepository {
  Future<List<MarketplaceListing>> fetchListings();
  Future<List<FarmerListingSummary>> fetchMyListings();
  Future<FarmerListingSummary> createListing({
    required String cropType,
    required double quantityKg,
    required int freshnessScore,
    required int shelfLifeDays,
    required double farmerLat,
    required double farmerLong,
    required double pricePerKg,
  });
}

class HttpMarketplaceRepository implements MarketplaceRepository {
  HttpMarketplaceRepository(this._dio);

  final Dio _dio;

  @override
  Future<List<MarketplaceListing>> fetchListings() async {
    try {
      final response = await _dio.get(ApiEndpoints.marketplace);
      final data = response.data['data'];
      final rawList = data?['listings'] as List? ?? [];

      if (rawList.isEmpty) {
        return mockMarketplaceListings;
      }

      return rawList.map((item) => _parseListing(item)).toList();
    } catch (_) {
      // Fallback to initial seed mock listings if network is offline
      return mockMarketplaceListings;
    }
  }

  @override
  Future<List<FarmerListingSummary>> fetchMyListings() async {
    try {
      final response = await _dio.get(ApiEndpoints.listings);
      final rawList = response.data['data']?['listings'] as List? ?? [];
      return rawList.map((item) => _parseFarmerListing(item)).toList();
    } on DioException catch (e) {
      throw ApiException(e.message ?? 'Failed to load your listings.');
    }
  }

  @override
  Future<FarmerListingSummary> createListing({
    required String cropType,
    required double quantityKg,
    required int freshnessScore,
    required int shelfLifeDays,
    required double farmerLat,
    required double farmerLong,
    required double pricePerKg,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.listings,
        data: {
          'cropType': cropType,
          'quantityKg': quantityKg,
          'freshnessScore': freshnessScore,
          'shelfLifeDays': shelfLifeDays,
          'farmerLat': farmerLat,
          'farmerLong': farmerLong,
          'pricePerKg': pricePerKg,
        },
      );
      final item = response.data['data'] ?? response.data;
      return _parseFarmerListing(item);
    } on DioException catch (e) {
      final serverMessage = e.response?.data?['error']?['message']?.toString();
      throw ApiException(serverMessage ?? e.message ?? 'Failed to create listing.');
    }
  }

  FarmerListingSummary _parseFarmerListing(dynamic json) {
    final cropType = json['cropType']?.toString() ?? 'crop';
    final statusStr = json['status']?.toString().toUpperCase() ?? 'ACTIVE';
    return FarmerListingSummary(
      id: json['id']?.toString() ?? '',
      cropType: cropType.isEmpty ? cropType : cropType[0].toUpperCase() + cropType.substring(1),
      freshnessScore: double.tryParse(json['freshnessScore']?.toString() ?? '')?.round() ?? 0,
      price: double.tryParse(json['pricePerKg']?.toString() ?? '') ?? 0,
      unit: 'kg',
      status: switch (statusStr) {
        'SOLD' => 'Sold',
        'INACTIVE' => 'Pending',
        _ => 'Active',
      },
    );
  }

  MarketplaceListing _parseListing(dynamic json) {
    final cropType = json['cropType']?.toString() ?? 'crop';

    return MarketplaceListing(
      id: json['id']?.toString() ?? 'id-${json.hashCode}',
      name: cropType[0].toUpperCase() + cropType.substring(1),
      category: _stringToCategory(cropType.toUpperCase()),
      freshnessScore: double.tryParse(json['freshnessScore']?.toString() ?? '')?.round() ?? 90,
      pricePerUnit: double.tryParse(json['pricePerKg']?.toString() ?? '') ?? 15.0,
      unit: 'kg',
      farmerName: json['farmerName']?.toString() ?? 'Local Farmer',
      farmerId: json['farmerId']?.toString(),
      quantityAvailable: double.tryParse(json['quantityKg']?.toString() ?? ''),
    );
  }

  ProduceCategory _stringToCategory(String str) {
    switch (str) {
      case 'FRUITS':
      case 'FRUIT':
        return ProduceCategory.fruits;
      case 'GRAINS':
      case 'GRAIN':
        return ProduceCategory.grains;
      case 'VEGETABLES':
      case 'VEGETABLE':
      default:
        return ProduceCategory.vegetables;
    }
  }
}

final marketplaceRepositoryProvider = Provider<MarketplaceRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return HttpMarketplaceRepository(dio);
});
