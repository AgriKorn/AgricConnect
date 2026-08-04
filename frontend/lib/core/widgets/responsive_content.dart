import 'package:flutter/material.dart';

/// Caps a single-column screen's content width and centers it on wide
/// viewports (tablet/desktop Flutter Web) so forms and lists don't stretch
/// edge-to-edge into unreadably long lines — full-width on phone-sized
/// screens, where [maxWidth] never binds anyway.
class ResponsiveContent extends StatelessWidget {
  const ResponsiveContent({super.key, required this.child, this.maxWidth = 640});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
