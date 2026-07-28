import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  List<DispatchJobModel> _jobs = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(dispatchRepositoryProvider);
    final results = await Future.wait([
      repo.fetchJobs(status: 'ACCEPTED'),
      repo.fetchJobs(status: 'COMPLETED'),
    ]);
    if (!mounted) return;
    final combined = [...results[0], ...results[1]]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    setState(() {
      _jobs = combined;
      _loading = false;
    });
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
                  : _jobs.isEmpty
                      ? const EmptyState(
                          icon: Icons.history_rounded,
                          message: 'No delivery history yet — accepted and completed jobs will appear here.',
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
                                  child: _HistoryTile(colorScheme: colorScheme, job: job),
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

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.colorScheme, required this.job});

  final ColorScheme colorScheme;
  final DispatchJobModel job;

  @override
  Widget build(BuildContext context) {
    final isCompleted = job.status == 'COMPLETED';
    final statusColor = isCompleted ? colorScheme.primary : colorScheme.tertiary;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.25)),
      ),
      child: Row(
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
              isCompleted ? 'Completed' : 'In progress',
              style: TextStyle(color: statusColor, fontWeight: FontWeight.w700, fontSize: 11.5),
            ),
          ),
        ],
      ),
    );
  }
}
