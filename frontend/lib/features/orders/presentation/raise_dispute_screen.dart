import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../auth/presentation/widgets/auth_visuals.dart';
import '../data/orders_repository.dart';

const _disputeTypes = {
  'WRONG_PRODUCE': 'Wrong produce delivered',
  'NON_DELIVERY': 'Never delivered',
  'PAYMENT_ISSUE': 'Payment issue',
  'OTHER': 'Something else',
};

class RaiseDisputeScreen extends ConsumerStatefulWidget {
  const RaiseDisputeScreen({super.key, required this.transactionId});

  final String transactionId;

  @override
  ConsumerState<RaiseDisputeScreen> createState() => _RaiseDisputeScreenState();
}

class _RaiseDisputeScreenState extends ConsumerState<RaiseDisputeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  String _type = 'WRONG_PRODUCE';
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(ordersRepositoryProvider).raiseDispute(
            transactionId: widget.transactionId,
            type: _type,
            description: _descriptionController.text.trim(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dispute submitted. An admin will review it shortly.')),
      );
      context.pop(true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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
                            'Report a Problem',
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
                          AuthFieldLabel('What went wrong?', colorScheme),
                          const SizedBox(height: 8),
                          ..._disputeTypes.entries.map(
                            (entry) => RadioListTile<String>(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              title: Text(entry.value, style: TextStyle(color: colorScheme.onSurface, fontSize: 14)),
                              value: entry.key,
                              groupValue: _type,
                              onChanged: (value) => setState(() => _type = value!),
                            ),
                          ),
                          const SizedBox(height: 12),
                          AuthFieldLabel('Details', colorScheme),
                          const SizedBox(height: 8),
                          AuthTextField(
                            controller: _descriptionController,
                            hint: 'Describe what happened (at least 10 characters)...',
                            colorScheme: colorScheme,
                            validator: (value) => (value == null || value.trim().length < 10)
                                ? 'Please provide at least 10 characters'
                                : null,
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 14),
                            Text(_error!, style: TextStyle(color: colorScheme.error, fontSize: 13, fontWeight: FontWeight.w600)),
                          ],
                          const SizedBox(height: 20),
                          AuthPillButton(
                            label: _submitting ? 'Submitting...' : 'Submit Report',
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
