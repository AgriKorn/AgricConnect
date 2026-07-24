import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Freshness semantic scale (§ Status Colors in both theme docs): fixed
/// everywhere, never re-themed per screen — only swapped for the
/// light/dark variant of each status color.
Color freshnessColorFor(int score, Brightness brightness) {
  if (score >= 70) return AgriStatusColors.success(brightness); // fresh
  if (score >= 40) return AgriStatusColors.warning(brightness); // sell soon
  return AgriStatusColors.error(brightness); // urgent
}

String freshnessStateLabel(int score) {
  if (score >= 70) return 'Fresh';
  if (score >= 40) return 'Sell soon';
  return 'Urgent';
}
