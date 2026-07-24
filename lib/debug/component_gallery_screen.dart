import 'package:flutter/material.dart';

import '../core/widgets/agri_bottom_sheet.dart';
import '../core/widgets/agri_button.dart';
import '../core/widgets/agri_card.dart';
import '../core/widgets/agri_dialog.dart';
import '../core/widgets/empty_state.dart';
import '../core/widgets/freshness_gauge.dart';
import '../core/widgets/status_chip.dart';

/// Throwaway debug screen (checklist 0.5 exit criteria) rendering every
/// shared design-system widget. Only reachable via a kDebugMode-gated link
/// on the login screen — never shipped as a real feature.
class ComponentGalleryScreen extends StatelessWidget {
  const ComponentGalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Component Gallery')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _SectionTitle('AgriButton'),
          AgriCard(
            child: Column(
              children: [
                AgriButton(label: 'Primary', onPressed: () {}),
                const SizedBox(height: 10),
                AgriButton(label: 'Secondary', variant: AgriButtonVariant.secondary, onPressed: () {}),
                const SizedBox(height: 10),
                AgriButton(label: 'Destructive', variant: AgriButtonVariant.destructive, onPressed: () {}),
                const SizedBox(height: 10),
                AgriButton(label: 'Loading', loading: true, onPressed: () {}),
                const SizedBox(height: 10),
                AgriButton(label: 'Disabled', onPressed: null),
              ],
            ),
          ),
          const _SectionTitle('AgriCard'),
          AgriCard(child: const Text('Elevation 1, surface-tinted, 20px radius.')),
          const _SectionTitle('FreshnessGauge'),
          AgriCard(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: const [
                FreshnessGauge(score: 86, size: 72),
                FreshnessGauge(score: 54, size: 72),
                FreshnessGauge(score: 22, size: 72),
              ],
            ),
          ),
          const _SectionTitle('StatusChip'),
          AgriCard(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: const [
                StatusChip(label: 'Escrow released', tone: AgriStatusTone.positive),
                StatusChip(label: 'Escrow held', tone: AgriStatusTone.warning),
                StatusChip(label: 'Dispatch pending', tone: AgriStatusTone.neutral),
                StatusChip(label: 'Expired', tone: AgriStatusTone.danger),
              ],
            ),
          ),
          const _SectionTitle('EmptyState'),
          AgriCard(
            child: EmptyState(
              icon: Icons.inbox_outlined,
              message: 'Nothing here yet.',
              ctaLabel: 'Take action',
              onCta: () {},
            ),
          ),
          const _SectionTitle('AgriDialog / AgriBottomSheet'),
          AgriCard(
            child: Row(
              children: [
                Expanded(
                  child: AgriButton(
                    label: 'Show dialog',
                    variant: AgriButtonVariant.secondary,
                    onPressed: () => showAgriDialog(
                      context,
                      title: 'Example dialog',
                      message: 'This is the shared AgriDialog wrapper.',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AgriButton(
                    label: 'Show sheet',
                    variant: AgriButtonVariant.secondary,
                    onPressed: () => showAgriBottomSheet(
                      context,
                      builder: (context) => const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Text('This is the shared AgriBottomSheet wrapper.'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Text(title, style: Theme.of(context).textTheme.titleLarge),
    );
  }
}
