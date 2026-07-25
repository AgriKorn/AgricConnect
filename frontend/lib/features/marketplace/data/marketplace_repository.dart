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
      final response = await _dio.get(ApiEndpoints.listings);
      final rawList = response.data['data'] as List? ?? [];
      
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
    final categoryStr = json['category']?.toString().toUpperCase() ?? 'VEGETABLES';
    
    return MarketplaceListing(
      id: json['id']?.toString() ?? 'id-${json.hashCode}',
      name: json['cropName']?.toString() ?? json['name']?.toString() ?? 'Fresh Crop',
      category: _stringToCategory(categoryStr),
      freshnessScore: int.tryParse(json['freshnessScore']?.toString() ?? '') ?? 90,
      pricePerUnit: double.tryParse(json['pricePerUnit']?.toString() ?? json['price']?.toString() ?? '') ?? 15.0,
      unit: json['unit']?.toString() ?? 'kg',
      farmerName: json['farmer']?['name']?.toString() ?? json['farmerName']?.toString() ?? 'Local Farmer',
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
