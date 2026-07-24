import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/storage/local_prefs.dart';
import '../../../core/storage/secure_storage.dart';
import '../data/auth_repository.dart';
import '../data/models/account_status.dart';
import '../data/models/auth_response_model.dart';
import '../data/models/register_request.dart';
import '../data/models/user_model.dart';
import 'session_state.dart';

const _sessionSnapshotKey = 'auth_session_snapshot';

/// Owns the session for the whole app. go_router's redirect guard reads
/// this via [authControllerProvider] (claude.md: role/verificationStatus
/// claims drive the redirect guard).
class AuthController extends Notifier<SessionState> {
  late String? _phoneForDebugApproval;

  @override
  SessionState build() {
    _phoneForDebugApproval = null;
    Future.microtask(_restoreSession);
    return SessionState.initial();
  }

  Future<void> _restoreSession() async {
    try {
      final prefs = ref.read(localPrefsProvider);
      final snapshotJson = prefs.getString(_sessionSnapshotKey);
      final accessToken = await ref
          .read(secureStorageProvider)
          .readAccessToken();

      if (snapshotJson == null || accessToken == null) {
        await _clearPersistedSession();
        state = const SessionState(status: AuthStatus.unauthenticated);
        return;
      }

      final snapshot = jsonDecode(snapshotJson) as Map<String, dynamic>;
      final user = UserModel.fromJson(snapshot['user'] as Map<String, dynamic>);
      state = SessionState(
        status: user.status == AccountStatus.verified
            ? AuthStatus.authenticated
            : AuthStatus.pendingVerification,
        user: user,
      );
    } catch (_) {
      await _clearPersistedSession();
      // A storage or decode failure should fail safe to signed out, not
      // block app startup.
      state = const SessionState(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> _persistSession(AuthResponseModel response) async {
    await ref
        .read(localPrefsProvider)
        .setString(
          _sessionSnapshotKey,
          jsonEncode({'user': response.user.toJson()}),
        );
  }

  Future<void> _clearPersistedSession() async {
    await ref.read(secureStorageProvider).clear();
    await ref.read(localPrefsProvider).remove(_sessionSnapshotKey);
  }

  Future<void> register(RegisterRequest request) async {
    state = state.copyWith(isSubmitting: true, errorMessage: null);
    try {
      final response = await ref.read(authRepositoryProvider).register(request);
      _phoneForDebugApproval = request.phone;
      await _applyAuthResponse(response);
    } on ApiException catch (e) {
      state = state.copyWith(isSubmitting: false, errorMessage: e.message);
    }
  }

  Future<void> login({required String phone, required String password}) async {
    state = state.copyWith(isSubmitting: true, errorMessage: null);
    try {
      final response = await ref
          .read(authRepositoryProvider)
          .login(phone: phone, password: password);
      _phoneForDebugApproval = phone;
      await _applyAuthResponse(response);
    } on ApiException catch (e) {
      state = state.copyWith(isSubmitting: false, errorMessage: e.message);
    }
  }

  Future<void> _applyAuthResponse(AuthResponseModel response) async {
    await ref
        .read(secureStorageProvider)
        .saveTokens(
          accessToken: response.accessToken,
          refreshToken: response.refreshToken,
        );
    await _persistSession(response);
    state = SessionState(
      status: response.verificationStatus == AccountStatus.verified
          ? AuthStatus.authenticated
          : AuthStatus.pendingVerification,
      user: response.user,
      isSubmitting: false,
    );
  }

  /// Dev-only: stands in for Admin approval (Phase 9 not yet built).
  Future<void> debugApprove() async {
    final phone = _phoneForDebugApproval;
    if (phone == null) return;
    final user = await ref.read(authRepositoryProvider).debugApprove(phone);
    state = state.copyWith(status: AuthStatus.authenticated, user: user);
    await ref
        .read(localPrefsProvider)
        .setString(_sessionSnapshotKey, jsonEncode({'user': user.toJson()}));
  }

  Future<void> logout() async {
    await _clearPersistedSession();
    state = const SessionState(status: AuthStatus.unauthenticated);
  }
}

final authControllerProvider = NotifierProvider<AuthController, SessionState>(
  AuthController.new,
);
