import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import 'models/account_status.dart';
import 'models/auth_response_model.dart';
import 'models/register_request.dart';
import 'models/user_model.dart';

/// Backend contract: POST /auth/register, POST /auth/login (claude.md Auth
/// contract). Do not point at real endpoints until the backend team confirms
/// this contract — see checklist Phase 1 callout. [MockAuthRepository] is
/// the only implementation for now.
abstract class AuthRepository {
  Future<AuthResponseModel> register(RegisterRequest request);
  Future<AuthResponseModel> login({required String phone, required String password});

  /// Dev-only affordance standing in for the Admin approval flow (Phase 9,
  /// not yet built) so the pending-verification screen can be demonstrated
  /// end to end. Not part of the real backend contract.
  Future<UserModel> debugApprove(String phone);
}

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

final authRepositoryProvider = Provider<AuthRepository>((ref) => MockAuthRepository());
