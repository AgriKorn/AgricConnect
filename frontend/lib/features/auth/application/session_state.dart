import 'package:freezed_annotation/freezed_annotation.dart';

import '../data/models/user_model.dart';

part 'session_state.freezed.dart';

enum AuthStatus { restoring, unauthenticated, pendingVerification, authenticated }

@freezed
class SessionState with _$SessionState {
  const factory SessionState({
    required AuthStatus status,
    UserModel? user,
    String? errorMessage,
    @Default(false) bool isSubmitting,
  }) = _SessionState;

  factory SessionState.initial() => const SessionState(status: AuthStatus.restoring);
}
