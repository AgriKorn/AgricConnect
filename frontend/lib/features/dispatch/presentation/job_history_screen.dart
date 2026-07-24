import 'package:flutter/material.dart';

import '../../../core/widgets/coming_soon_screen.dart';

class JobHistoryScreen extends StatelessWidget {
  const JobHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComingSoonScreen(
      title: 'Job History',
      icon: Icons.history_rounded,
      message: 'Your completed deliveries will appear here.',
    );
  }
}
