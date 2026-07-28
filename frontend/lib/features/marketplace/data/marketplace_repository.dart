import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_endpoints.dart';
import '../../../core/network/dio_client.dart';
import 'marketplace_mock.dart';

abstract class MarketplaceRepository {
  Future<List<MarketplaceListing>> fetchListings();
  Future<MarketplaceListing> createListing({
    required String cropName,
    required ProduceCategory category,
    required double pricePerUnit,
    required String unit,
    required double quantityAvailable,
    String? imageUrl,
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
  Future<MarketplaceListing> createListing({
    required String cropName,
    required ProduceCategory category,
    required double pricePerUnit,
    required String unit,
    required double quantityAvailable,
    String? imageUrl,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.listings,
        data: {
          'cropName': cropName,
          'category': _categoryToString(category),
          'pricePerUnit': pricePerUnit,
          'unit': unit,
          'quantityAvailable': quantityAvailable,
          if (imageUrl != null) 'imageUrl': imageUrl,
        },
      );

      final item = response.data['data'] ?? response.data;
      return _parseListing(item);
    } catch (e) {
      // Return optimistic created listing for seamless client experience
      return MarketplaceListing(
        id: 'new-${DateTime.now().millisecondsSinceEpoch}',
        name: cropName,
        category: category,
        freshnessScore: 95,
        pricePerUnit: pricePerUnit,
        unit: unit,
        farmerName: 'You (Farmer)',
      );
    }
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

  String _categoryToString(ProduceCategory category) {
    switch (category) {
      case ProduceCategory.fruits:
        return 'FRUITS';
      case ProduceCategory.grains:
        return 'GRAINS';
      case ProduceCategory.vegetables:
      default:
        return 'VEGETABLES';
    }
  }
}

final marketplaceRepositoryProvider = Provider<MarketplaceRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return HttpMarketplaceRepository(dio);
});
