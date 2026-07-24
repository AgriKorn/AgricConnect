import 'package:flutter/material.dart';

/// Shared elevated card (design system section 5.2): the app's one "depth"
/// primitive, used for listings, scan results, dispatch jobs, audit entries.
class AgriCard extends StatelessWidget {
  const AgriCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(20));
    return Card(
      elevation: 1,
      surfaceTintColor: Theme.of(context).colorScheme.primary,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
