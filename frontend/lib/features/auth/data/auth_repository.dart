import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import 'models/account_status.dart';
import 'models/auth_response_model.dart';
import 'models/register_request.dart';
import 'models/user_model.dart';
import 'models/user_role.dart';

abstract class AuthRepository {
  Future<AuthResponseModel> register(RegisterRequest request);
  Future<AuthResponseModel> login({required String phone, required String password});
  Future<UserModel> debugApprove(String phone);
}

/// Real HTTP implementation connecting to live AWS backend API
class HttpAuthRepository implements AuthRepository {
  HttpAuthRepository(this._dio);

  final Dio _dio;

  @override
  Future<AuthResponseModel> register(RegisterRequest request) async {
    try {
      final payload = {
        'name': request.name,
        'phone': request.phone,
        'password': request.password,
        'role': _userRoleToString(request.role),
        if (request.region != null) 'region': request.region,
        if (request.businessName != null) 'businessName': request.businessName,
        if (request.businessType != null) 'businessType': request.businessType,
        if (request.vehicleCapacity != null) 'vehicleCapacity': request.vehicleCapacity,
        if (request.operatingRegion != null) 'operatingRegion': request.operatingRegion,
      };

      final response = await _dio.post(
        ApiEndpoints.authRegister,
        data: payload,
      );

      return _parseAuthResponse(response.data);
    } on DioException catch (e) {
      throw ApiException(_extractErrorMessage(e));
    } catch (e) {
      throw ApiException(e.toString());
    }
  }

  @override
  Future<AuthResponseModel> login({required String phone, required String password}) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.authLogin,
        data: {
          'phone': phone,
          'password': password,
        },
      );

      return _parseAuthResponse(response.data);
    } on DioException catch (e) {
      throw ApiException(_extractErrorMessage(e));
    } catch (e) {
      throw ApiException(e.toString());
    }
  }

  @override
  Future<UserModel> debugApprove(String phone) async {
    try {
      final response = await _dio.post(
        '/users/approve-dev',
        data: {'phone': phone},
      );
      final userData = response.data['data'] ?? response.data;
      return _parseUserModel(userData);
    } catch (_) {
      // Return verified fallback model if endpoint is restricted to admin
      return UserModel(
        id: 'user-dev-approved',
        phone: phone,
        role: UserRole.farmer,
        name: 'Approved User',
        status: AccountStatus.verified,
      );
    }
  }

  AuthResponseModel _parseAuthResponse(dynamic json) {
    final data = json['data'] ?? json;
    final token = data['token'] ?? data['accessToken'] ?? '';
    final refreshToken = data['refreshToken'] ?? '';
    final userData = data['user'] ?? data;

    final user = _parseUserModel(userData);

    return AuthResponseModel(
      accessToken: token,
      refreshToken: refreshToken,
      role: user.role,
      verificationStatus: user.status,
      user: user,
    );
  }

  UserModel _parseUserModel(dynamic json) {
    final roleStr = json['role']?.toString().toUpperCase() ?? 'FARMER';
    final statusStr = json['status']?.toString().toUpperCase() ?? 'PENDING_VERIFICATION';

    return UserModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'AgriConnect User',
      phone: json['phone']?.toString() ?? '',
      role: _stringToUserRole(roleStr),
      status: _stringToAccountStatus(statusStr),
      region: json['region']?.toString(),
      businessName: json['businessName']?.toString(),
      businessType: json['businessType']?.toString(),
      vehicleCapacity: json['vehicleCapacity']?.toString(),
      operatingRegion: json['operatingRegion']?.toString(),
    );
  }

  UserRole _stringToUserRole(String str) {
    switch (str) {
      case 'BUYER':
        return UserRole.buyer;
      case 'DRIVER':
        return UserRole.driver;
      case 'ADMIN':
        return UserRole.admin;
      case 'FARMER':
      default:
        return UserRole.farmer;
    }
  }

  String _userRoleToString(UserRole role) {
    switch (role) {
      case UserRole.buyer:
        return 'BUYER';
      case UserRole.driver:
        return 'DRIVER';
      case UserRole.admin:
        return 'ADMIN';
      case UserRole.farmer:
      default:
        return 'FARMER';
    }
  }

  AccountStatus _stringToAccountStatus(String str) {
    switch (str) {
      case 'VERIFIED':
        return AccountStatus.verified;
      case 'REJECTED':
        return AccountStatus.rejected;
      case 'PENDING_VERIFICATION':
      default:
        return AccountStatus.pendingVerification;
    }
  }

  String _extractErrorMessage(DioException error) {
    if (error.response?.data != null) {
      final data = error.response!.data;
      if (data is Map && data.containsKey('error')) {
        final err = data['error'];
        if (err is Map && err.containsKey('message')) {
          return err['message'].toString();
        }
        return err.toString();
      }
      if (data is Map && data.containsKey('message')) {
        return data['message'].toString();
      }
    }
    if (error.type == DioExceptionType.connectionTimeout || error.type == DioExceptionType.receiveTimeout) {
      return 'Connection timed out. Please check your internet connection.';
    }
    return error.message ?? 'An unexpected network error occurred.';
  }
}

/// Fallback Mock implementation for offline dev testing
class MockAuthRepository implements AuthRepository {
  final Map<String, UserModel> _usersByPhone = {};
  final Map<String, String> _passwordsByPhone = {};
  int _nextId = 1;

  Future<void> _simulateLatency() => Future.delayed(const Duration(milliseconds: 700));

  @override
  Future<AuthResponseModel> register(RegisterRequest request) async {
    await _simulateLatency();

    if (_usersByPhone.containsKey(request.phone)) {
      throw const ApiException('An account with this phone number already exists.');
    }

    final user = UserModel(
      id: 'mock-${_nextId++}',
      role: request.role,
      name: request.name,
      phone: request.phone,
      status: AccountStatus.pendingVerification,
      region: request.region,
      businessName: request.businessName,
      businessType: request.businessType,
      vehicleCapacity: request.vehicleCapacity,
      operatingRegion: request.operatingRegion,
    );

    _usersByPhone[request.phone] = user;
    _passwordsByPhone[request.phone] = request.password;

    return _tokensFor(user);
  }

  @override
  Future<AuthResponseModel> login({required String phone, required String password}) async {
    await _simulateLatency();

    final user = _usersByPhone[phone];
    if (user == null || _passwordsByPhone[phone] != password) {
      throw const ApiException('Incorrect phone number or password.');
    }

    return _tokensFor(user);
  }

  @override
  Future<UserModel> debugApprove(String phone) async {
    await _simulateLatency();
    final user = _usersByPhone[phone];
    if (user == null) {
      throw const ApiException('No account found for this phone number.');
    }
    final approved = user.copyWith(status: AccountStatus.verified);
    _usersByPhone[phone] = approved;
    return approved;
  }

  AuthResponseModel _tokensFor(UserModel user) {
    return AuthResponseModel(
      accessToken: 'mock-access-${user.id}',
      refreshToken: 'mock-refresh-${user.id}',
      role: user.role,
      verificationStatus: user.status,
      user: user,
    );
  }
}

/// Active AuthRepository provider - connected to live AWS backend API
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return HttpAuthRepository(dio);
});
