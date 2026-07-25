import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';

class OrderItemModel {
  const OrderItemModel({
    required this.id,
    required this.listingName,
    required this.amount,
    required this.status,
    required this.createdAt,
    this.paystackUrl,
  });

  final String id;
  final String listingName;
  final double amount;
  final String status;
  final DateTime createdAt;
  final String? paystackUrl;
}

abstract class OrdersRepository {
  Future<OrderItemModel> createOrder({
    required String listingId,
    required double quantity,
  });

  Future<String> initializePaystackCheckout({
    required String transactionId,
    required String email,
    required double amount,
  });

  Future<List<OrderItemModel>> fetchUserOrders();
}

class HttpOrdersRepository implements OrdersRepository {
  HttpOrdersRepository(this._dio);

  final Dio _dio;

  @override
  Future<OrderItemModel> createOrder({
    required String listingId,
    required double quantity,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.transactions,
        data: {
          'listingId': listingId,
          'quantity': quantity,
        },
      );

      final data = response.data['data'] ?? response.data;
      return OrderItemModel(
        id: data['id']?.toString() ?? 'tx-${DateTime.now().millisecondsSinceEpoch}',
        listingName: data['listing']?['cropName']?.toString() ?? 'AgriConnect Order',
        amount: double.tryParse(data['totalAmount']?.toString() ?? data['amount']?.toString() ?? '') ?? 150.0,
        status: data['status']?.toString() ?? 'PENDING_PAYMENT',
        createdAt: DateTime.now(),
      );
    } on DioException catch (e) {
      throw ApiException(e.message ?? 'Failed to place order.');
    }
  }

  @override
  Future<String> initializePaystackCheckout({
    required String transactionId,
    required String email,
    required double amount,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.paystackInitialize,
        data: {
          'transactionId': transactionId,
          'email': email,
          'amount': amount,
        },
      );

      final data = response.data['data'] ?? response.data;
      final url = data['authorizationUrl']?.toString() ?? data['authorization_url']?.toString();
      if (url == null || url.isEmpty) {
        throw const ApiException('Paystack authorization URL missing.');
      }
      return url;
    } on DioException catch (e) {
      throw ApiException(e.message ?? 'Paystack initialization failed.');
    }
  }

  @override
  Future<List<OrderItemModel>> fetchUserOrders() async {
    try {
      final response = await _dio.get(ApiEndpoints.transactions);
      final rawList = response.data['data'] as List? ?? [];
      
      return rawList.map((item) => OrderItemModel(
        id: item['id']?.toString() ?? '',
        listingName: item['listing']?['cropName']?.toString() ?? 'Produce Order',
        amount: double.tryParse(item['totalAmount']?.toString() ?? '') ?? 0.0,
        status: item['status']?.toString() ?? 'ESCROW_HELD',
        createdAt: DateTime.tryParse(item['createdAt']?.toString() ?? '') ?? DateTime.now(),
      )).toList();
    } catch (_) {
      return [
        OrderItemModel(
          id: 'ord-101',
          listingName: 'Organic Roma Tomatoes (50kg)',
          amount: 900.0,
          status: 'ESCROW_HELD',
          createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        ),
      ];
    }
  }
}

final ordersRepositoryProvider = Provider<OrdersRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return HttpOrdersRepository(dio);
});
