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
    required this.hasOwnTransport,
    this.farmerId,
    this.farmerName,
    this.buyerName,
    this.driverName,
    this.driverPhone,
  });

  final String id;
  final String listingName;
  final double amount;
  final String status;
  final DateTime createdAt;
  final bool hasOwnTransport;
  final String? farmerId;
  final String? farmerName;
  /// Set when the signed-in user is the farmer on this order — who bought it.
  final String? buyerName;
  final String? driverName;
  final String? driverPhone;
}

class PurchaseResult {
  const PurchaseResult({
    required this.transactionId,
    required this.amount,
    required this.hasOwnTransport,
    required this.authorizationUrl,
  });

  final String transactionId;
  final double amount;
  final bool hasOwnTransport;
  final String authorizationUrl;
}

abstract class OrdersRepository {
  Future<PurchaseResult> purchaseListing({
    required String listingId,
    required bool hasOwnTransport,
  });

  Future<List<OrderItemModel>> fetchUserOrders();

  Future<void> confirmDelivery({required String transactionId, required String qrHash});

  Future<void> raiseDispute({
    required String transactionId,
    required String type,
    required String description,
  });
}

class HttpOrdersRepository implements OrdersRepository {
  HttpOrdersRepository(this._dio);

  final Dio _dio;

  @override
  Future<PurchaseResult> purchaseListing({
    required String listingId,
    required bool hasOwnTransport,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.transactionPurchase,
        data: {
          'listingId': listingId,
          'hasOwnTransport': hasOwnTransport,
        },
      );

      final data = response.data['data'] ?? response.data;
      final transaction = data['transaction'] ?? {};
      return PurchaseResult(
        transactionId: transaction['id']?.toString() ?? '',
        amount: double.tryParse(transaction['amountGhs']?.toString() ?? '') ?? 0.0,
        hasOwnTransport: transaction['hasOwnTransport'] as bool? ?? hasOwnTransport,
        authorizationUrl: data['authorizationUrl']?.toString() ?? '',
      );
    } on DioException catch (e) {
      final serverMessage = e.response?.data?['error']?['message']?.toString();
      throw ApiException(serverMessage ?? e.message ?? 'Failed to complete purchase.');
    }
  }

  @override
  Future<List<OrderItemModel>> fetchUserOrders() async {
    try {
      final response = await _dio.get(ApiEndpoints.transactions);
      final rawList = response.data['data']?['transactions'] as List? ?? [];

      return rawList.map((item) => OrderItemModel(
        id: item['id']?.toString() ?? '',
        listingName: item['cropType']?.toString() ?? 'Produce Order',
        amount: double.tryParse(item['amountGhs']?.toString() ?? '') ?? 0.0,
        status: item['status']?.toString() ?? 'PAYMENT_HELD',
        createdAt: DateTime.tryParse(item['createdAt']?.toString() ?? '') ?? DateTime.now(),
        hasOwnTransport: item['hasOwnTransport'] == true,
        farmerId: item['farmerId']?.toString(),
        farmerName: item['farmerName']?.toString(),
        buyerName: item['buyerName']?.toString(),
        driverName: item['driverName']?.toString(),
        driverPhone: item['driverPhone']?.toString(),
      )).toList();
    } on DioException catch (e) {
      // Swallowing this to `[]` used to make a failed fetch indistinguishable
      // from "genuinely no orders yet" — both the buyer's Orders screen and
      // the farmer's My Sales screen already have a real error state built
      // for ordersAsync, it just never fired.
      String? serverMessage;
      final responseData = e.response?.data;
      if (responseData is Map) {
        serverMessage = responseData['error']?['message']?.toString();
      }
      throw ApiException(serverMessage ?? e.message ?? 'Failed to load orders.');
    }
  }

  @override
  Future<void> confirmDelivery({required String transactionId, required String qrHash}) async {
    try {
      await _dio.post('${ApiEndpoints.transactions}/$transactionId/confirm-delivery', data: {'qrHash': qrHash});
    } on DioException catch (e) {
      final serverMessage = e.response?.data?['error']?['message']?.toString();
      throw ApiException(serverMessage ?? e.message ?? 'Failed to confirm delivery.');
    }
  }

  @override
  Future<void> raiseDispute({
    required String transactionId,
    required String type,
    required String description,
  }) async {
    try {
      await _dio.post(ApiEndpoints.disputes, data: {
        'transactionId': transactionId,
        'type': type,
        'description': description,
      });
    } on DioException catch (e) {
      final serverMessage = e.response?.data?['error']?['message']?.toString();
      throw ApiException(serverMessage ?? e.message ?? 'Failed to submit dispute.');
    }
  }
}

final ordersRepositoryProvider = Provider<OrdersRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return HttpOrdersRepository(dio);
});
