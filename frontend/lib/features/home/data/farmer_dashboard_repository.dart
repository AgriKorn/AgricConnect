import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';

/// Real farmer dashboard/profile numbers from GET /dashboard/farmer-summary
/// — replaces the old hardcoded mock that showed the same fake figures to
/// every farmer. marketTrendPercent is null (not 0) until there's enough
/// MOFA reference-price history to compute a real trend from.
class FarmerDashboardSummary {
  const FarmerDashboardSummary({
    required this.location,
    required this.todaysEarningsGhs,
    required this.totalEarningsGhs,
    required this.activeOrders,
    required this.salesCount,
    required this.primaryCrops,
    required this.marketTrendPercent,
  });

  final String location;
  final double todaysEarningsGhs;
  final double totalEarningsGhs;
  final int activeOrders;
  final int salesCount;
  final List<String> primaryCrops;
  final double? marketTrendPercent;

  factory FarmerDashboardSummary.fromJson(Map<String, dynamic> json) {
    return FarmerDashboardSummary(
      location: json['location']?.toString() ?? 'Ghana',
      todaysEarningsGhs: double.tryParse(json['todaysEarningsGhs']?.toString() ?? '') ?? 0,
      totalEarningsGhs: double.tryParse(json['totalEarningsGhs']?.toString() ?? '') ?? 0,
      activeOrders: int.tryParse(json['activeOrders']?.toString() ?? '') ?? 0,
      salesCount: int.tryParse(json['salesCount']?.toString() ?? '') ?? 0,
      primaryCrops: (json['primaryCrops'] as List?)?.map((c) => c.toString()).toList() ?? const [],
      marketTrendPercent: json['marketTrendPercent'] == null
          ? null
          : double.tryParse(json['marketTrendPercent'].toString()),
    );
  }
}

abstract class FarmerDashboardRepository {
  Future<FarmerDashboardSummary> fetchSummary();
}

class HttpFarmerDashboardRepository implements FarmerDashboardRepository {
  HttpFarmerDashboardRepository(this._dio);

  final Dio _dio;

  @override
  Future<FarmerDashboardSummary> fetchSummary() async {
    try {
      final response = await _dio.get('/dashboard/farmer-summary');
      final data = response.data['data'] ?? response.data;
      return FarmerDashboardSummary.fromJson(data as Map<String, dynamic>);
    } on DioException catch (e) {
      String? serverMessage;
      final responseData = e.response?.data;
      if (responseData is Map) {
        serverMessage = responseData['error']?['message']?.toString();
      }
      throw ApiException(serverMessage ?? e.message ?? 'Failed to load dashboard summary.');
    }
  }
}

final farmerDashboardRepositoryProvider = Provider<FarmerDashboardRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return HttpFarmerDashboardRepository(dio);
});
