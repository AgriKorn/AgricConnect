import 'package:json_annotation/json_annotation.dart';

/// Matches the JWT `verificationStatus` claim (claude.md Auth contract, FR-14).
enum AccountStatus {
  @JsonValue('PENDING_VERIFICATION')
  pendingVerification,
  @JsonValue('VERIFIED')
  verified,
  @JsonValue('REJECTED')
  rejected,
}
