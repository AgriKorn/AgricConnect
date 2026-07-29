import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/network/api_exception.dart';
import '../data/orders_repository.dart';

/// Scans (or manually accepts) the farmer's listing QR code and calls
/// POST /transactions/:id/confirm-delivery, releasing escrow to the farmer.
/// Reachable from both the buyer's Orders screen and a driver's Job History.
class ConfirmDeliveryScreen extends ConsumerStatefulWidget {
  const ConfirmDeliveryScreen({super.key, required this.transactionId});

  final String transactionId;

  @override
  ConsumerState<ConfirmDeliveryScreen> createState() => _ConfirmDeliveryScreenState();
}

class _ConfirmDeliveryScreenState extends ConsumerState<ConfirmDeliveryScreen> {
  final MobileScannerController _controller = MobileScannerController();
  final _manualController = TextEditingController();
  bool _manualEntry = false;
  bool _submitting = false;
  bool _handled = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    _manualController.dispose();
    super.dispose();
  }

  Future<void> _submit(String qrHash) async {
    if (_submitting || qrHash.trim().isEmpty) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(ordersRepositoryProvider).confirmDelivery(
            transactionId: widget.transactionId,
            qrHash: qrHash.trim(),
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _submitting = false;
        _handled = false;
      });
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final value = capture.barcodes.firstOrNull?.rawValue;
    if (value == null || value.isEmpty) return;
    _handled = true;
    _submit(value);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Confirm Delivery'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Scan the QR code the farmer shows you to release payment and confirm delivery.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 13.5, height: 1.4),
              ),
            ),
            Expanded(
              child: _manualEntry
                  ? _ManualEntryForm(
                      controller: _manualController,
                      submitting: _submitting,
                      onSubmit: () => _submit(_manualController.text),
                    )
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        MobileScanner(controller: _controller, onDetect: _onDetect),
                        if (_submitting)
                          Container(
                            color: Colors.black54,
                            child: const Center(child: CircularProgressIndicator(color: Colors.white)),
                          ),
                        Center(
                          child: Container(
                            width: 240,
                            height: 240,
                            decoration: BoxDecoration(
                              border: Border.all(color: colorScheme.primary, width: 3),
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextButton(
                onPressed: () => setState(() {
                  _manualEntry = !_manualEntry;
                  _error = null;
                }),
                child: Text(
                  _manualEntry ? 'Use camera instead' : 'Enter code manually',
                  style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class _ManualEntryForm extends StatelessWidget {
  const _ManualEntryForm({required this.controller, required this.submitting, required this.onSubmit});

  final TextEditingController controller;
  final bool submitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white12,
              hintText: 'Paste or type the listing code',
              hintStyle: const TextStyle(color: Colors.white38),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: submitting ? null : onSubmit,
              child: submitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Confirm Delivery'),
            ),
          ),
        ],
      ),
    );
  }
}
