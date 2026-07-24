import 'package:freezed_annotation/freezed_annotation.dart';

import 'user_role.dart';

part 'register_request.freezed.dart';
part 'register_request.g.dart';

/// POST /auth/register payload (claude.md Auth contract). Shared fields per
/// checklist 1.2, plus the fields relevant to [role] — the registration form
/// only shows/fills the fields for the role the user picked.
@freezed
class RegisterRequest with _$RegisterRequest {
  const factory RegisterRequest({
    required UserRole role,
    required String name,
    required String phone,
    required String password,
    String? region, // Farmer / Driver
    String? businessName, // Buyer (optional)
    String? businessType, // Buyer
    String? vehicleCapacity, // Driver
    String? operatingRegion, // Driver
  }) = _RegisterRequest;

  factory RegisterRequest.fromJson(Map<String, dynamic> json) =>
      _$RegisterRequestFromJson(json);
}
