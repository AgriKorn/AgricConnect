import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/storage/local_prefs.dart';
import '../../../core/storage/secure_storage.dart';
import '../../home/application/farmer_dashboard_providers.dart';
import '../data/auth_repository.dart';
import '../data/models/account_status.dart';
import '../data/models/auth_response_model.dart';
import '../data/models/register_request.dart';
import '../data/models/user_model.dart';
import '../data/models/user_role.dart';
import 'session_state.dart';

const _sessionSnapshotKey = 'auth_session_snapshot';

/// Owns the session for the whole app. go_router's redirect guard reads
/// this via [authControllerProvider] (claude.md: role/verificationStatus
/// claims drive the redirect guard).
class AuthController extends Notifier<SessionState> {
  @override
  SessionState build() {
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

  Future<void> _persistSession(AuthResponseModel response) => _persistUser(response.user);

  Future<void> _persistUser(UserModel user) async {
    await ref
        .read(localPrefsProvider)
        .setString(_sessionSnapshotKey, jsonEncode({'user': user.toJson()}));
  }

  Future<void> _clearPersistedSession() async {
    await ref.read(secureStorageProvider).clear();
    await ref.read(localPrefsProvider).remove(_sessionSnapshotKey);
  }

  Future<void> register(RegisterRequest request) async {
    state = state.copyWith(isSubmitting: true, errorMessage: null);
    try {
      final result = await ref.read(authRepositoryProvider).register(request);

      // Registration succeeded. The backend does NOT return tokens on
      // registration, so we set a success message and direct the user to log
      // in (buyers) or wait for approval (farmers/drivers).
      state = SessionState(
        status: result.isBuyer
            ? AuthStatus.unauthenticated
            : AuthStatus.pendingVerification,
        isSubmitting: false,
        errorMessage: null,
        successMessage: result.message,
      );
    } on ApiException catch (e) {
      state = state.copyWith(isSubmitting: false, errorMessage: e.message);
    }
  }

  /// Saves through PATCH /users/profile — name and region are the only
  /// fields this screen can actually change. Phone and email aren't in
  /// updateProfileSchema at all (changing your login email needs its own
  /// verified flow, not a silent free-text edit), so EditProfileScreen
  /// shows them read-only rather than accepting edits it can't persist.
  /// The local snapshot is only updated after the server confirms the
  /// write, so a failed save can't leave the UI showing something the
  /// backend never actually stored.
  Future<void> updateProfile({
    required String name,
    String? region,
  }) async {
    final currentUser = state.user;
    if (currentUser == null) return;

    await ref.read(authRepositoryProvider).updateProfile({
      'name': name,
      if (region != null && region.isNotEmpty) 'farmRegion': region,
    });

    final updated = currentUser.copyWith(name: name, region: region);
    state = state.copyWith(user: updated);
    await _persistUser(updated);

    // farmerDashboardSummaryProvider caches its GET /dashboard/farmer-summary
    // fetch for the app's lifetime — without this, a region edit here (or the
    // weather it drives) keeps showing whatever was fetched at login.
    ref.invalidate(farmerDashboardSummaryProvider);
  }

  /// Separate from [updateProfile] so changing the photo doesn't force a
  /// name re-submit — the upload itself already happened by the time this
  /// runs, this just persists the resulting URL.
  Future<void> updatePhotoUrl(String photoUrl) async {
    final currentUser = state.user;
    if (currentUser == null) return;

    await ref.read(authRepositoryProvider).updateProfile({'photoUrl': photoUrl});

    final updated = currentUser.copyWith(photoUrl: photoUrl);
    state = state.copyWith(user: updated);
    await _persistUser(updated);
  }

  Future<void> login({required String email, required String password}) async {
    state = state.copyWith(isSubmitting: true, errorMessage: null);
    try {
      final response = await ref
          .read(authRepositoryProvider)
          .login(email: email, password: password);
      await _applyAuthResponse(response);
    } on ApiException catch (e) {
      state = state.copyWith(isSubmitting: false, errorMessage: e.message);
    }
  }

  Future<void> loginWithGoogle({UserRole? role}) async {
    state = state.copyWith(isSubmitting: true, errorMessage: null);
    try {
      final response = await ref.read(authRepositoryProvider).loginWithGoogle(role: role);
      await _applyAuthResponse(response);
    } on ApiException catch (e) {
      state = state.copyWith(isSubmitting: false, errorMessage: e.message);
    }
  }

  /// Web counterpart to [loginWithGoogle]: the web sign-in button hands us
  /// an already-obtained [GoogleSignInAccount] via a stream (see
  /// presentation/widgets/google_signin/google_signin_web.dart) instead of
  /// this controller triggering the native `.signIn()` popup itself.
  Future<void> completeGoogleSignIn(GoogleSignInAccount googleUser, {UserRole? role}) async {
    state = state.copyWith(isSubmitting: true, errorMessage: null);
    try {
      final response = await ref.read(authRepositoryProvider).completeGoogleSignIn(googleUser, role: role);
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

  Future<void> logout() async {
    try {
      final refreshToken = await ref.read(secureStorageProvider).readRefreshToken();
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await ref.read(authRepositoryProvider).logout(refreshToken);
      }
    } catch (_) {
      // Best-effort server-side revocation — the user must still end up
      // signed out locally even if this call fails (offline, already
      // expired, backend unreachable).
    }
    await _clearPersistedSession();
    state = const SessionState(status: AuthStatus.unauthenticated);
  }

  /// Called when a background token refresh discovers the refresh token
  /// itself is dead (expired/revoked elsewhere) — without this, the app
  /// silently wipes local tokens but keeps showing authenticated screens
  /// while every subsequent request quietly 401s, since nothing ever tells
  /// the router's redirect guard the session actually ended.
  void forceLogout() {
    if (state.status == AuthStatus.unauthenticated) return;
    unawaited(_clearPersistedSession());
    state = const SessionState(status: AuthStatus.unauthenticated);
  }
}

final authControllerProvider = NotifierProvider<AuthController, SessionState>(
  AuthController.new,
);
