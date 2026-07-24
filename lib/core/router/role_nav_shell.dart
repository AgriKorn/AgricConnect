import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// One bottom-nav shell reused by each role's StatefulShellRoute
/// (checklist 2.2) — each role only ever sees its own destinations.
/// Rendered as a floating pill rather than a docked Material NavigationBar,
/// matching the marketplace/auth screens' visual language.
class RoleNavShell extends StatelessWidget {
  const RoleNavShell({
    super.key,
    required this.navigationShell,
    required this.destinations,
  });

  final StatefulNavigationShell navigationShell;
  final List<NavigationDestination> destinations;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: _FloatingNavBar(
          colorScheme: colorScheme,
          currentIndex: navigationShell.currentIndex,
          destinations: destinations,
          onSelect: (index) => navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          ),
        ),
      ),
    );
  }
}

class _FloatingNavBar extends StatelessWidget {
  const _FloatingNavBar({
    required this.colorScheme,
    required this.currentIndex,
    required this.destinations,
    required this.onSelect,
  });

  final ColorScheme colorScheme;
  final int currentIndex;
  final List<NavigationDestination> destinations;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Row(
        children: [
          for (var i = 0; i < destinations.length; i++)
            Expanded(
              child: _NavItem(
                destination: destinations[i],
                active: i == currentIndex,
                colorScheme: colorScheme,
                onTap: () => onSelect(i),
              ),
            ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.active,
    required this.colorScheme,
    required this.onTap,
  });

  final NavigationDestination destination;
  final bool active;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? colorScheme.primary : colorScheme.onSurfaceVariant;
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconTheme(
              data: IconThemeData(color: color, size: 22),
              child: active ? (destination.selectedIcon ?? destination.icon) : destination.icon,
            ),
            const SizedBox(height: 3),
            Text(
              destination.label,
              style: TextStyle(color: color, fontSize: 11, fontWeight: active ? FontWeight.w700 : FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
