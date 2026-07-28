// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'register_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$RegisterRequestImpl _$$RegisterRequestImplFromJson(
  Map<String, dynamic> json,
) => _$RegisterRequestImpl(
  role: $enumDecode(_$UserRoleEnumMap, json['role']),
  name: json['name'] as String,
  phone: json['phone'] as String,
  password: json['password'] as String,
  region: json['region'] as String?,
  businessName: json['businessName'] as String?,
  businessType: json['businessType'] as String?,
  vehicleCapacity: json['vehicleCapacity'] as String?,
  operatingRegion: json['operatingRegion'] as String?,
);

Map<String, dynamic> _$$RegisterRequestImplToJson(
  _$RegisterRequestImpl instance,
) => <String, dynamic>{
  'role': _$UserRoleEnumMap[instance.role]!,
  'name': instance.name,
  'phone': instance.phone,
  'password': instance.password,
  'region': instance.region,
  'businessName': instance.businessName,
  'businessType': instance.businessType,
  'vehicleCapacity': instance.vehicleCapacity,
  'operatingRegion': instance.operatingRegion,
};

const _$UserRoleEnumMap = {
  UserRole.farmer: 'farmer',
  UserRole.buyer: 'buyer',
  UserRole.driver: 'driver',
  UserRole.admin: 'admin',
};
