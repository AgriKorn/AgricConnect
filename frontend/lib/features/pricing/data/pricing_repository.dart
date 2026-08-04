import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';

/// Mirrors the backend's `PriceRecommendation` (pricing.service.ts) — only
/// the fields the app currently consumes; `decayProjection` isn't used yet.
class PriceRecommendation {
  const PriceRecommendation({
    required this.mofaPrice,
    required this.ceiling,
    required this.softFloor,
  });

  /// The real MOFA reference price per kg for this crop/region.
  final double mofaPrice;

  /// mofaPrice scaled by freshness — what the backend recommends listing at.
  final double ceiling;

  /// mofaPrice * 0.6 — a floor below which a farmer must explicitly
  /// acknowledge undercutting (see produce_listings.below_floor_acknowledged).
  final double softFloor;

  factory PriceRecommendation.fromJson(Map<String, dynamic> json) {
    return PriceRecommendation(
      mofaPrice: (json['mofaPrice'] as num).toDouble(),
      ceiling: (json['ceiling'] as num).toDouble(),
      softFloor: (json['softFloor'] as num).toDouble(),
    );
  }
}

/// Backend contract (verified, not illustrative — see
/// backend/src/modules/pricing/pricing.service.ts +
/// pricing.schema.ts): GET /pricing/recommend?crop&region&freshness&shelfLifeDays.
/// Requires a MOFA reference price to exist for the given crop+region, or
/// the backend 404s (NotFoundError) — callers should treat any failure here
/// as "no real recommendation available" and fall back to a local estimate,
/// same as this app's other offline-degradation paths (PRD 7.1).
abstract class PricingRepository {
  Future<PriceRecommendation> recommend({
    required String crop,
    required String region,
    required double freshness,
    int? shelfLifeDays,
  });
}

class HttpPricingRepository implements PricingRepository {
  HttpPricingRepository(this._dio);

  final Dio _dio;

  @override
  Future<PriceRecommendation> recommend({
    required String crop,
    required String region,
    required double freshness,
    int? shelfLifeDays,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.pricingRecommend,
        queryParameters: {
          'crop': crop,
          'region': region,
          'freshness': freshness,
          'shelfLifeDays': ?shelfLifeDays,
        },
      );
      return PriceRecommendation.fromJson(response.data!);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError || e.type == DioExceptionType.connectionTimeout) {
        throw const NoConnectionException();
      }
      final message = (e.response?.data is Map) ? e.response?.data['message'] as String? : null;
      throw ApiException(message ?? 'Could not fetch a price recommendation.');
    }
  }
}

final pricingRepositoryProvider = Provider<PricingRepository>((ref) {
  return HttpPricingRepository(ref.watch(dioProvider));
});
