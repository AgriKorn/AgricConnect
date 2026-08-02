import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/secure_storage.dart';
import 'api_endpoints.dart';

/// Single Dio instance for the app, configured with default live AWS API URL
/// and JWT Bearer token attachment interceptor.
final dioProvider = Provider<Dio>((ref) {
  final secureStorage = ref.watch(secureStorageProvider);
  final baseUrl = const String.fromEnvironment('API_BASE_URL', defaultValue: ApiEndpoints.defaultBaseUrl);

  final dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
  ));

  // Access tokens are short-lived (15 min) by design — without this, every
  // session silently breaks the moment one expires: every request 401s with
  // "Access token is invalid or expired" until the user manually logs out
  // and back in, even though their refresh token (7 days) is still good.
  Future<String?>? refreshInFlight;

  Future<String?> refreshAccessToken() {
    return refreshInFlight ??= () async {
      try {
        final refreshToken = await secureStorage.readRefreshToken();
        if (refreshToken == null || refreshToken.isEmpty) return null;

        // A bare instance, not `dio` itself — this must never go through
        // the interceptor below or a failed refresh could recurse into
        // itself trying to refresh its own 401.
        final refreshClient = Dio(BaseOptions(baseUrl: baseUrl));
        final response = await refreshClient.post(
          ApiEndpoints.authRefresh,
          data: {'refreshToken': refreshToken},
        );
        final data = response.data['data'] ?? response.data;
        final newAccessToken = data['accessToken']?.toString();
        if (newAccessToken == null || newAccessToken.isEmpty) return null;

        await secureStorage.saveTokens(accessToken: newAccessToken, refreshToken: refreshToken);
        return newAccessToken;
      } catch (_) {
        // Refresh token itself is dead (expired/revoked) — clear the stale
        // pair so the app stops attaching a token that will never work,
        // rather than repeating this failed refresh on every request.
        await secureStorage.clear();
        return null;
      } finally {
        refreshInFlight = null;
      }
    }();
  }

  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      final token = await secureStorage.readAccessToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      handler.next(options);
    },
    onError: (DioException error, handler) async {
      final isExpiredToken = error.response?.statusCode == 401;
      final alreadyRetried = error.requestOptions.extra['retriedAfterRefresh'] == true;

      if (isExpiredToken && !alreadyRetried) {
        final newAccessToken = await refreshAccessToken();
        if (newAccessToken != null) {
          try {
            error.requestOptions.extra['retriedAfterRefresh'] = true;
            final retryResponse = await dio.fetch(error.requestOptions);
            return handler.resolve(retryResponse);
          } catch (_) {
            // Fall through and surface the original error below.
          }
        }
      }
      handler.next(error);
    },
  ));

  return dio;
});
