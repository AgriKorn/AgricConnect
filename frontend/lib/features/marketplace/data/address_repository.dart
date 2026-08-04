import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';

class DeliveryAddress {
  const DeliveryAddress({
    required this.id,
    required this.label,
    required this.addressLine,
    this.region,
    this.isDefault = false,
  });

  final String id;
  final String label;
  final String addressLine;
  final String? region;
  final bool isDefault;

  factory DeliveryAddress.fromJson(Map<String, dynamic> json) => DeliveryAddress(
    id: json['id']?.toString() ?? '',
    label: json['label']?.toString() ?? '',
    addressLine: json['addressLine']?.toString() ?? '',
    region: json['region']?.toString(),
    isDefault: json['isDefault'] as bool? ?? false,
  );
}

abstract class AddressRepository {
  Future<List<DeliveryAddress>> fetchAddresses();
  Future<DeliveryAddress> createAddress({required String label, required String addressLine, String? region, bool isDefault = false});
  Future<DeliveryAddress> updateAddress(String id, {String? label, String? addressLine, String? region, bool? isDefault});
  Future<void> deleteAddress(String id);
}

class HttpAddressRepository implements AddressRepository {
  HttpAddressRepository(this._dio);

  final Dio _dio;

  @override
  Future<List<DeliveryAddress>> fetchAddresses() async {
    try {
      final response = await _dio.get(ApiEndpoints.userAddresses);
      final rawList = response.data['data']?['addresses'] as List? ?? [];
      return rawList.map((item) => DeliveryAddress.fromJson((item as Map).cast<String, dynamic>())).toList();
    } on DioException catch (e) {
      throw ApiException(_extractErrorMessage(e));
    }
  }

  @override
  Future<DeliveryAddress> createAddress({
    required String label,
    required String addressLine,
    String? region,
    bool isDefault = false,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.userAddresses,
        data: {
          'label': label,
          'addressLine': addressLine,
          if (region != null && region.isNotEmpty) 'region': region,
          'isDefault': isDefault,
        },
      );
      final data = response.data['data'] ?? response.data;
      return DeliveryAddress.fromJson((data as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      throw ApiException(_extractErrorMessage(e));
    }
  }

  @override
  Future<DeliveryAddress> updateAddress(
    String id, {
    String? label,
    String? addressLine,
    String? region,
    bool? isDefault,
  }) async {
    try {
      final response = await _dio.patch(
        '${ApiEndpoints.userAddresses}/$id',
        data: {
          if (label != null) 'label': label,
          if (addressLine != null) 'addressLine': addressLine,
          if (region != null) 'region': region,
          if (isDefault != null) 'isDefault': isDefault,
        },
      );
      final data = response.data['data'] ?? response.data;
      return DeliveryAddress.fromJson((data as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      throw ApiException(_extractErrorMessage(e));
    }
  }

  @override
  Future<void> deleteAddress(String id) async {
    try {
      await _dio.delete('${ApiEndpoints.userAddresses}/$id');
    } on DioException catch (e) {
      throw ApiException(_extractErrorMessage(e));
    }
  }

  String _extractErrorMessage(DioException error) {
    final data = error.response?.data;
    if (data is Map && data['error'] is Map) {
      return (data['error']['message'] ?? 'Something went wrong.').toString();
    }
    return error.message ?? 'Something went wrong.';
  }
}

final addressRepositoryProvider = Provider<AddressRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return HttpAddressRepository(dio);
});
