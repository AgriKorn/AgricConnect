import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum UserRole { farmer, buyer, driver }

extension UserRoleInfo on UserRole {
  String get label {
    switch (this) {
      case UserRole.farmer:
        return 'Farmer';
      case UserRole.buyer:
        return 'Buyer';
      case UserRole.driver:
        return 'Driver';
    }
  }

  String get description {
    switch (this) {
      case UserRole.farmer:
        return 'List and sell your produce directly to buyers';
      case UserRole.buyer:
        return 'Discover and buy fresh produce from local farmers';
      case UserRole.driver:
        return 'Deliver orders and earn on your own schedule';
    }
  }

  IconData get icon {
    switch (this) {
      case UserRole.farmer:
        return Icons.agriculture_rounded;
      case UserRole.buyer:
        return Icons.storefront_rounded;
      case UserRole.driver:
        return Icons.local_shipping_rounded;
    }
  }

  Color get color {
    switch (this) {
      case UserRole.farmer:
        return AppColors.primary;
      case UserRole.buyer:
        return AppColors.accent;
      case UserRole.driver:
        return AppColors.forest;
    }
  }
}