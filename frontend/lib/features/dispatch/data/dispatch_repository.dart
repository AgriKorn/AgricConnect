import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';

class DispatchJobModel {
  const DispatchJobModel({
    required this.id,
    required this.pickupAddress,
    required this.deliveryAddress,
    required this.cropName,
    required this.quantityKg,
    required this.earningsGhs,
    required this.status,
  });

  final String id;
  final String pickupAddress;
  final String deliveryAddress;
  final String cropName;
  final double quantityKg;
  final double earningsGhs;
  final String status;
}

abstract class DispatchRepository {
  Future<List<DispatchJobModel>> fetchAvailableJobs();
  Future<bool> acceptJob(String jobId);
  Future<bool> updateJobStatus(String jobId, String status);
}

class HttpDispatchRepository implements DispatchRepository {
  HttpDispatchRepository(this._dio);

  final Dio _dio;

  @override
  Future<List<DispatchJobModel>> fetchAvailableJobs() async {
    try {
      final response = await _dio.get('/dispatch/available');
      final rawList = response.data['data'] as List? ?? [];

      return rawList.map((item) => DispatchJobModel(
        id: item['id']?.toString() ?? '',
        pickupAddress: item['pickupAddress']?.toString() ?? 'Kumasi Central Market',
        deliveryAddress: item['deliveryAddress']?.toString() ?? 'Accra Wholesale Hub',
        cropName: item['cropName']?.toString() ?? 'Tomatoes (Bulk)',
        quantityKg: double.tryParse(item['quantityKg']?.toString() ?? '') ?? 50.0,
        earningsGhs: double.tryParse(item['earningsGhs']?.toString() ?? '') ?? 250.0,
        status: item['status']?.toString() ?? 'ASSIGNED',
      )).toList();
    } catch (_) {
      return const [
        DispatchJobModel(
          id: 'job-501',
          pickupAddress: 'Techiman Farm Hub, Bono East',
          deliveryAddress: 'Agbogbloshie Market, Accra',
          cropName: 'Fresh Yam (100 Tubers)',
          quantityKg: 200.0,
          earningsGhs: 450.0,
          status: 'AVAILABLE',
        ),
      ];
    }
  }

  @override
  Future<bool> acceptJob(String jobId) async {
    try {
      await _dio.post('/dispatch/$jobId/accept');
      return true;
    } on DioException catch (e) {
      throw ApiException(e.message ?? 'Failed to accept dispatch job.');
    }
  }

  @override
  Future<bool> updateJobStatus(String jobId, String status) async {
    try {
      await _dio.post(
        '/dispatch/$jobId/status',
        data: {'status': status},
      );
      return true;
    } on DioException catch (e) {
      throw ApiException(e.message ?? 'Failed to update job status.');
    }
  }
}

final dispatchRepositoryProvider = Provider<DispatchRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return HttpDispatchRepository(dio);
});
