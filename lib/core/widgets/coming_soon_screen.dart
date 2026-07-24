import 'package:flutter/material.dart';

import 'empty_state.dart';

/// Placeholder for a nav-shell destination whose real content is a later
/// phase (checklist: "work through phases in order"). Phase 2 is only the
/// navigation shell — Marketplace, Orders, Job History etc. get their real
/// content in their own phase.
class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({super.key, required this.title, required this.icon, required this.message});

  final String title;
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(child: EmptyState(icon: icon, message: message)),
    );
  }
}
