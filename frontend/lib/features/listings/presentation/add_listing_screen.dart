import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/utils/freshness.dart';
import '../../../core/widgets/agri_bottom_sheet.dart';
import '../../../core/widgets/agri_toast.dart';
import '../../../core/widgets/responsive_content.dart';
import '../../auth/presentation/widgets/auth_visuals.dart';
import '../../home/application/farmer_dashboard_providers.dart';
import '../../marketplace/data/marketplace_repository.dart';
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
  final _imagePicker = ImagePicker();
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late final TextEditingController _quantityController;
  late final TextEditingController _shelfLifeController;
  late final TextEditingController _descriptionController;
  late double _freshnessScore;
  String? _imageUrl;
  bool _uploadingPhoto = false;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final scan = widget.prefill;
    // Deliberately not prefilled from scan.cropType: the on-device model has
    // a fixed 9-crop vocabulary and no "not a crop" class, so it always
    // guesses *something* — including confidently wrong guesses on
    // non-produce photos. Species identification is out of scope for this
    // scan feature (see crop_scan_presenter.dart); the farmer names their
    // own produce, the scan only supplies freshness/shelf-life/price.
    _nameController = TextEditingController();
    _priceController = TextEditingController(text: scan == null ? '' : scan.recommendedPrice.toStringAsFixed(0));
    _quantityController = TextEditingController();
    _shelfLifeController = TextEditingController(
      // Reads the scan's raw day count directly rather than re-parsing its
      // display label — that label switches to hour units under 1 day
      // (e.g. "8 Hours"), and grabbing the leading digits from it would
      // silently submit 8 *days* instead of 8 hours to the backend.
      text: scan == null ? '' : scan.shelfLifeDays.round().toString(),
    );
    _descriptionController = TextEditingController();
    _freshnessScore = (scan?.score ?? 100).toDouble();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    _shelfLifeController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final source = await showAgriBottomSheet<ImageSource>(
      context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Take a photo'),
            onTap: () => Navigator.of(context).pop(ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from gallery'),
            onTap: () => Navigator.of(context).pop(ImageSource.gallery),
          ),
        ],
      ),
    );
    if (source == null || !mounted) return;

    final picked = await _imagePicker.pickImage(source: source, maxWidth: 1600, imageQuality: 85);
    if (picked == null || !mounted) return;

    setState(() => _uploadingPhoto = true);
    try {
      final bytes = await picked.readAsBytes();
      final ext = picked.name.contains('.') ? picked.name.split('.').last.toLowerCase() : 'jpg';
      final contentType = ext == 'png' ? 'image/png' : 'image/jpeg';

      final publicUrl = await ref.read(marketplaceRepositoryProvider).uploadListingPhoto(
            bytes: bytes,
            fileName: picked.name,
            contentType: contentType,
          );

      if (!mounted) return;
      setState(() => _imageUrl = publicUrl);
    } on ApiException catch (e) {
      if (mounted) showAgriToast(context, e.message);
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });

    final cropType = _nameController.text.trim();
    try {
      String? region;
      try {
        final response = await ref.read(dioProvider).get(ApiEndpoints.userProfile);
        final data = response.data['data'] ?? response.data;
        region = data['profile']?['farmRegion']?.toString();
      } catch (_) {
        // Fall back to the default region coordinate below.
      }
      final (lat, long) = coordinatesForRegion(region);

      await ref.read(farmerListingsProvider.notifier).addListing(
            cropType: cropType,
            quantityKg: double.parse(_quantityController.text.trim()),
            freshnessScore: _freshnessScore.round(),
            shelfLifeDays: int.parse(_shelfLifeController.text.trim()),
            farmerLat: lat,
            farmerLong: long,
            pricePerKg: double.parse(_priceController.text.trim()),
            imageUrl: _imageUrl,
            description: _descriptionController.text.trim(),
          );

      if (!mounted) return;
      showAgriToast(context, '$cropType listed successfully');
      context.go('/farmer/listings');
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
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
            child: ResponsiveContent(
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
                          AuthFieldLabel('Photo', colorScheme),
                          const SizedBox(height: 8),
                          _PhotoPicker(
                            colorScheme: colorScheme,
                            imageUrl: _imageUrl,
                            uploading: _uploadingPhoto,
                            onTap: _uploadingPhoto ? null : _pickPhoto,
                          ),
                          const SizedBox(height: 16),
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
                                    AuthFieldLabel('Price per kg (GH₵)', colorScheme),
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
                                    AuthFieldLabel('Quantity (kg)', colorScheme),
                                    const SizedBox(height: 8),
                                    AuthTextField(
                                      controller: _quantityController,
                                      hint: 'e.g. 40',
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      icon: Icons.inventory_2_outlined,
                                      colorScheme: colorScheme,
                                      validator: (value) {
                                        final qty = double.tryParse(value?.trim() ?? '');
                                        return (qty == null || qty <= 0) ? 'Enter a valid quantity' : null;
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          AuthFieldLabel('Shelf life (days)', colorScheme),
                          const SizedBox(height: 8),
                          AuthTextField(
                            controller: _shelfLifeController,
                            hint: 'e.g. 7',
                            keyboardType: TextInputType.number,
                            icon: Icons.hourglass_bottom_rounded,
                            colorScheme: colorScheme,
                            validator: (value) {
                              final days = int.tryParse(value?.trim() ?? '');
                              return (days == null || days <= 0) ? 'Enter a valid number of days' : null;
                            },
                          ),
                          const SizedBox(height: 16),
                          AuthFieldLabel('Description (optional)', colorScheme),
                          const SizedBox(height: 8),
                          AuthTextField(
                            controller: _descriptionController,
                            hint: 'Add any extra details for buyers...',
                            colorScheme: colorScheme,
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 14),
                            Text(
                              _error!,
                              style: TextStyle(color: colorScheme.error, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ],
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
          ),
        ],
      ),
    );
  }
}

class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker({
    required this.colorScheme,
    required this.imageUrl,
    required this.uploading,
    required this.onTap,
  });

  final ColorScheme colorScheme;
  final String? imageUrl;
  final bool uploading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 160,
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colorScheme.outline.withValues(alpha: 0.3)),
        ),
        child: uploading
            ? const Center(child: CircularProgressIndicator())
            : imageUrl != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(imageUrl!, fit: BoxFit.cover),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'Change photo',
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              )
            : Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_a_photo_outlined, color: colorScheme.onSurfaceVariant, size: 26),
                    const SizedBox(height: 8),
                    Text(
                      'Add a photo of your produce',
                      style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
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
