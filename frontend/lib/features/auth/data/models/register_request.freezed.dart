// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'register_request.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

RegisterRequest _$RegisterRequestFromJson(Map<String, dynamic> json) {
  return _RegisterRequest.fromJson(json);
}

/// @nodoc
mixin _$RegisterRequest {
  UserRole get role => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get email => throw _privateConstructorUsedError;
  String get phone => throw _privateConstructorUsedError;
  String get password => throw _privateConstructorUsedError;
  String? get region => throw _privateConstructorUsedError; // Farmer / Driver
  String? get businessName =>
      throw _privateConstructorUsedError; // Buyer (optional)
  String? get businessType => throw _privateConstructorUsedError; // Buyer
  String? get vehicleCapacity => throw _privateConstructorUsedError; // Driver
  String? get operatingRegion => throw _privateConstructorUsedError;

  /// Serializes this RegisterRequest to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of RegisterRequest
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $RegisterRequestCopyWith<RegisterRequest> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RegisterRequestCopyWith<$Res> {
  factory $RegisterRequestCopyWith(
    RegisterRequest value,
    $Res Function(RegisterRequest) then,
  ) = _$RegisterRequestCopyWithImpl<$Res, RegisterRequest>;
  @useResult
  $Res call({
    UserRole role,
    String name,
    String email,
    String phone,
    String password,
    String? region,
    String? businessName,
    String? businessType,
    String? vehicleCapacity,
    String? operatingRegion,
  });
}

/// @nodoc
class _$RegisterRequestCopyWithImpl<$Res, $Val extends RegisterRequest>
    implements $RegisterRequestCopyWith<$Res> {
  _$RegisterRequestCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of RegisterRequest
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? role = null,
    Object? name = null,
    Object? email = null,
    Object? phone = null,
    Object? password = null,
    Object? region = freezed,
    Object? businessName = freezed,
    Object? businessType = freezed,
    Object? vehicleCapacity = freezed,
    Object? operatingRegion = freezed,
  }) {
    return _then(
      _value.copyWith(
            role: null == role
                ? _value.role
                : role // ignore: cast_nullable_to_non_nullable
                      as UserRole,
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            email: null == email
                ? _value.email
                : email // ignore: cast_nullable_to_non_nullable
                      as String,
            phone: null == phone
                ? _value.phone
                : phone // ignore: cast_nullable_to_non_nullable
                      as String,
            password: null == password
                ? _value.password
                : password // ignore: cast_nullable_to_non_nullable
                      as String,
            region: freezed == region
                ? _value.region
                : region // ignore: cast_nullable_to_non_nullable
                      as String?,
            businessName: freezed == businessName
                ? _value.businessName
                : businessName // ignore: cast_nullable_to_non_nullable
                      as String?,
            businessType: freezed == businessType
                ? _value.businessType
                : businessType // ignore: cast_nullable_to_non_nullable
                      as String?,
            vehicleCapacity: freezed == vehicleCapacity
                ? _value.vehicleCapacity
                : vehicleCapacity // ignore: cast_nullable_to_non_nullable
                      as String?,
            operatingRegion: freezed == operatingRegion
                ? _value.operatingRegion
                : operatingRegion // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$RegisterRequestImplCopyWith<$Res>
    implements $RegisterRequestCopyWith<$Res> {
  factory _$$RegisterRequestImplCopyWith(
    _$RegisterRequestImpl value,
    $Res Function(_$RegisterRequestImpl) then,
  ) = __$$RegisterRequestImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    UserRole role,
    String name,
    String email,
    String phone,
    String password,
    String? region,
    String? businessName,
    String? businessType,
    String? vehicleCapacity,
    String? operatingRegion,
  });
}

/// @nodoc
class __$$RegisterRequestImplCopyWithImpl<$Res>
    extends _$RegisterRequestCopyWithImpl<$Res, _$RegisterRequestImpl>
    implements _$$RegisterRequestImplCopyWith<$Res> {
  __$$RegisterRequestImplCopyWithImpl(
    _$RegisterRequestImpl _value,
    $Res Function(_$RegisterRequestImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of RegisterRequest
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? role = null,
    Object? name = null,
    Object? email = null,
    Object? phone = null,
    Object? password = null,
    Object? region = freezed,
    Object? businessName = freezed,
    Object? businessType = freezed,
    Object? vehicleCapacity = freezed,
    Object? operatingRegion = freezed,
  }) {
    return _then(
      _$RegisterRequestImpl(
        role: null == role
            ? _value.role
            : role // ignore: cast_nullable_to_non_nullable
                  as UserRole,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        email: null == email
            ? _value.email
            : email // ignore: cast_nullable_to_non_nullable
                  as String,
        phone: null == phone
            ? _value.phone
            : phone // ignore: cast_nullable_to_non_nullable
                  as String,
        password: null == password
            ? _value.password
            : password // ignore: cast_nullable_to_non_nullable
                  as String,
        region: freezed == region
            ? _value.region
            : region // ignore: cast_nullable_to_non_nullable
                  as String?,
        businessName: freezed == businessName
            ? _value.businessName
            : businessName // ignore: cast_nullable_to_non_nullable
                  as String?,
        businessType: freezed == businessType
            ? _value.businessType
            : businessType // ignore: cast_nullable_to_non_nullable
                  as String?,
        vehicleCapacity: freezed == vehicleCapacity
            ? _value.vehicleCapacity
            : vehicleCapacity // ignore: cast_nullable_to_non_nullable
                  as String?,
        operatingRegion: freezed == operatingRegion
            ? _value.operatingRegion
            : operatingRegion // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$RegisterRequestImpl implements _RegisterRequest {
  const _$RegisterRequestImpl({
    required this.role,
    required this.name,
    required this.email,
    required this.phone,
    required this.password,
    this.region,
    this.businessName,
    this.businessType,
    this.vehicleCapacity,
    this.operatingRegion,
  });

  factory _$RegisterRequestImpl.fromJson(Map<String, dynamic> json) =>
      _$$RegisterRequestImplFromJson(json);

  @override
  final UserRole role;
  @override
  final String name;
  @override
  final String email;
  @override
  final String phone;
  @override
  final String password;
  @override
  final String? region;
  // Farmer / Driver
  @override
  final String? businessName;
  // Buyer (optional)
  @override
  final String? businessType;
  // Buyer
  @override
  final String? vehicleCapacity;
  // Driver
  @override
  final String? operatingRegion;

  @override
  String toString() {
    return 'RegisterRequest(role: $role, name: $name, email: $email, phone: $phone, password: $password, region: $region, businessName: $businessName, businessType: $businessType, vehicleCapacity: $vehicleCapacity, operatingRegion: $operatingRegion)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RegisterRequestImpl &&
            (identical(other.role, role) || other.role == role) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.email, email) || other.email == email) &&
            (identical(other.phone, phone) || other.phone == phone) &&
            (identical(other.password, password) ||
                other.password == password) &&
            (identical(other.region, region) || other.region == region) &&
            (identical(other.businessName, businessName) ||
                other.businessName == businessName) &&
            (identical(other.businessType, businessType) ||
                other.businessType == businessType) &&
            (identical(other.vehicleCapacity, vehicleCapacity) ||
                other.vehicleCapacity == vehicleCapacity) &&
            (identical(other.operatingRegion, operatingRegion) ||
                other.operatingRegion == operatingRegion));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    role,
    name,
    email,
    phone,
    password,
    region,
    businessName,
    businessType,
    vehicleCapacity,
    operatingRegion,
  );

  /// Create a copy of RegisterRequest
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RegisterRequestImplCopyWith<_$RegisterRequestImpl> get copyWith =>
      __$$RegisterRequestImplCopyWithImpl<_$RegisterRequestImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$RegisterRequestImplToJson(this);
  }
}

abstract class _RegisterRequest implements RegisterRequest {
  const factory _RegisterRequest({
    required final UserRole role,
    required final String name,
    required final String email,
    required final String phone,
    required final String password,
    final String? region,
    final String? businessName,
    final String? businessType,
    final String? vehicleCapacity,
    final String? operatingRegion,
  }) = _$RegisterRequestImpl;

  factory _RegisterRequest.fromJson(Map<String, dynamic> json) =
      _$RegisterRequestImpl.fromJson;

  @override
  UserRole get role;
  @override
  String get name;
  @override
  String get email;
  @override
  String get phone;
  @override
  String get password;
  @override
  String? get region; // Farmer / Driver
  @override
  String? get businessName; // Buyer (optional)
  @override
  String? get businessType; // Buyer
  @override
  String? get vehicleCapacity; // Driver
  @override
  String? get operatingRegion;

  /// Create a copy of RegisterRequest
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RegisterRequestImplCopyWith<_$RegisterRequestImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
