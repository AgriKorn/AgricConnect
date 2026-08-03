import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/utils/freshness.dart';
import '../../../core/widgets/agri_bottom_sheet.dart';
import '../../../core/widgets/agri_toast.dart';
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
  String? _imagePath;
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
    _imagePath = scan?.imagePath;
  }

  Future<void> _pickImage() async {
    final source = await showAgriBottomSheet<ImageSource>(
      context,
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        );
      },
    );
    if (source == null || !mounted) return;
    final file = await ImagePicker().pickImage(source: source, maxWidth: 1600, imageQuality: 85);
    if (file == null || !mounted) return;
    setState(() => _imagePath = file.path);
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
            imagePath: _imagePath,
          ),
        );

    if (!mounted) return;
    showAgriToast(context, '$cropType listed successfully');
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
                          AuthFieldLabel('Photo', colorScheme),
                          const SizedBox(height: 8),
                          _ListingPhotoPicker(
                            colorScheme: colorScheme,
                            imagePath: _imagePath,
                            fromScan: widget.prefill != null && _imagePath == widget.prefill?.imagePath,
                            onTap: _pickImage,
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

class _ListingPhotoPicker extends StatelessWidget {
  const _ListingPhotoPicker({
    required this.colorScheme,
    required this.imagePath,
    required this.fromScan,
    required this.onTap,
  });

  final ColorScheme colorScheme;
  final String? imagePath;
  final bool fromScan;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 160,
          width: double.infinity,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colorScheme.outline.withValues(alpha: 0.3)),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (imagePath != null && !kIsWeb)
                Image.file(
                  File(imagePath!),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => _placeholder(),
                )
              else
                _placeholder(),
              if (imagePath != null)
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.edit_rounded, size: 14, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          fromScan ? 'From scan · Change' : 'Change',
                          style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add_a_photo_outlined, size: 30, color: colorScheme.onSurfaceVariant),
          const SizedBox(height: 8),
          Text(
            'Add a photo',
            style: TextStyle(color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600, fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}
