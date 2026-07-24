// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$UserModelImpl _$$UserModelImplFromJson(Map<String, dynamic> json) =>
    _$UserModelImpl(
      id: json['id'] as String,
      role: $enumDecode(_$UserRoleEnumMap, json['role']),
      name: json['name'] as String,
      phone: json['phone'] as String,
      status: $enumDecode(_$AccountStatusEnumMap, json['status']),
      region: json['region'] as String?,
      businessName: json['businessName'] as String?,
      businessType: json['businessType'] as String?,
      vehicleCapacity: json['vehicleCapacity'] as String?,
      operatingRegion: json['operatingRegion'] as String?,
    );

Map<String, dynamic> _$$UserModelImplToJson(_$UserModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'role': _$UserRoleEnumMap[instance.role]!,
      'name': instance.name,
      'phone': instance.phone,
      'status': _$AccountStatusEnumMap[instance.status]!,
      'region': instance.region,
      'businessName': instance.businessName,
      'businessType': instance.businessType,
      'vehicleCapacity': instance.vehicleCapacity,
      'operatingRegion': instance.operatingRegion,
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
