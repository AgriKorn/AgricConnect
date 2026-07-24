import 'package:flutter/material.dart';

import '../../../core/widgets/coming_soon_screen.dart';

class DriverHomeScreen extends StatelessWidget {
  const DriverHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComingSoonScreen(
      title: 'Driver',
      icon: Icons.local_shipping_outlined,
      message: 'Your availability toggle and active job will appear here.',
    );
  }
}
