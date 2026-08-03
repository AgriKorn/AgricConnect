import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../debug/component_gallery_screen.dart';
import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/application/session_state.dart';
import '../../features/auth/data/models/user_role.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/pending_verification_screen.dart';
import '../../features/auth/presentation/registration_screen.dart';
import '../../features/auth/presentation/role_selection_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/dispatch/presentation/driver_dispatch_screen.dart';
import '../../features/dispatch/presentation/driver_home_screen.dart';
import '../../features/dispatch/presentation/driver_profile_screen.dart';
import '../../features/dispatch/presentation/job_history_screen.dart';
import '../../features/home/presentation/farmer_dashboard_screen.dart';
import '../../features/home/presentation/farmer_profile_screen.dart';
import '../../features/listings/presentation/add_listing_screen.dart';
import '../../features/listings/presentation/my_listings_screen.dart';
import '../../features/marketplace/presentation/buyer_profile_screen.dart';
import '../../features/marketplace/presentation/marketplace_screen.dart';
import '../../features/notifications/presentation/alerts_screen.dart';
import '../../features/onboarding/application/onboarding_controller.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/orders/presentation/orders_screen.dart';
import '../../features/scan/data/scan_record.dart';
import '../../features/scan/presentation/scan_capture_screen.dart';
import '../../features/scan/presentation/scan_result_screen.dart';
import 'role_nav_shell.dart';
import 'splash_timer_controller.dart';

/// Bridges Riverpod's authControllerProvider to go_router's redirect
/// re-evaluation (checklist 2.1).
class GoRouterRefreshNotifier extends ChangeNotifier {
  GoRouterRefreshNotifier(Ref ref) {
    ref.listen<SessionState>(
      authControllerProvider,
      (_, _) => notifyListeners(),
    );
    ref.listen<bool>(splashTimerProvider, (_, _) => notifyListeners());
  }
}

UserRole _parseRole(String? segment) {
  return UserRole.values.firstWhere(
    (role) => role.pathSegment == segment,
    orElse: () => UserRole.farmer,
  );
}

String _homePathFor(UserRole role) => switch (role) {
  UserRole.farmer => '/farmer/home',
  UserRole.buyer => '/buyer/marketplace',
  UserRole.driver => '/driver/home',
  UserRole.admin => '/login', // no self-service admin shell (PRD 3.4)
};

bool _isPreAuthRoute(String location) {
  return location == '/login' ||
      location == '/forgot-password' ||
      location == '/role-selection' ||
      location.startsWith('/register/') ||
      location == '/pending-verification' ||
      location == '/splash' ||
      location == '/onboarding' ||
      location == '/debug/components';
}

/// Redirect guard (checklist 2.1): unauthenticated -> /login (via /onboarding
/// on first launch); authenticated but wrong-role path -> home for their
/// actual role; PENDING_VERIFICATION -> pending screen.
String? _redirect(
  SessionState session,
  bool onboardingComplete,
  bool minSplashElapsed,
  String location,
) {
  // Splash holds until both session restore AND the minimum display time
  // (splashTimerProvider) are done, so it's visible for a fixed floor even
  // when auth restoration resolves instantly.
  if (session.status == AuthStatus.restoring || !minSplashElapsed) {
    return location == '/splash' ? null : '/splash';
  }

  if (session.status == AuthStatus.unauthenticated) {
    if (!onboardingComplete) {
      return location == '/onboarding' ? null : '/onboarding';
    }
    if (location == '/splash' || location == '/onboarding') return '/login';
    return _isPreAuthRoute(location) ? null : '/login';
  }

  if (session.status == AuthStatus.pendingVerification) {
    return location == '/pending-verification' ? null : '/pending-verification';
  }

  // AuthStatus.authenticated
  final role = session.user?.role;
  if (role == null) return '/login';
  final home = _homePathFor(role);

  if (_isPreAuthRoute(location)) return home;
  if (!location.startsWith('/${role.pathSegment}')) return home;
  return null;
}

const _profileDestination = NavigationDestination(
  icon: Icon(Icons.person_outline_rounded),
  selectedIcon: Icon(Icons.person_rounded),
  label: 'Profile',
);

final goRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = GoRouterRefreshNotifier(ref);
  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refreshNotifier,
    redirect: (context, state) => _redirect(
      ref.read(authControllerProvider),
      ref.read(onboardingControllerProvider),
      ref.read(splashTimerProvider),
      state.matchedLocation,
    ),
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/role-selection',
        builder: (context, state) => const RoleSelectionScreen(),
      ),
      GoRoute(
        path: '/register/:role',
        builder: (context, state) =>
            RegistrationScreen(role: _parseRole(state.pathParameters['role'])),
      ),
      GoRoute(
        path: '/pending-verification',
        builder: (context, state) => const PendingVerificationScreen(),
      ),
      GoRoute(
        path: '/farmer/scan',
        builder: (context, state) => const ScanCaptureScreen(),
      ),
      GoRoute(
        path: '/farmer/scan/result',
        builder: (context, state) => const ScanResultScreen(),
      ),
      GoRoute(
        path: '/farmer/listings/add',
        builder: (context, state) => AddListingScreen(prefill: state.extra as ScanRecord?),
      ),
      if (kDebugMode)
        GoRoute(
          path: '/debug/components',
          builder: (context, state) => const ComponentGalleryScreen(),
        ),

      // Farmer: Home (Scan CTA) · My Listings · Alerts · Profile (checklist 2.2)
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => RoleNavShell(
          navigationShell: navigationShell,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined),
              selectedIcon: Icon(Icons.inventory_2_rounded),
              label: 'Listings',
            ),
            NavigationDestination(
              icon: Icon(Icons.notifications_outlined),
              selectedIcon: Icon(Icons.notifications_rounded),
              label: 'Alerts',
            ),
            _profileDestination,
          ],
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/farmer/home',
                builder: (context, state) => const FarmerDashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/farmer/listings',
                builder: (context, state) => const MyListingsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/farmer/alerts',
                builder: (context, state) => const AlertsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/farmer/profile',
                builder: (context, state) => const FarmerProfileScreen(),
              ),
            ],
          ),
        ],
      ),

      // Buyer: Marketplace · Orders · Alerts · Profile (checklist 2.2)
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => RoleNavShell(
          navigationShell: navigationShell,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.storefront_outlined),
              selectedIcon: Icon(Icons.storefront_rounded),
              label: 'Marketplace',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long_rounded),
              label: 'Orders',
            ),
            NavigationDestination(
              icon: Icon(Icons.notifications_outlined),
              selectedIcon: Icon(Icons.notifications_rounded),
              label: 'Alerts',
            ),
            _profileDestination,
          ],
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/buyer/marketplace',
                builder: (context, state) => const MarketplaceScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/buyer/orders',
                builder: (context, state) => const OrdersScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/buyer/alerts',
                builder: (context, state) => const AlertsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/buyer/profile',
                builder: (context, state) => const BuyerProfileScreen(),
              ),
            ],
          ),
        ],
      ),

      // Driver: Home (Availability toggle) · Jobs (Dispatch) · Job History · Alerts · Profile (checklist 2.2)
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => RoleNavShell(
          navigationShell: navigationShell,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.local_shipping_outlined),
              selectedIcon: Icon(Icons.local_shipping_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.assignment_outlined),
              selectedIcon: Icon(Icons.assignment_rounded),
              label: 'Jobs',
            ),
            NavigationDestination(
              icon: Icon(Icons.history_outlined),
              selectedIcon: Icon(Icons.history_rounded),
              label: 'History',
            ),
            NavigationDestination(
              icon: Icon(Icons.notifications_outlined),
              selectedIcon: Icon(Icons.notifications_rounded),
              label: 'Alerts',
            ),
            _profileDestination,
          ],
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/driver/home',
                builder: (context, state) => const DriverHomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/driver/jobs',
                builder: (context, state) => const DriverDispatchScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/driver/history',
                builder: (context, state) => const JobHistoryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/driver/alerts',
                builder: (context, state) => const AlertsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/driver/profile',
                builder: (context, state) => const DriverProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
