import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/motion.dart';
import '../../../core/widgets/theme_toggle_button.dart';
import '../data/models/user_role.dart';
import 'widgets/auth_visuals.dart';

const _markAsset = 'assets/images/agri_mark.png';

/// Checklist 1.1: large icon-led cards, single-select + explicit Continue
/// (not tap-to-navigate) so the choice is confirmable before committing to
/// a registration form. Admin has no self-registration path per PRD 3.4, so
/// it never appears here. Shares its visual language (widgets/auth_visuals)
/// with login and registration.
class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  static const _selectableRoles = [UserRole.farmer, UserRole.buyer, UserRole.driver];

  UserRole? _selected;

  void _goBack(BuildContext context) => context.canPop() ? context.pop() : context.go('/login');

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final selected = _selected;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          AmbientBackground(colorScheme: colorScheme),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AuthBackButton(colorScheme: colorScheme, onPressed: () => _goBack(context)),
                      const Spacer(),
                      const ThemeToggleButton(),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: 72,
                    height: 72,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: colorScheme.outline.withValues(alpha: 0.4)),
                    ),
                    child: Image.asset(_markAsset, fit: BoxFit.contain),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Welcome to AgriConnect',
                    style: TextStyle(color: colorScheme.onSurface, fontSize: 27, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Choose your role to get started',
                    style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 15),
                  ),
                  const SizedBox(height: 28),
                  for (final role in _selectableRoles) ...[
                    _RoleOptionCard(
                      role: role,
                      colorScheme: colorScheme,
                      selected: selected == role,
                      onTap: () => setState(() => _selected = role),
                    ),
                    const SizedBox(height: 16),
                  ],
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton(
                      onPressed: selected == null ? null : () => context.push('/register/${selected.pathSegment}'),
                      style: FilledButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        disabledBackgroundColor: colorScheme.primary.withValues(alpha: 0.35),
                        disabledForegroundColor: colorScheme.onPrimary.withValues(alpha: 0.7),
                        shape: const StadiumBorder(),
                      ),
                      child: const Text('Continue', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          "Already have an account? ",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _goBack(context),
                        child: Text('Log In', style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.touch_app_outlined, size: 15, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
                      const SizedBox(width: 6),
                      Text(
                        'Tap a card to select',
                        style: TextStyle(color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7), fontSize: 12.5),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleOptionCard extends StatelessWidget {
  const _RoleOptionCard({
    required this.role,
    required this.colorScheme,
    required this.selected,
    required this.onTap,
  });

  final UserRole role;
  final ColorScheme colorScheme;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: kAgriConnectDuration,
        curve: kAgriConnectCurve,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? colorScheme.primary : colorScheme.outline.withValues(alpha: 0.25),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(role.icon, color: colorScheme.primary, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    role.label,
                    style: TextStyle(color: colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    role.description,
                    style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13, height: 1.35),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            AnimatedContainer(
              duration: kAgriConnectDuration,
              curve: kAgriConnectCurve,
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? colorScheme.primary : Colors.transparent,
                border: selected ? null : Border.all(color: colorScheme.outline.withValues(alpha: 0.4)),
              ),
              child: selected ? Icon(Icons.check_rounded, color: colorScheme.onPrimary, size: 16) : null,
            ),
          ],
        ),
      ),
    );
  }
}
