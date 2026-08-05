import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/freshness.dart';
import '../../../core/widgets/agri_toast.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/responsive_content.dart';
import '../application/scan_controller.dart';
import '../data/scan_record.dart';

class ScanResultScreen extends ConsumerWidget {
  const ScanResultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scanState = ref.watch(scanControllerProvider);
    final result = scanState.lastResult;
    final colorScheme = Theme.of(context).colorScheme;

    if (result == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('AI Analysis (Preview)')),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: EmptyState(
                icon: Icons.camera_alt_outlined,
                message: 'No cached scan was found yet.',
                ctaLabel: 'Scan again',
                onCta: () => context.go('/farmer/scan'),
              ),
            ),
          ),
        ),
      );
    }

    final tint = freshnessColorFor(result.score, Theme.of(context).brightness);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          _ResultBackground(tint: tint),
          SafeArea(
            child: ResponsiveContent(
              child: Column(
              children: [
                _ResultAppBar(colorScheme: colorScheme, result: result),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                    children: [
                      _FreshnessCard(colorScheme: colorScheme, result: result, tint: tint),
                      if (result.attributes.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        _AttributeChips(colorScheme: colorScheme, attributes: result.attributes),
                      ],
                      if (result.imagePath != null) ...[
                        const SizedBox(height: 26),
                        Text(
                          'Visual Analysis',
                          style: TextStyle(color: colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 12),
                        _VisualAnalysisImage(colorScheme: colorScheme, imagePath: result.imagePath!),
                      ],
                    ],
                  ),
                ),
              ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: _ActionBar(colorScheme: colorScheme, result: result),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultBackground extends StatelessWidget {
  const _ResultBackground({required this.tint});

  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: Theme.of(context).scaffoldBackgroundColor),
        Positioned(top: -90, right: -60, child: _Blob(color: tint.withValues(alpha: 0.35), size: 260)),
        Positioned(bottom: -110, left: -70, child: _Blob(color: tint.withValues(alpha: 0.28), size: 280)),
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
          child: const SizedBox.expand(),
        ),
      ],
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _ResultAppBar extends StatelessWidget {
  const _ResultAppBar({required this.colorScheme, required this.result});

  final ColorScheme colorScheme;
  final ScanRecord result;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Row(
        children: [
          _CircleIconButton(
            colorScheme: colorScheme,
            icon: Icons.arrow_back_ios_new_rounded,
            iconSize: 16,
            onPressed: () => context.canPop() ? context.pop() : context.go('/farmer/home'),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'AI Analysis',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colorScheme.onSurface, fontSize: 19, fontWeight: FontWeight.w800),
                ),
                Text(
                  'Freshness only — you name the produce',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          _CircleIconButton(
            colorScheme: colorScheme,
            icon: Icons.ios_share_rounded,
            iconSize: 18,
            onPressed: () async {
              // Deliberately asserts neither a crop species nor a price — see
              // crop_scan_presenter.dart for why both were removed.
              await Clipboard.setData(ClipboardData(
                text:
                    '${result.score}% freshness (${result.qualityGrade}), '
                    '${result.shelfLifeLabel} shelf life.',
              ));
              if (context.mounted) {
                showAgriToast(context, 'Scan summary copied to clipboard');
              }
            },
          ),
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.colorScheme,
    required this.icon,
    required this.onPressed,
    this.iconSize = 18,
  });

  final ColorScheme colorScheme;
  final IconData icon;
  final VoidCallback onPressed;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
        shape: BoxShape.circle,
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.3)),
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, size: iconSize, color: colorScheme.onSurface),
        onPressed: onPressed,
      ),
    );
  }
}

class _FreshnessCard extends StatelessWidget {
  const _FreshnessCard({required this.colorScheme, required this.result, required this.tint});

  final ColorScheme colorScheme;
  final ScanRecord result;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          SizedBox(
            width: 190,
            height: 190,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: result.score / 100,
                    strokeWidth: 10,
                    strokeCap: StrokeCap.round,
                    backgroundColor: tint.withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation(tint),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${result.score}%',
                      style: TextStyle(color: colorScheme.onSurface, fontSize: 40, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      'Freshness Score',
                      style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          Row(
            children: [
              Expanded(
                child: _StatPill(
                  colorScheme: colorScheme,
                  icon: Icons.calendar_today_rounded,
                  value: result.shelfLifeLabel,
                  label: 'Shelf Life',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatPill(
                  colorScheme: colorScheme,
                  icon: Icons.local_fire_department_rounded,
                  value: result.qualityGrade,
                  label: 'Quality',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.colorScheme,
    required this.icon,
    required this.value,
    required this.label,
  });

  final ColorScheme colorScheme;
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: colorScheme.primary.withValues(alpha: 0.18), shape: BoxShape.circle),
            child: Icon(icon, size: 16, color: colorScheme.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w800, fontSize: 15),
                ),
                Text(
                  label,
                  style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 11.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The scan's qualifying signals — most importantly the low-confidence
/// "retake in better light" hint. [buildScanRecord] has always computed these
/// (see crop_scan_presenter.dart) but nothing rendered them, so the farmer saw
/// a bare score with no indication the model was unsure about it.
class _AttributeChips extends StatelessWidget {
  const _AttributeChips({required this.colorScheme, required this.attributes});

  final ColorScheme colorScheme;
  final List<ScanAttribute> attributes;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: attributes.map((attribute) {
        final isCaution = attribute.kind == ScanAttributeKind.caution;
        // Caution reads against the theme's error colour so a warning can't be
        // mistaken for a positive finding; everything else stays on primary.
        final accent = isCaution ? colorScheme.error : colorScheme.primary;
        final icon = attribute.kind.icon;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: accent.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: accent),
                const SizedBox(width: 6),
              ],
              Text(
                attribute.label,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

/// Just the actual captured photo — no attribute chips or other overlays.
class _VisualAnalysisImage extends StatelessWidget {
  const _VisualAnalysisImage({required this.colorScheme, required this.imagePath});

  final ColorScheme colorScheme;
  final String imagePath;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: kIsWeb
            ? _fallback()
            : Image.file(
                File(imagePath),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _fallback(),
              ),
      ),
    );
  }

  Widget _fallback() {
    return ColoredBox(
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      child: Icon(Icons.image_not_supported_outlined, color: colorScheme.onSurfaceVariant, size: 40),
    );
  }
}

class _ActionBar extends ConsumerWidget {
  const _ActionBar({required this.colorScheme, required this.result});

  final ColorScheme colorScheme;
  final ScanRecord result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 52,
              child: OutlinedButton.icon(
                onPressed: () => context.go('/farmer/scan'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colorScheme.onSurface,
                  side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.5)),
                  shape: const StadiumBorder(),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retake', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: () => context.push('/farmer/listings/add', extra: result),
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  shape: const StadiumBorder(),
                ),
                icon: const Icon(Icons.shopping_cart_outlined, size: 18),
                label: const Text('Create Listing', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
