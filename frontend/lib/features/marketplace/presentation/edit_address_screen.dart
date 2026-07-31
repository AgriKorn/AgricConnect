import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../auth/presentation/widgets/auth_visuals.dart';
import '../application/buyer_profile_providers.dart';
import '../data/address_repository.dart';

/// Add or edit a real delivery address (GET/POST/PATCH/DELETE
/// /api/users/addresses) — the buyer's own data, not a mock.
class EditAddressScreen extends ConsumerStatefulWidget {
  const EditAddressScreen({super.key, this.address});

  /// Null when adding a new address.
  final DeliveryAddress? address;

  @override
  ConsumerState<EditAddressScreen> createState() => _EditAddressScreenState();
}

class _EditAddressScreenState extends ConsumerState<EditAddressScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _labelController = TextEditingController(text: widget.address?.label ?? '');
  late final _addressLineController = TextEditingController(text: widget.address?.addressLine ?? '');
  late final _regionController = TextEditingController(text: widget.address?.region ?? '');
  late bool _isDefault = widget.address?.isDefault ?? false;
  bool _submitting = false;
  bool _deleting = false;
  String? _error;

  bool get _isEditing => widget.address != null;

  @override
  void dispose() {
    _labelController.dispose();
    _addressLineController.dispose();
    _regionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting || _deleting) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final controller = ref.read(deliveryAddressesProvider.notifier);
      if (_isEditing) {
        await controller.edit(
          widget.address!.id,
          label: _labelController.text.trim(),
          addressLine: _addressLineController.text.trim(),
          region: _regionController.text.trim(),
          isDefault: _isDefault,
        );
      } else {
        await controller.add(
          label: _labelController.text.trim(),
          addressLine: _addressLineController.text.trim(),
          region: _regionController.text.trim(),
          isDefault: _isDefault,
        );
      }
      if (!mounted) return;
      context.pop();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _delete() async {
    if (_submitting || _deleting) return;
    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      await ref.read(deliveryAddressesProvider.notifier).remove(widget.address!.id);
      if (!mounted) return;
      context.pop();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final busy = _submitting || _deleting;

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
                        AuthBackButton(colorScheme: colorScheme, onPressed: () => context.pop()),
                        Expanded(
                          child: Text(
                            _isEditing ? 'Edit Address' : 'Add Address',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: colorScheme.onSurface, fontSize: 19, fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(width: 40),
                      ],
                    ),
                    const SizedBox(height: 20),
                    AuthGlassCard(
                      colorScheme: colorScheme,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AuthFieldLabel('Label', colorScheme),
                          const SizedBox(height: 8),
                          AuthTextField(
                            controller: _labelController,
                            hint: 'e.g. Home, Office',
                            colorScheme: colorScheme,
                            validator: (value) => (value == null || value.trim().isEmpty) ? 'Enter a label' : null,
                          ),
                          const SizedBox(height: 16),
                          AuthFieldLabel('Address', colorScheme),
                          const SizedBox(height: 8),
                          AuthTextField(
                            controller: _addressLineController,
                            hint: 'e.g. House No. 24, Spintex Road, Accra',
                            colorScheme: colorScheme,
                            validator: (value) => (value == null || value.trim().isEmpty) ? 'Enter an address' : null,
                          ),
                          const SizedBox(height: 16),
                          AuthFieldLabel('Region (optional)', colorScheme),
                          const SizedBox(height: 8),
                          AuthTextField(
                            controller: _regionController,
                            hint: 'e.g. Greater Accra',
                            colorScheme: colorScheme,
                          ),
                          const SizedBox(height: 8),
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            value: _isDefault,
                            onChanged: (value) => setState(() => _isDefault = value ?? false),
                            title: Text(
                              'Set as default delivery address',
                              style: TextStyle(color: colorScheme.onSurface, fontSize: 14),
                            ),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 10),
                            Text(_error!, style: TextStyle(color: colorScheme.error, fontSize: 13, fontWeight: FontWeight.w600)),
                          ],
                          const SizedBox(height: 16),
                          AuthPillButton(
                            label: _submitting ? 'Saving...' : (_isEditing ? 'Save Changes' : 'Add Address'),
                            loading: _submitting,
                            onPressed: _submit,
                            colorScheme: colorScheme,
                          ),
                          if (_isEditing) ...[
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: TextButton.icon(
                                onPressed: busy ? null : _delete,
                                icon: _deleting
                                    ? SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.error),
                                      )
                                    : Icon(Icons.delete_outline_rounded, color: colorScheme.error, size: 18),
                                label: Text(
                                  _deleting ? 'Removing...' : 'Remove Address',
                                  style: TextStyle(color: colorScheme.error, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                          ],
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
