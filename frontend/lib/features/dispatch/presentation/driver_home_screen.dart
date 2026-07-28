import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/ambient_background.dart';
import '../../../core/widgets/empty_state.dart';
import '../../auth/application/auth_controller.dart';
import '../data/dispatch_repository.dart';

class DriverHomeScreen extends ConsumerStatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  ConsumerState<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends ConsumerState<DriverHomeScreen> {
  bool _isAvailable = true;
  bool _loadingAvailability = true;
  bool _loadingJobs = true;
  List<DispatchJobModel> _jobs = const [];
  String? _actingJobId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(dispatchRepositoryProvider);
    final available = await repo.fetchIsAvailable();
    final jobs = await repo.fetchJobs(status: 'PENDING');
    if (!mounted) return;
    setState(() {
      _isAvailable = available;
      _jobs = jobs;
      _loadingAvailability = false;
      _loadingJobs = false;
    });
  }

  Future<void> _toggleAvailability(bool value) async {
    setState(() => _isAvailable = value);
    try {
      await ref.read(dispatchRepositoryProvider).setAvailability(value);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isAvailable = !value);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _respond(String jobId, bool accept) async {
    setState(() => _actingJobId = jobId);
    try {
      final repo = ref.read(dispatchRepositoryProvider);
      if (accept) {
        await repo.acceptJob(jobId);
      } else {
        await repo.declineJob(jobId);
      }
      final jobs = await repo.fetchJobs(status: 'PENDING');
      if (!mounted) return;
      setState(() {
        _jobs = jobs;
        _actingJobId = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _actingJobId = null);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final userName = ref.watch(authControllerProvider).user?.name;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          AmbientBackground(colorScheme: colorScheme),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  Text(
                    'Hi, ${userName ?? 'Driver'}',
                    style: TextStyle(color: colorScheme.onSurface, fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 16),
                  _AvailabilityCard(
                    colorScheme: colorScheme,
                    isAvailable: _isAvailable,
                    loading: _loadingAvailability,
                    onChanged: _toggleAvailability,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Job Offers',
                    style: TextStyle(color: colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  if (_loadingJobs)
                    const Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_jobs.isEmpty)
                    const EmptyState(
                      icon: Icons.local_shipping_outlined,
                      message: 'No delivery offers right now. Stay available and check back soon.',
                    )
                  else
                    ..._jobs.map((job) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _JobCard(
                            colorScheme: colorScheme,
                            job: job,
                            acting: _actingJobId == job.id,
                            onAccept: () => _respond(job.id, true),
                            onDecline: () => _respond(job.id, false),
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

class _AvailabilityCard extends StatelessWidget {
  const _AvailabilityCard({
    required this.colorScheme,
    required this.isAvailable,
    required this.loading,
    required this.onChanged,
  });

  final ColorScheme colorScheme;
  final bool isAvailable;
  final bool loading;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(
            isAvailable ? Icons.check_circle_rounded : Icons.pause_circle_outline_rounded,
            color: isAvailable ? colorScheme.primary : colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isAvailable ? 'You\'re available for jobs' : 'You\'re offline',
              style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ),
          loading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Switch(value: isAvailable, activeThumbColor: colorScheme.primary, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  const _JobCard({
    required this.colorScheme,
    required this.job,
    required this.acting,
    required this.onAccept,
    required this.onDecline,
  });

  final ColorScheme colorScheme;
  final DispatchJobModel job;
  final bool acting;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${job.quantityKg.toStringAsFixed(0)}kg of ${job.cropType}',
            style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w800, fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            'Offered ${_relativeTime(job.createdAt)}',
            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12.5),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: acting ? null : onDecline,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colorScheme.error,
                    side: BorderSide(color: colorScheme.error.withValues(alpha: 0.5)),
                    shape: const StadiumBorder(),
                  ),
                  child: const Text('Decline'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: acting ? null : onAccept,
                  style: FilledButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    shape: const StadiumBorder(),
                  ),
                  child: acting
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.onPrimary),
                        )
                      : const Text('Accept'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _relativeTime(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}
