import 'package:json_annotation/json_annotation.dart';

/// Matches the backend user status values. The backend uses
/// ACTIVE / PENDING_APPROVAL / REJECTED while the frontend maps them
/// to verified / pendingVerification / rejected.
enum AccountStatus {
  @JsonValue('PENDING_VERIFICATION')
  pendingVerification,
  @JsonValue('VERIFIED')
  verified,
  @JsonValue('REJECTED')
  rejected,
}
