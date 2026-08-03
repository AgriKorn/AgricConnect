// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

UserModel _$UserModelFromJson(Map<String, dynamic> json) {
  return _UserModel.fromJson(json);
}

/// @nodoc
mixin _$UserModel {
  String get id => throw _privateConstructorUsedError;
  UserRole get role => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get email => throw _privateConstructorUsedError;
  String get phone => throw _privateConstructorUsedError;
  AccountStatus get status => throw _privateConstructorUsedError;
  String? get region =>
      throw _privateConstructorUsedError; // Farmer / Buyer / Driver — their operating location
  String? get businessName => throw _privateConstructorUsedError; // Buyer
  String? get businessType => throw _privateConstructorUsedError; // Buyer
  String? get vehicleCapacity => throw _privateConstructorUsedError; // Driver
  String? get operatingRegion => throw _privateConstructorUsedError; // Driver
  String? get bio =>
      throw _privateConstructorUsedError; // Farmer / Buyer / Driver — free-text profile description
  String? get avatarPath => throw _privateConstructorUsedError;

  /// Serializes this UserModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of UserModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $UserModelCopyWith<UserModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $UserModelCopyWith<$Res> {
  factory $UserModelCopyWith(UserModel value, $Res Function(UserModel) then) =
      _$UserModelCopyWithImpl<$Res, UserModel>;
  @useResult
  $Res call({
    String id,
    UserRole role,
    String name,
    String email,
    String phone,
    AccountStatus status,
    String? region,
    String? businessName,
    String? businessType,
    String? vehicleCapacity,
    String? operatingRegion,
    String? bio,
    String? avatarPath,
  });
}

/// @nodoc
class _$UserModelCopyWithImpl<$Res, $Val extends UserModel>
    implements $UserModelCopyWith<$Res> {
  _$UserModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of UserModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? role = null,
    Object? name = null,
    Object? email = null,
    Object? phone = null,
    Object? status = null,
    Object? region = freezed,
    Object? businessName = freezed,
    Object? businessType = freezed,
    Object? vehicleCapacity = freezed,
    Object? operatingRegion = freezed,
    Object? bio = freezed,
    Object? avatarPath = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
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
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as AccountStatus,
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
            bio: freezed == bio
                ? _value.bio
                : bio // ignore: cast_nullable_to_non_nullable
                      as String?,
            avatarPath: freezed == avatarPath
                ? _value.avatarPath
                : avatarPath // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$UserModelImplCopyWith<$Res>
    implements $UserModelCopyWith<$Res> {
  factory _$$UserModelImplCopyWith(
    _$UserModelImpl value,
    $Res Function(_$UserModelImpl) then,
  ) = __$$UserModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    UserRole role,
    String name,
    String email,
    String phone,
    AccountStatus status,
    String? region,
    String? businessName,
    String? businessType,
    String? vehicleCapacity,
    String? operatingRegion,
    String? bio,
    String? avatarPath,
  });
}

/// @nodoc
class __$$UserModelImplCopyWithImpl<$Res>
    extends _$UserModelCopyWithImpl<$Res, _$UserModelImpl>
    implements _$$UserModelImplCopyWith<$Res> {
  __$$UserModelImplCopyWithImpl(
    _$UserModelImpl _value,
    $Res Function(_$UserModelImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of UserModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? role = null,
    Object? name = null,
    Object? email = null,
    Object? phone = null,
    Object? status = null,
    Object? region = freezed,
    Object? businessName = freezed,
    Object? businessType = freezed,
    Object? vehicleCapacity = freezed,
    Object? operatingRegion = freezed,
    Object? bio = freezed,
    Object? avatarPath = freezed,
  }) {
    return _then(
      _$UserModelImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
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
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as AccountStatus,
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
        bio: freezed == bio
            ? _value.bio
            : bio // ignore: cast_nullable_to_non_nullable
                  as String?,
        avatarPath: freezed == avatarPath
            ? _value.avatarPath
            : avatarPath // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$UserModelImpl implements _UserModel {
  const _$UserModelImpl({
    required this.id,
    required this.role,
    required this.name,
    required this.email,
    required this.phone,
    required this.status,
    this.region,
    this.businessName,
    this.businessType,
    this.vehicleCapacity,
    this.operatingRegion,
    this.bio,
    this.avatarPath,
  });

  factory _$UserModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$UserModelImplFromJson(json);

  @override
  final String id;
  @override
  final UserRole role;
  @override
  final String name;
  @override
  final String email;
  @override
  final String phone;
  @override
  final AccountStatus status;
  @override
  final String? region;
  // Farmer / Buyer / Driver — their operating location
  @override
  final String? businessName;
  // Buyer
  @override
  final String? businessType;
  // Buyer
  @override
  final String? vehicleCapacity;
  // Driver
  @override
  final String? operatingRegion;
  // Driver
  @override
  final String? bio;
  // Farmer / Buyer / Driver — free-text profile description
  @override
  final String? avatarPath;

  @override
  String toString() {
    return 'UserModel(id: $id, role: $role, name: $name, email: $email, phone: $phone, status: $status, region: $region, businessName: $businessName, businessType: $businessType, vehicleCapacity: $vehicleCapacity, operatingRegion: $operatingRegion, bio: $bio, avatarPath: $avatarPath)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$UserModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.role, role) || other.role == role) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.email, email) || other.email == email) &&
            (identical(other.phone, phone) || other.phone == phone) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.region, region) || other.region == region) &&
            (identical(other.businessName, businessName) ||
                other.businessName == businessName) &&
            (identical(other.businessType, businessType) ||
                other.businessType == businessType) &&
            (identical(other.vehicleCapacity, vehicleCapacity) ||
                other.vehicleCapacity == vehicleCapacity) &&
            (identical(other.operatingRegion, operatingRegion) ||
                other.operatingRegion == operatingRegion) &&
            (identical(other.bio, bio) || other.bio == bio) &&
            (identical(other.avatarPath, avatarPath) ||
                other.avatarPath == avatarPath));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    role,
    name,
    email,
    phone,
    status,
    region,
    businessName,
    businessType,
    vehicleCapacity,
    operatingRegion,
    bio,
    avatarPath,
  );

  /// Create a copy of UserModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$UserModelImplCopyWith<_$UserModelImpl> get copyWith =>
      __$$UserModelImplCopyWithImpl<_$UserModelImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$UserModelImplToJson(this);
  }
}

abstract class _UserModel implements UserModel {
  const factory _UserModel({
    required final String id,
    required final UserRole role,
    required final String name,
    required final String email,
    required final String phone,
    required final AccountStatus status,
    final String? region,
    final String? businessName,
    final String? businessType,
    final String? vehicleCapacity,
    final String? operatingRegion,
    final String? bio,
    final String? avatarPath,
  }) = _$UserModelImpl;

  factory _UserModel.fromJson(Map<String, dynamic> json) =
      _$UserModelImpl.fromJson;

  @override
  String get id;
  @override
  UserRole get role;
  @override
  String get name;
  @override
  String get email;
  @override
  String get phone;
  @override
  AccountStatus get status;
  @override
  String? get region; // Farmer / Buyer / Driver — their operating location
  @override
  String? get businessName; // Buyer
  @override
  String? get businessType; // Buyer
  @override
  String? get vehicleCapacity; // Driver
  @override
  String? get operatingRegion; // Driver
  @override
  String? get bio; // Farmer / Buyer / Driver — free-text profile description
  @override
  String? get avatarPath;

  /// Create a copy of UserModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$UserModelImplCopyWith<_$UserModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
