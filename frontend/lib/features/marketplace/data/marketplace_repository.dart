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

  /// GET /marketplace/:id — full detail (farmer name/region, quantity,
  /// shelf life) for the product detail screen.
  Future<MarketplaceListingDetail> fetchListingDetail(String id);

  Future<List<FarmerListingSummary>> fetchMyListings();
  Future<FarmerListingSummary> createListing({
    required String cropType,
    required double quantityKg,
    required int freshnessScore,
    required int shelfLifeDays,
    required double farmerLat,
    required double farmerLong,
    required double pricePerKg,
    String? imageUrl,
    String? description,
  });

  /// Uploads [bytes] to S3 via a presigned URL and returns the resulting
  /// public photo URL — caller still has to pass it to [createListing].
  Future<String> uploadListingPhoto({
    required List<int> bytes,
    required String fileName,
    required String contentType,
  });

  /// Soft-deletes the listing — DELETE /listings/:id.
  Future<void> deleteListing(String id);
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
      return rawList.map((item) => _parseListing(item)).toList();
    } on DioException catch (e) {
      final serverMessage = e.response?.data?['error']?['message']?.toString();
      throw ApiException(serverMessage ?? e.message ?? 'Failed to load the marketplace.');
    }
  }

  @override
  Future<MarketplaceListingDetail> fetchListingDetail(String id) async {
    try {
      final response = await _dio.get('${ApiEndpoints.marketplace}/$id');
      final item = response.data['data'] ?? response.data;
      return _parseListingDetail(item);
    } on DioException catch (e) {
      final serverMessage = e.response?.data?['error']?['message']?.toString();
      throw ApiException(serverMessage ?? e.message ?? 'Failed to load this listing.');
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
    String? imageUrl,
    String? description,
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
          if (imageUrl != null) 'imageUrl': imageUrl,
          if (description != null && description.trim().isNotEmpty) 'description': description.trim(),
        },
      );
      final item = response.data['data'] ?? response.data;
      return _parseFarmerListing(item);
    } on DioException catch (e) {
      final serverMessage = e.response?.data?['error']?['message']?.toString();
      throw ApiException(serverMessage ?? e.message ?? 'Failed to create listing.');
    }
  }

  @override
  Future<String> uploadListingPhoto({
    required List<int> bytes,
    required String fileName,
    required String contentType,
  }) async {
    try {
      final urlResponse = await _dio.post(
        '/listings/photo-upload-url',
        data: {'fileName': fileName, 'contentType': contentType},
      );
      final urlData = urlResponse.data['data'] ?? urlResponse.data;
      final uploadUrl = urlData['uploadUrl']?.toString() ?? '';
      final publicUrl = urlData['publicUrl']?.toString() ?? '';
      if (uploadUrl.isEmpty || publicUrl.isEmpty) {
        throw const ApiException('Could not get a photo upload URL.');
      }

      await Dio().put<void>(
        uploadUrl,
        data: Stream.fromIterable([bytes]),
        options: Options(headers: {'Content-Type': contentType, 'content-length': bytes.length}),
      );

      return publicUrl;
    } on DioException catch (e) {
      final serverMessage = e.response?.data?['error']?['message']?.toString();
      throw ApiException(serverMessage ?? e.message ?? 'Failed to upload photo.');
    }
  }

  @override
  Future<void> deleteListing(String id) async {
    try {
      await _dio.delete('${ApiEndpoints.listings}/$id');
    } on DioException catch (e) {
      final serverMessage = e.response?.data?['error']?['message']?.toString();
      throw ApiException(serverMessage ?? e.message ?? 'Failed to delete listing.');
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
      qrCodeData: json['qrCodeData']?.toString(),
      imageUrl: json['imageUrl']?.toString(),
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
      imageUrl: json['imageUrl']?.toString(),
    );
  }

  MarketplaceListingDetail _parseListingDetail(dynamic json) {
    final cropType = json['cropType']?.toString() ?? 'crop';

    return MarketplaceListingDetail(
      id: json['id']?.toString() ?? '',
      name: cropType.isEmpty ? cropType : cropType[0].toUpperCase() + cropType.substring(1),
      category: _stringToCategory((json['cropCategory'] ?? cropType).toString().toUpperCase()),
      freshnessScore: double.tryParse(json['freshnessScore']?.toString() ?? '')?.round() ?? 0,
      pricePerUnit: double.tryParse(json['pricePerKg']?.toString() ?? '') ?? 0,
      unit: 'kg',
      quantityAvailable: double.tryParse(json['quantityKg']?.toString() ?? ''),
      shelfLifeDays: int.tryParse(json['shelfLifeDays']?.toString() ?? ''),
      imageUrl: json['imageUrl']?.toString(),
      farmerName: json['farmerName']?.toString() ?? 'Local Farmer',
      farmerId: json['farmerId']?.toString(),
      farmerRegion: json['farmerRegion']?.toString(),
      description: json['description']?.toString(),
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
