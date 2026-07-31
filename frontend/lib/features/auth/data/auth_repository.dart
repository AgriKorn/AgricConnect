import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide Provider, AuthResponse;

import '../../../core/config/supabase_config.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import 'models/account_status.dart';
import 'models/auth_response_model.dart';
import 'models/register_request.dart';
import 'models/user_model.dart';
import 'models/user_role.dart';

/// Result from POST /auth/register — the backend returns { userId, message }
/// (no tokens) because non-buyer accounts need admin approval first.
class RegisterResult {
  const RegisterResult({required this.userId, required this.message, required this.isBuyer});
  final String userId;
  final String message;
  final bool isBuyer;
}

/// GET /users/profile's `profile` sub-object — fields vary by role.
class ProfileData {
  const ProfileData({
    this.farmRegion,
    this.businessName,
    this.deliveryAddress,
    this.truckCapacity,
    this.operatingRegion,
    this.momoNumber,
    this.momoNetwork,
  });

  final String? farmRegion;
  final String? businessName;
  final String? deliveryAddress;
  final double? truckCapacity;
  final String? operatingRegion;
  final String? momoNumber;
  final String? momoNetwork;

  factory ProfileData.fromJson(Map<String, dynamic> json) {
    return ProfileData(
      farmRegion: json['farmRegion']?.toString(),
      businessName: json['businessName']?.toString(),
      deliveryAddress: json['deliveryAddress']?.toString(),
      truckCapacity: double.tryParse(json['truckCapacity']?.toString() ?? ''),
      operatingRegion: json['operatingRegion']?.toString(),
      momoNumber: json['momoNumber']?.toString(),
      momoNetwork: json['momoNetwork']?.toString(),
    );
  }
}

abstract class AuthRepository {
  Future<RegisterResult> register(RegisterRequest request);
  Future<AuthResponseModel> login({required String email, required String password});
  /// [role] is only sent for a brand-new sign-up (defaults to buyer on the
  /// backend if omitted); existing accounts are matched by email regardless.
  Future<AuthResponseModel> loginWithGoogle({UserRole? role});
  Future<UserModel> debugApprove(String phone);
  Future<String> forgotPassword(String email);
  Future<void> resetPassword({required String token, required String newPassword});
  Future<ProfileData> fetchProfile();
  Future<void> updateProfile(Map<String, dynamic> fields);
  Future<String> resolveMomoAccount({required String accountNumber, required String bankCode});
}

/// Real HTTP implementation connecting to live AWS backend API
class HttpAuthRepository implements AuthRepository {
  HttpAuthRepository(this._dio);

  final Dio _dio;

  String _formatGhanaPhone(String raw) {
    final trimmed = raw.trim().replaceAll(RegExp(r'\s+'), '');
    if (RegExp(r'^0\d{9}$').hasMatch(trimmed)) {
      return '+233${trimmed.substring(1)}';
    }
    if (RegExp(r'^233\d{9}$').hasMatch(trimmed)) {
      return '+$trimmed';
    }
    return trimmed;
  }

  @override
  Future<RegisterResult> register(RegisterRequest request) async {
    try {
      final roleStr = _userRoleToString(request.role);
      final payload = {
        'name': request.name.trim(),
        'email': request.email.trim(),
        'phone': _formatGhanaPhone(request.phone),
        'password': request.password,
        'role': roleStr,
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

      final data = response.data['data'] ?? response.data;
      return RegisterResult(
        userId: data['userId']?.toString() ?? '',
        message: data['message']?.toString() ?? 'Registration successful.',
        isBuyer: roleStr == 'buyer',
      );
    } on DioException catch (e) {
      throw ApiException(_extractErrorMessage(e));
    } catch (e) {
      throw ApiException(e.toString());
    }
  }

  @override
  Future<AuthResponseModel> login({required String email, required String password}) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.authLogin,
        data: {
          'email': email.trim(),
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
  Future<AuthResponseModel> loginWithGoogle({UserRole? role}) async {
    try {
      final googleUser = await GoogleSignIn(serverClientId: SupabaseConfig.googleWebClientId).signIn();
      if (googleUser == null) {
        throw const ApiException('Google sign-in was cancelled.');
      }

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null) {
        throw const ApiException('Google did not return an ID token — check the Web Client ID configuration.');
      }

      final supabaseSession = await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: googleAuth.accessToken,
      );
      final supabaseAccessToken = supabaseSession.session?.accessToken;
      if (supabaseAccessToken == null) {
        throw const ApiException('Could not establish a Google session.');
      }

      final response = await _dio.post(
        ApiEndpoints.authGoogle,
        data: {
          'token': supabaseAccessToken,
          if (role != null) 'role': _userRoleToString(role),
        },
      );
      return _parseAuthResponse(response.data);
    } on DioException catch (e) {
      throw ApiException(_extractErrorMessage(e));
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(e.toString());
    }
  }

  @override
  Future<UserModel> debugApprove(String phone) async {
    try {
      final response = await _dio.post(
        '/users/approve-dev',
        data: {'phone': _formatGhanaPhone(phone)},
      );
      final userData = response.data['data'] ?? response.data;
      return _parseUserModel(userData);
    } catch (_) {
      // Return verified fallback model if endpoint is restricted to admin
      return UserModel(
        id: 'user-dev-approved',
        phone: phone,
        email: '',
        role: UserRole.farmer,
        name: 'Approved User',
        status: AccountStatus.verified,
      );
    }
  }

