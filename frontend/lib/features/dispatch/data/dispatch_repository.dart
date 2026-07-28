import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';

class DispatchJobModel {
  const DispatchJobModel({
    required this.id,
    required this.transactionId,
    required this.cropType,
    required this.quantityKg,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String transactionId;
  final String cropType;
  final double quantityKg;
  final String status;
  final DateTime createdAt;

  factory DispatchJobModel.fromJson(Map<String, dynamic> json) {
    return DispatchJobModel(
      id: json['id']?.toString() ?? '',
      transactionId: json['transactionId']?.toString() ?? '',
      cropType: json['cropType']?.toString() ?? 'Produce',
      quantityKg: double.tryParse(json['quantityKg']?.toString() ?? '') ?? 0.0,
      status: json['status']?.toString() ?? 'PENDING',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

abstract class DispatchRepository {
  Future<List<DispatchJobModel>> fetchJobs({String? status});
  Future<void> acceptJob(String jobId);
  Future<void> declineJob(String jobId);
  Future<bool> fetchIsAvailable();
  Future<void> setAvailability(bool isAvailable);
}

class HttpDispatchRepository implements DispatchRepository {
  HttpDispatchRepository(this._dio);

  final Dio _dio;

  @override
  Future<List<DispatchJobModel>> fetchJobs({String? status}) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.dispatchJobs,
        queryParameters: status == null ? null : {'status': status},
      );
      final rawList = response.data['data']?['jobs'] as List? ?? [];
      return rawList.map((item) => DispatchJobModel.fromJson(item as Map<String, dynamic>)).toList();
    } on DioException {
      return const [];
    }
  }

  @override
  Future<void> acceptJob(String jobId) async {
    try {
      await _dio.patch('/dispatch/$jobId/accept');
    } on DioException catch (e) {
      final serverMessage = e.response?.data?['error']?['message']?.toString();
      throw ApiException(serverMessage ?? e.message ?? 'Failed to accept job.');
    }
  }

  @override
  Future<void> declineJob(String jobId) async {
    try {
      await _dio.patch('/dispatch/$jobId/decline');
    } on DioException catch (e) {
      final serverMessage = e.response?.data?['error']?['message']?.toString();
      throw ApiException(serverMessage ?? e.message ?? 'Failed to decline job.');
    }
  }

  @override
  Future<bool> fetchIsAvailable() async {
    try {
      final response = await _dio.get(ApiEndpoints.userProfile);
      final data = response.data['data'] ?? response.data;
      return data['profile']?['isAvailable'] as bool? ?? true;
    } on DioException {
      return true;
    }
  }

  @override
  Future<void> setAvailability(bool isAvailable) async {
    try {
      await _dio.patch(ApiEndpoints.userProfile, data: {'isAvailable': isAvailable});
    } on DioException catch (e) {
      throw ApiException(e.message ?? 'Failed to update availability.');
    }
  }
}

final dispatchRepositoryProvider = Provider<DispatchRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return HttpDispatchRepository(dio);
});
