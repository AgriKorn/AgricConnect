import 'package:freezed_annotation/freezed_annotation.dart';

import 'account_status.dart';
import 'user_role.dart';

part 'user_model.freezed.dart';
part 'user_model.g.dart';

/// Illustrative shape of the backend User entity (claude.md Backend
/// Integration Reference) — role-specific fields are nullable since only
/// the fields for the user's own role are ever populated.
@freezed
class UserModel with _$UserModel {
  const factory UserModel({
    required String id,
    required UserRole role,
    required String name,
    required String email,
    required String phone,
    required AccountStatus status,
    String? region, // Farmer / Buyer / Driver — their operating location
    String? businessName, // Buyer
    String? businessType, // Buyer
    String? vehicleCapacity, // Driver
    String? operatingRegion, // Driver
    String? bio, // Farmer / Buyer / Driver — free-text profile description
    String? photoUrl, // Shared — real uploaded profile photo, null until set
  }) = _UserModel;

  factory UserModel.fromJson(Map<String, dynamic> json) => _$UserModelFromJson(json);
}