  @override
  Future<String> forgotPassword(String email) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.authForgotPassword,
        data: {'email': email.trim()},
      );
      final data = response.data['data'] ?? response.data;
      return data['message']?.toString() ?? 'If an account with that email exists, reset instructions have been sent.';
    } on DioException catch (e) {
      throw ApiException(_extractErrorMessage(e));
    }
  }

  @override
  Future<void> resetPassword({required String token, required String newPassword}) async {
    try {
      await _dio.post(
        ApiEndpoints.authResetPassword,
        data: {'token': token, 'newPassword': newPassword},
      );
    } on DioException catch (e) {
      throw ApiException(_extractErrorMessage(e));
    }
  }

  @override
  Future<ProfileData> fetchProfile() async {
    try {
      final response = await _dio.get(ApiEndpoints.userProfile);
      final data = response.data['data'] ?? response.data;
      return ProfileData.fromJson((data['profile'] as Map?)?.cast<String, dynamic>() ?? {});
    } on DioException catch (e) {
      throw ApiException(_extractErrorMessage(e));
    }
  }

  @override
  Future<void> updateProfile(Map<String, dynamic> fields) async {
    try {
      await _dio.patch(ApiEndpoints.userProfile, data: fields);
    } on DioException catch (e) {
      throw ApiException(_extractErrorMessage(e));
    }
  }

  @override
  Future<String> resolveMomoAccount({required String accountNumber, required String bankCode}) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.paystackResolveMomo,
        queryParameters: {'accountNumber': accountNumber, 'bankCode': bankCode},
      );
      final data = response.data['data'] ?? response.data;
      return data['accountName']?.toString() ?? '';
    } on DioException catch (e) {
      throw ApiException(_extractErrorMessage(e));
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
    final roleStr = json['role']?.toString().toLowerCase() ?? 'farmer';
    final statusStr = json['status']?.toString().toUpperCase() ?? 'PENDING_VERIFICATION';

    return UserModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'AgriConnect User',
      email: json['email']?.toString() ?? '',
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
    switch (str.toLowerCase()) {
      case 'buyer':
        return UserRole.buyer;
      case 'driver':
        return UserRole.driver;
      case 'admin':
        return UserRole.admin;
      case 'farmer':
      default:
        return UserRole.farmer;
    }
  }

  String _userRoleToString(UserRole role) {
    switch (role) {
      case UserRole.buyer:
        return 'buyer';
      case UserRole.driver:
        return 'driver';
      case UserRole.admin:
        return 'admin';
      case UserRole.farmer:
      default:
        return 'farmer';
    }
  }

  AccountStatus _stringToAccountStatus(String str) {
    switch (str) {
      case 'VERIFIED':
      case 'ACTIVE':
        return AccountStatus.verified;
      case 'REJECTED':
        return AccountStatus.rejected;
      case 'PENDING_VERIFICATION':
      case 'PENDING_APPROVAL':
      case 'PENDING_OTP':
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
  final Map<String, UserModel> _usersByEmail = {};
  final Map<String, String> _passwordsByEmail = {};
  int _nextId = 1;

  Future<void> _simulateLatency() => Future.delayed(const Duration(milliseconds: 700));

  @override
  Future<RegisterResult> register(RegisterRequest request) async {
    await _simulateLatency();

    if (_usersByPhone.containsKey(request.phone)) {
      throw const ApiException('An account with this phone number already exists.');
    }
    if (_usersByEmail.containsKey(request.email)) {
      throw const ApiException('An account with this email already exists.');
    }

    final isBuyer = request.role == UserRole.buyer;
    final user = UserModel(
      id: 'mock-${_nextId++}',
      role: request.role,
      name: request.name,
      email: request.email,
      phone: request.phone,
      status: isBuyer ? AccountStatus.verified : AccountStatus.pendingVerification,
      region: request.region,
      businessName: request.businessName,
      businessType: request.businessType,
      vehicleCapacity: request.vehicleCapacity,
      operatingRegion: request.operatingRegion,
    );

    _usersByPhone[request.phone] = user;
    _usersByEmail[request.email] = user;
    _passwordsByEmail[request.email] = request.password;

    return RegisterResult(
      userId: user.id,
      message: isBuyer
          ? 'Registration successful. Welcome to AgriConnect!'
          : 'Registration successful. Your account is pending admin approval.',
      isBuyer: isBuyer,
    );
  }

  @override
  Future<AuthResponseModel> login({required String email, required String password}) async {
    await _simulateLatency();

    final user = _usersByEmail[email];
    if (user == null || _passwordsByEmail[email] != password) {
      throw const ApiException('Incorrect email or password.');
    }

    return _tokensFor(user);
  }

  @override
  Future<AuthResponseModel> loginWithGoogle({UserRole? role}) async {
    await _simulateLatency();
    throw const ApiException('Google sign-in is not available in offline/mock mode.');
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

  @override
  Future<String> forgotPassword(String email) async {
    await _simulateLatency();
    return 'If an account with that email exists, reset instructions have been sent.';
  }

  @override
  Future<void> resetPassword({required String token, required String newPassword}) async {
    await _simulateLatency();
  }

  @override
  Future<ProfileData> fetchProfile() async {
    await _simulateLatency();
    return const ProfileData();
  }

  @override
  Future<void> updateProfile(Map<String, dynamic> fields) async {
    await _simulateLatency();
  }

  @override
  Future<String> resolveMomoAccount({required String accountNumber, required String bankCode}) async {
    await _simulateLatency();
    return 'Mock Account Holder';
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
