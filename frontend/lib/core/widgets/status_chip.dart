import 'package:flutter/material.dart';

/// Shared status badge (design system section 5.5): escrow, dispatch,
/// verification states. Color is never the only signal — always paired
/// with a text label. Tones map to theme colorScheme container tokens,
/// which are seeded from the exact semantic hex values in section 3.
enum AgriStatusTone { positive, warning, neutral, danger }

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, required this.tone});

  final String label;
  final AgriStatusTone tone;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final (Color background, Color foreground) = switch (tone) {
      AgriStatusTone.positive => (colorScheme.primaryContainer, colorScheme.onPrimaryContainer),
      AgriStatusTone.warning => (colorScheme.tertiaryContainer, colorScheme.onTertiaryContainer),
      AgriStatusTone.neutral => (colorScheme.secondaryContainer, colorScheme.onSecondaryContainer),
      AgriStatusTone.danger => (colorScheme.errorContainer, colorScheme.onErrorContainer),
    };

    return Chip(
      label: Text(label),
      backgroundColor: background,
      labelStyle: TextStyle(color: foreground, fontWeight: FontWeight.w600, fontSize: 12.5),
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}
