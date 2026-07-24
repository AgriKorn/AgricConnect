import 'package:flutter/material.dart';
import 'package:json_annotation/json_annotation.dart';

/// Matches the JWT `role` claim exactly (claude.md Backend Integration
/// Reference / Auth contract). Admin has no self-registration path but is
/// still a valid role value the client must be able to read from a token.
enum UserRole {
  @JsonValue('FARMER')
  farmer,
  @JsonValue('BUYER')
  buyer,
  @JsonValue('DRIVER')
  driver,
  @JsonValue('ADMIN')
  admin,
}

extension UserRoleX on UserRole {
  String get pathSegment => switch (this) {
        UserRole.farmer => 'farmer',
        UserRole.buyer => 'buyer',
        UserRole.driver => 'driver',
        UserRole.admin => 'admin',
      };

  String get label => switch (this) {
        UserRole.farmer => 'Farmer',
        UserRole.buyer => 'Buyer',
        UserRole.driver => 'Driver',
        UserRole.admin => 'Admin',
      };

  String get description => switch (this) {
        UserRole.farmer => 'List and sell your produce directly to buyers',
        UserRole.buyer => 'Discover and buy fresh produce from local farmers',
        UserRole.driver => 'Deliver orders and earn on your own schedule',
        UserRole.admin => 'Review and verify new accounts',
      };

  IconData get icon => switch (this) {
        UserRole.farmer => Icons.agriculture_rounded,
        UserRole.buyer => Icons.storefront_rounded,
        UserRole.driver => Icons.local_shipping_rounded,
        UserRole.admin => Icons.admin_panel_settings_rounded,
      };

  /// Resolves against the active colorScheme — never a hardcoded hex
  /// (checklist Non-Negotiable Rules).
  Color colorOf(ColorScheme colorScheme) => switch (this) {
        UserRole.farmer => colorScheme.primary,
        UserRole.buyer => colorScheme.tertiary,
        UserRole.driver => colorScheme.secondary,
        UserRole.admin => colorScheme.error,
      };
}
