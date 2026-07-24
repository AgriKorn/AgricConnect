// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_response_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AuthResponseModelImpl _$$AuthResponseModelImplFromJson(
  Map<String, dynamic> json,
) => _$AuthResponseModelImpl(
  accessToken: json['accessToken'] as String,
  refreshToken: json['refreshToken'] as String,
  role: $enumDecode(_$UserRoleEnumMap, json['role']),
  verificationStatus: $enumDecode(
    _$AccountStatusEnumMap,
    json['verificationStatus'],
  ),
  user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
);

Map<String, dynamic> _$$AuthResponseModelImplToJson(
  _$AuthResponseModelImpl instance,
) => <String, dynamic>{
  'accessToken': instance.accessToken,
  'refreshToken': instance.refreshToken,
  'role': _$UserRoleEnumMap[instance.role]!,
  'verificationStatus': _$AccountStatusEnumMap[instance.verificationStatus]!,
  'user': instance.user,
};

const _$UserRoleEnumMap = {
  UserRole.farmer: 'FARMER',
  UserRole.buyer: 'BUYER',
  UserRole.driver: 'DRIVER',
  UserRole.admin: 'ADMIN',
};

const _$AccountStatusEnumMap = {
  AccountStatus.pendingVerification: 'PENDING_VERIFICATION',
  AccountStatus.verified: 'VERIFIED',
  AccountStatus.rejected: 'REJECTED',
};
