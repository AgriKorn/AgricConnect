import 'package:flutter/material.dart';

import '../../../core/widgets/coming_soon_screen.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComingSoonScreen(
      title: 'Orders',
      icon: Icons.receipt_long_outlined,
      message: 'Your orders and escrow status will appear here.',
    );
  }
}
