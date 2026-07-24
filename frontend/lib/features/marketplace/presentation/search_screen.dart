import 'package:flutter/material.dart';

import '../../../core/widgets/coming_soon_screen.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComingSoonScreen(
      title: 'Search',
      icon: Icons.search_rounded,
      message: 'Search and filter listings by crop, freshness, and location.',
    );
  }
}
