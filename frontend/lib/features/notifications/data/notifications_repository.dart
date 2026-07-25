import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_endpoints.dart';
import '../../../core/network/dio_client.dart';
import 'notifications_mock.dart';

abstract class NotificationsRepository {
  Future<List<AppNotification>> fetchNotifications();
  Future<void> registerDeviceToken({required String fcmToken, required String platform});
  Future<void> markAsRead(String notificationId);
}

class HttpNotificationsRepository implements NotificationsRepository {
  HttpNotificationsRepository(this._dio);

  final Dio _dio;

  @override
  Future<List<AppNotification>> fetchNotifications() async {
    try {
      final response = await _dio.get('/notifications');
      final rawList = response.data['data'] as List? ?? [];

      if (rawList.isEmpty) {
        return mockNotifications;
      }

      return rawList.map((item) => AppNotification(
        id: item['id']?.toString() ?? '',
        title: item['title']?.toString() ?? 'AgriConnect Alert',
        message: item['message']?.toString() ?? '',
        timeAgo: 'Just now',
        isRead: item['isRead'] == true,
      )).toList();
    } catch (_) {
      return mockNotifications;
    }
  }

  @override
  Future<void> registerDeviceToken({required String fcmToken, required String platform}) async {
    try {
      await _dio.post(
        ApiEndpoints.userDeviceToken,
        data: {
          'token': fcmToken,
          'platform': platform,
        },
      );
    } catch (_) {
      // Fire-and-forget push token registration
    }
  }

  @override
  Future<void> markAsRead(String notificationId) async {
    try {
      await _dio.post('/notifications/$notificationId/read');
    } catch (_) {}
  }
}

final notificationsRepositoryProvider = Provider<NotificationsRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return HttpNotificationsRepository(dio);
});
