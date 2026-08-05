import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/ambient_background.dart';
import '../../../core/widgets/empty_state.dart';
import '../data/dispatch_repository.dart';

class JobHistoryScreen extends ConsumerStatefulWidget {
  const JobHistoryScreen({super.key});

  @override
  ConsumerState<JobHistoryScreen> createState() => _JobHistoryScreenState();
}

class _JobHistoryScreenState extends ConsumerState<JobHistoryScreen> {
  bool _loading = true;
  String? _error;
  List<DispatchJobModel> _jobs = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(dispatchRepositoryProvider);
      final results = await Future.wait([
        repo.fetchJobs(status: 'ACCEPTED'),
        repo.fetchJobs(status: 'IN_TRANSIT'),
        repo.fetchJobs(status: 'DELIVERED'),
        repo.fetchJobs(status: 'COMPLETED'),
      ]);
      if (!mounted) return;
      final combined = [...results[0], ...results[1], ...results[2], ...results[3]]
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      setState(() {
        _jobs = combined;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
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
            child: RefreshIndicator(
              onRefresh: _load,
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? EmptyState(
                          icon: Icons.wifi_off_rounded,
                          message: 'Could not load your delivery history. Pull to refresh, or tap Retry.',
                          ctaLabel: 'Retry',
                          onCta: _load,
                        )
                      : _jobs.isEmpty
                      ? const EmptyState(
                          icon: Icons.history_rounded,
                          message: 'You have not completed any deliveries yet.',
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                          children: [
                            Text(
                              'Job History',
                              style: TextStyle(color: colorScheme.onSurface, fontSize: 22, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 16),
                            ..._jobs.map((job) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _HistoryTile(
                                    colorScheme: colorScheme,
                                    job: job,
                                    onConfirmed: _load,
                                  ),
                                )),
                          ],
                        ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryTile extends ConsumerWidget {
  const _HistoryTile({required this.colorScheme, required this.job, required this.onConfirmed});

  final ColorScheme colorScheme;
  final DispatchJobModel job;
  final VoidCallback onConfirmed;

  Future<void> _runAction(BuildContext context, WidgetRef ref, Future<void> Function() action) async {
    try {
      await action();
      onConfirmed();
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  void _showQrDialog(BuildContext context) {
    final data = job.deliveryQrImage;
    Uint8List? imageBytes;
    if (data != null && data.startsWith('data:image')) {
      try {
        imageBytes = base64Decode(data.split(',').last);
      } catch (_) {
        imageBytes = null;
      }
    }

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Show this to the buyer'),
        content: SizedBox(
          width: 220,
          height: 220,
          child: imageBytes != null
              ? Image.memory(imageBytes)
              : const Center(child: Icon(Icons.qr_code_2_rounded, size: 64)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCompleted = job.status == 'COMPLETED';
    final statusColor = isCompleted ? colorScheme.primary : colorScheme.tertiary;
    final statusLabel = switch (job.status) {
      'COMPLETED' => 'Completed',
      'DELIVERED' => 'Awaiting buyer scan',
      'IN_TRANSIT' => 'In transit',
      _ => 'Pickup pending',
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                isCompleted ? Icons.check_circle_rounded : Icons.local_shipping_rounded,
                color: statusColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${job.quantityKg.toStringAsFixed(0)}kg of ${job.cropType}',
                      style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    Text(
                      '${job.createdAt.toLocal()}'.split('.').first,
                      style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(999)),
                child: Text(
                  statusLabel,
                  style: TextStyle(color: statusColor, fontWeight: FontWeight.w700, fontSize: 11.5),
                ),
              ),
            ],
          ),
          if (!isCompleted) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: switch (job.status) {
                'IN_TRANSIT' => FilledButton.icon(
                  onPressed: () => _runAction(
                    context,
                    ref,
                    () => ref.read(dispatchRepositoryProvider).markDelivered(job.id),
                  ),
                  style: FilledButton.styleFrom(backgroundColor: colorScheme.primary, foregroundColor: colorScheme.onPrimary),
                  icon: const Icon(Icons.flag_rounded, size: 18),
                  label: const Text('Mark Delivered'),
                ),
                'DELIVERED' => OutlinedButton.icon(
                  onPressed: () => _showQrDialog(context),
                  style: OutlinedButton.styleFrom(foregroundColor: colorScheme.primary),
                  icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                  label: const Text('Show Delivery QR'),
                ),
                _ => FilledButton.icon(
                  onPressed: () => _runAction(
                    context,
                    ref,
                    () => ref.read(dispatchRepositoryProvider).markPickedUp(job.id),
                  ),
                  style: FilledButton.styleFrom(backgroundColor: colorScheme.primary, foregroundColor: colorScheme.onPrimary),
                  icon: const Icon(Icons.inventory_2_rounded, size: 18),
                  label: const Text('Mark Picked Up'),
                ),
              },
            ),
          ],
        ],
      ),
    );
  }
}
