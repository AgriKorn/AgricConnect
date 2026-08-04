import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_endpoints.dart';
import '../../../core/network/dio_client.dart';

String _titleForType(String type) {
  final words = type.split('_').map((w) => w.isEmpty ? w : '${w[0]}${w.substring(1).toLowerCase()}');
  return words.join(' ');
}

String _relativeTime(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.timeAgo,
    required this.isRead,
    this.orderId,
    this.listingId,
  });

  final String id;
  final String title;
  final String message;
  final String timeAgo;
  final bool isRead;
  final String? orderId;
  final String? listingId;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final type = json['type']?.toString() ?? 'ALERT';
    final createdAt = DateTime.tryParse(json['createdAt']?.toString() ?? '');
    return AppNotification(
      id: json['id']?.toString() ?? '',
      title: _titleForType(type),
      message: json['message']?.toString() ?? '',
      timeAgo: createdAt == null ? '' : _relativeTime(createdAt),
      isRead: json['isRead'] == true,
      orderId: json['orderId']?.toString(),
      listingId: json['listingId']?.toString(),
    );
  }
}

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
      final rawList = response.data['data']?['notifications'] as List? ?? [];
      return rawList.map((item) => AppNotification.fromJson(item as Map<String, dynamic>)).toList();
    } on DioException {
      return const [];
    }
  }

  @override
  Future<void> registerDeviceToken({required String fcmToken, required String platform}) async {
    try {
      await _dio.post(
        ApiEndpoints.userDeviceToken,
        data: {
          'fcmToken': fcmToken,
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
      await _dio.patch('/notifications/$notificationId/read');
    } catch (_) {}
  }
}

final notificationsRepositoryProvider = Provider<NotificationsRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return HttpNotificationsRepository(dio);
});
