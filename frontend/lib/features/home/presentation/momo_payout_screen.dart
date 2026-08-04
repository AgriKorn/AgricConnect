import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/agri_button.dart';
import '../../../core/widgets/agri_card.dart';
import '../../auth/data/auth_repository.dart';

const _networks = [
  (code: 'MTN', label: 'MTN Mobile Money'),
  (code: 'VOD', label: 'Vodafone Cash'),
  (code: 'ATL', label: 'AirtelTigo Money'),
];

/// Lets a farmer register the Mobile Money number their sales are paid out
/// to. A listing cannot be created until this is on file (backend rejects
/// POST /listings with PAYOUT_NOT_CONFIGURED otherwise), so this screen is
/// reached from Farmer Profile > Payment Methods.
class MomoPayoutScreen extends ConsumerStatefulWidget {
  const MomoPayoutScreen({super.key});

  @override
  ConsumerState<MomoPayoutScreen> createState() => _MomoPayoutScreenState();
}

class _MomoPayoutScreenState extends ConsumerState<MomoPayoutScreen> {
  final _numberController = TextEditingController();
  String _networkCode = _networks.first.code;

  bool _loading = true;
  bool _verifying = false;
  bool _saving = false;
  String? _error;
  String? _verifiedAccountName;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _numberController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final profile = await ref.read(authRepositoryProvider).fetchProfile();
      if (!mounted) return;
      _numberController.text = profile.momoNumber ?? '';
      if (profile.momoNetwork != null) _networkCode = profile.momoNetwork!;
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verify() async {
    setState(() {
      _verifying = true;
      _error = null;
      _verifiedAccountName = null;
    });
    try {
      final name = await ref.read(authRepositoryProvider).resolveMomoAccount(
            accountNumber: _numberController.text.trim(),
            bankCode: _networkCode,
          );
      if (!mounted) return;
      setState(() => _verifiedAccountName = name.isEmpty ? 'Verified' : name);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).updateProfile({
        'momoNumber': _numberController.text.trim(),
        'momoNetwork': _networkCode,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mobile Money payout details saved')),
      );
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Payment Methods')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Mobile Money payout number',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "This is where you'll be paid when a buyer's delivery is confirmed. "
                    "You must add this before you can create a listing.",
                    style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13.5, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  AgriCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: _networkCode,
                          decoration: const InputDecoration(labelText: 'Mobile Money network', border: OutlineInputBorder()),
                          items: [
                            for (final network in _networks) DropdownMenuItem(value: network.code, child: Text(network.label)),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              _networkCode = value;
                              _verifiedAccountName = null;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _numberController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'MoMo number',
                            hintText: '+233 00 000 0000',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) => setState(() => _verifiedAccountName = null),
                        ),
                        const SizedBox(height: 12),
                        if (_verifiedAccountName != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.verified_rounded, color: colorScheme.primary, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Verified: $_verifiedAccountName',
                                    style: TextStyle(color: colorScheme.onPrimaryContainer, fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          AgriButton(
                            label: _verifying ? 'Verifying...' : 'Verify account name',
                            variant: AgriButtonVariant.secondary,
                            loading: _verifying,
                            onPressed: _numberController.text.trim().isEmpty ? null : _verify,
                          ),
                        if (_error != null) ...[
                          const SizedBox(height: 10),
                          Text(_error!, style: TextStyle(color: colorScheme.error, fontSize: 13, fontWeight: FontWeight.w600)),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  AgriButton(
                    label: _saving ? 'Saving...' : 'Save',
                    loading: _saving,
                    onPressed: _numberController.text.trim().isEmpty ? null : _save,
                  ),
                ],
              ),
      ),
    );
  }
}
