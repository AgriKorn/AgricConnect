import 'package:freezed_annotation/freezed_annotation.dart';

import 'account_status.dart';
import 'user_model.dart';
import 'user_role.dart';

part 'auth_response_model.freezed.dart';
part 'auth_response_model.g.dart';

/// POST /auth/login and /auth/register response shape (claude.md Auth contract).
@freezed
class AuthResponseModel with _$AuthResponseModel {
  const factory AuthResponseModel({
    required String accessToken,
    required String refreshToken,
    required UserRole role,
    required AccountStatus verificationStatus,
    required UserModel user,
  }) = _AuthResponseModel;

  factory AuthResponseModel.fromJson(Map<String, dynamic> json) =>
      _$AuthResponseModelFromJson(json);
}
