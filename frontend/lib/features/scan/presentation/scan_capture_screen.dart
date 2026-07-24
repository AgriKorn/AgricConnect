import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/agri_button.dart';
import '../../../core/widgets/agri_card.dart';
import '../../../core/widgets/agri_dialog.dart';
import '../../../core/widgets/status_chip.dart';
import '../application/scan_controller.dart';

/// Phase 3.1 and 3.2: mock camera capture surface with a rationale dialog,
/// flash toggle, visible inference state, and an offline-only result path.
class ScanCaptureScreen extends ConsumerWidget {
  const ScanCaptureScreen({super.key});

  Future<void> _capture(BuildContext context, WidgetRef ref) async {
    final confirmed = await showAgriDialog(
      context,
      title: 'Allow camera access?',
      message:
          'AgriConnect uses the camera to inspect produce. The analysis runs on-device and works offline, so no image leaves the phone.',
      confirmLabel: 'Continue',
      cancelLabel: 'Not now',
    );

    if (confirmed != true) {
      return;
    }

    await ref.read(scanControllerProvider.notifier).captureAndAnalyze();
    if (!context.mounted) {
      return;
    }

    context.go('/farmer/scan/result');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scanState = ref.watch(scanControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Freshness Scan')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Scan produce offline',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Capture a clean image and let the on-device model score freshness without network access.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 20),
            AgriCard(
              padding: const EdgeInsets.all(0),
              child: AspectRatio(
                aspectRatio: 3 / 4,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Theme.of(context).colorScheme.surface,
                            Theme.of(context).colorScheme.surfaceContainerHighest,
                          ],
                        ),
                      ),
                      child: const Center(
                        child: Icon(Icons.photo_camera_outlined, size: 72),
                      ),
                    ),
                    Positioned(
                      top: 16,
                      right: 16,
                      child: IconButton.filledTonal(
                        tooltip: scanState.isFlashOn ? 'Flash on' : 'Flash off',
                        onPressed: () => ref
                            .read(scanControllerProvider.notifier)
                            .toggleFlash(),
                        icon: Icon(
                          scanState.isFlashOn
                              ? Icons.flash_on_rounded
                              : Icons.flash_off_rounded,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 16,
                      child: Row(
                        children: [
                          const StatusChip(
                            label: 'Offline scan',
                            tone: AgriStatusTone.neutral,
                          ),
                          const Spacer(),
                          if (scanState.isScanning)
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (scanState.isScanning)
                      Container(
                        color: Theme.of(
                          context,
                        ).colorScheme.surface.withValues(alpha: 0.72),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'Analyzing image on device...',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            AgriButton(
              label: scanState.isScanning ? 'Scanning...' : 'Capture Produce',
              icon: Icons.camera_alt_outlined,
              loading: scanState.isScanning,
              onPressed: scanState.isScanning
                  ? null
                  : () => _capture(context, ref),
            ),
            if (scanState.errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                scanState.errorMessage!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => context.go('/farmer/home'),
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Back to home'),
            ),
          ],
        ),
      ),
    );
  }
}
