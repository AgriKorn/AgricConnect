import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/freshness.dart';
import '../../auth/presentation/widgets/auth_visuals.dart';
import '../../home/application/farmer_dashboard_providers.dart';
import '../../home/data/farmer_dashboard_mock.dart';
import '../../scan/data/scan_record.dart';

/// Manual (or scan-assisted, via [prefill]) listing creation — the scan
/// flow is one way into this form, not the only way. Reuses the auth flow's
/// glass-card form primitives (widgets/auth_visuals.dart).
class AddListingScreen extends ConsumerStatefulWidget {
  const AddListingScreen({super.key, this.prefill});

  final ScanRecord? prefill;

  @override
  ConsumerState<AddListingScreen> createState() => _AddListingScreenState();
}

class _AddListingScreenState extends ConsumerState<AddListingScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late final TextEditingController _unitController;
  late final TextEditingController _quantityController;
  late final TextEditingController _descriptionController;
  late double _freshnessScore;
  String? _tag;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final scan = widget.prefill;
    _nameController = TextEditingController(text: scan?.cropType ?? '');
    _priceController = TextEditingController(text: scan == null ? '' : scan.recommendedPrice.toStringAsFixed(0));
    _unitController = TextEditingController(text: scan?.priceUnit ?? 'kg');
    _quantityController = TextEditingController();
    _descriptionController = TextEditingController();
    _freshnessScore = (scan?.score ?? 100).toDouble();
    _tag = switch (scan?.qualityGrade) {
      'Grade A' => 'Premium',
      'Grade B' => 'Verified',
      _ => null,
    };
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _unitController.dispose();
    _quantityController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    await Future<void>.delayed(const Duration(milliseconds: 600));

    final cropType = _nameController.text.trim();
    ref.read(farmerListingsProvider.notifier).addListing(
          FarmerListingSummary(
            id: 'l-${DateTime.now().millisecondsSinceEpoch}',
            cropType: cropType,
            freshnessScore: _freshnessScore.round(),
            price: double.tryParse(_priceController.text.trim()) ?? 0,
            unit: _unitController.text.trim(),
            status: 'Active',
            tag: _tag,
          ),
        );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$cropType listed successfully')),
    );
    context.go('/farmer/listings');
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final prefill = widget.prefill;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          AmbientBackground(colorScheme: colorScheme),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        AuthBackButton(
                          colorScheme: colorScheme,
                          onPressed: () => context.canPop() ? context.pop() : context.go('/farmer/listings'),
                        ),
                        Expanded(
                          child: Text(
                            'Add Listing',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: colorScheme.onSurface, fontSize: 19, fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(width: 40),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (prefill != null)
                      _PrefillBanner(colorScheme: colorScheme, prefill: prefill)
                    else
                      Center(
                        child: TextButton.icon(
                          onPressed: () => context.go('/farmer/scan'),
                          icon: Icon(Icons.center_focus_strong_rounded, size: 16, color: colorScheme.primary),
                          label: Text(
                            'Have produce in hand? Scan instead',
                            style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w600, fontSize: 12.5),
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    AuthGlassCard(
                      colorScheme: colorScheme,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AuthFieldLabel('Crop / Produce Name', colorScheme),
                          const SizedBox(height: 8),
                          AuthTextField(
                            controller: _nameController,
                            hint: 'e.g. Roma Tomatoes',
                            icon: Icons.eco_outlined,
                            colorScheme: colorScheme,
                            validator: (value) =>
                                (value == null || value.trim().isEmpty) ? 'Enter a crop name' : null,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    AuthFieldLabel('Price (GH₵)', colorScheme),
                                    const SizedBox(height: 8),
                                    AuthTextField(
                                      controller: _priceController,
                                      hint: '0.00',
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      colorScheme: colorScheme,
                                      validator: (value) {
                                        final price = double.tryParse(value?.trim() ?? '');
                                        return (price == null || price <= 0) ? 'Enter a valid price' : null;
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    AuthFieldLabel('Unit', colorScheme),
                                    const SizedBox(height: 8),
                                    AuthTextField(
                                      controller: _unitController,
                                      hint: 'kg, box, bag...',
                                      colorScheme: colorScheme,
                                      validator: (value) =>
                                          (value == null || value.trim().isEmpty) ? 'Required' : null,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          AuthFieldLabel('Quantity Available (optional)', colorScheme),
                          const SizedBox(height: 8),
                          AuthTextField(
                            controller: _quantityController,
                            hint: 'e.g. 40',
                            keyboardType: TextInputType.number,
                            icon: Icons.inventory_2_outlined,
                            colorScheme: colorScheme,
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              AuthFieldLabel('Freshness Score', colorScheme),
                              Text(
                                '${_freshnessScore.round()}%',
                                style: TextStyle(
                                  color: freshnessColorFor(_freshnessScore.round(), Theme.of(context).brightness),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          SliderTheme(
                            data: SliderThemeData(
                              activeTrackColor: colorScheme.primary,
                              thumbColor: colorScheme.primary,
                              inactiveTrackColor: colorScheme.surfaceContainerHighest,
                              overlayColor: colorScheme.primary.withValues(alpha: 0.15),
                            ),
                            child: Slider(
                              value: _freshnessScore,
                              min: 0,
                              max: 100,
                              divisions: 100,
                              onChanged: (value) => setState(() => _freshnessScore = value),
                            ),
                          ),
                          const SizedBox(height: 4),
                          AuthFieldLabel('Tag (optional)', colorScheme),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: [
                              _TagChoiceChip(
                                label: 'None',
                                selected: _tag == null,
                                colorScheme: colorScheme,
                                onTap: () => setState(() => _tag = null),
                              ),
                              _TagChoiceChip(
                                label: 'Verified',
                                selected: _tag == 'Verified',
                                colorScheme: colorScheme,
                                onTap: () => setState(() => _tag = 'Verified'),
                              ),
                              _TagChoiceChip(
                                label: 'Premium',
                                selected: _tag == 'Premium',
                                colorScheme: colorScheme,
                                onTap: () => setState(() => _tag = 'Premium'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          AuthFieldLabel('Description (optional)', colorScheme),
                          const SizedBox(height: 8),
                          AuthTextField(
                            controller: _descriptionController,
                            hint: 'Add any extra details for buyers...',
                            colorScheme: colorScheme,
                          ),
                          const SizedBox(height: 22),
                          AuthPillButton(
                            label: _submitting ? 'Publishing...' : 'Publish Listing',
                            loading: _submitting,
                            onPressed: _submit,
                            colorScheme: colorScheme,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrefillBanner extends StatelessWidget {
  const _PrefillBanner({required this.colorScheme, required this.prefill});

  final ColorScheme colorScheme;
  final ScanRecord prefill;

  @override
  Widget build(BuildContext context) {
    final tint = freshnessColorFor(prefill.score, Theme.of(context).brightness);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tint.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome_rounded, color: tint, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Pre-filled from your AI scan (${prefill.score}% freshness, ${prefill.qualityGrade}).',
              style: TextStyle(color: colorScheme.onSurface, fontSize: 12.5, fontWeight: FontWeight.w600, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}

class _TagChoiceChip extends StatelessWidget {
  const _TagChoiceChip({
    required this.label,
    required this.selected,
    required this.colorScheme,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? colorScheme.primary : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
          border: selected ? null : Border.all(color: colorScheme.outline.withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
