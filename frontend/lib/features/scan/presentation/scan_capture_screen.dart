import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/coming_soon_screen.dart';
import '../application/scan_controller.dart';

const _cameraFeedFallbackAsset = 'assets/images/roma tomatoes.png';

void _openComingSoon(BuildContext context, String title, IconData icon) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => ComingSoonScreen(
        title: title,
        icon: icon,
        message: '$title will be available in a future update.',
      ),
    ),
  );
}

/// Full-bleed live camera surface with a centered viewfinder. Tapping the
/// shutter takes a real photo (falls back to a bundled still image on
/// platforms/devices with no camera — desktop, simulators, or web without
/// permission) and simultaneously simulates detection + analysis: a
/// skeleton scan line sweeps the frame while [ScanController.captureAndAnalyze]
/// runs (still mocked — no AI backend exists yet), then the app moves to
/// the results screen.
class ScanCaptureScreen extends ConsumerStatefulWidget {
  const ScanCaptureScreen({super.key});

  @override
  ConsumerState<ScanCaptureScreen> createState() => _ScanCaptureScreenState();
}

class _ScanCaptureScreenState extends ConsumerState<ScanCaptureScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _scanLineController;
  CameraController? _cameraController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      // Bounded: on platforms/environments with no camera plugin
      // implementation registered (e.g. desktop, plain widget tests), the
      // method channel call never resolves rather than throwing — without
      // a timeout this would hang the screen indefinitely instead of
      // falling back to the mock feed.
      final cameras = await availableCameras().timeout(const Duration(seconds: 4));
      if (cameras.isEmpty) {
        throw CameraException('noCamera', 'No camera found on this device.');
      }
      final description = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        description,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize().timeout(const Duration(seconds: 6));
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _cameraController = controller);
    } catch (e) {
      if (kDebugMode) debugPrint('Camera unavailable, falling back to mock feed: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      controller.dispose();
      _cameraController = null;
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scanLineController.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _toggleFlash() async {
    final controller = _cameraController;
    final turningOn = !ref.read(scanControllerProvider).isFlashOn;
    ref.read(scanControllerProvider.notifier).toggleFlash();
    if (controller != null && controller.value.isInitialized) {
      try {
        await controller.setFlashMode(turningOn ? FlashMode.torch : FlashMode.off);
      } catch (_) {
        // Torch unsupported on this camera — the UI toggle still tracks
        // intent even if the hardware can't honor it.
      }
    }
  }

  Future<void> _capture() async {
    final controller = _cameraController;
    _scanLineController.repeat(reverse: true);

    if (controller != null && controller.value.isInitialized && !controller.value.isTakingPicture) {
      try {
        await controller.takePicture();
      } catch (e) {
        if (kDebugMode) debugPrint('takePicture failed: $e');
      }
    }

    await ref.read(scanControllerProvider.notifier).captureAndAnalyze();
    _scanLineController.stop();

    if (!mounted) {
      return;
    }
    context.go('/farmer/scan/result');
  }

  @override
  Widget build(BuildContext context) {
    final scanState = ref.watch(scanControllerProvider);
    final isScanning = scanState.isScanning;
    final detectedLabel = ref.read(scanControllerProvider.notifier).previewCropType.toUpperCase();
    final controller = _cameraController;
    final cameraReady = controller != null && controller.value.isInitialized;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (cameraReady)
            _CameraPreviewCover(controller: controller)
          else
            Image.asset(_cameraFeedFallbackAsset, fit: BoxFit.cover),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.55),
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.6),
                ],
                stops: const [0, 0.25, 0.65, 1],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _GlassIconButton(
                        icon: Icons.close_rounded,
                        onPressed: () => context.canPop() ? context.pop() : context.go('/farmer/home'),
                      ),
                      if (isScanning) _DetectedPill(label: detectedLabel),
                      _GlassIconButton(
                        icon: scanState.isFlashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                        active: scanState.isFlashOn,
                        onPressed: _toggleFlash,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Center(
                    child: FractionallySizedBox(
                      widthFactor: 0.72,
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: _ViewfinderFrame(
                          isScanning: isScanning,
                          scanLineController: _scanLineController,
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: _HoldSteadyCard(isScanning: isScanning),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 0, 28, 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _GlassIconButton(
                        icon: Icons.photo_library_outlined,
                        onPressed: () => _openComingSoon(context, 'Import from Gallery', Icons.photo_library_outlined),
                      ),
                      _ShutterButton(loading: isScanning, onPressed: isScanning ? null : _capture),
                      _GlassIconButton(
                        icon: Icons.settings_outlined,
                        onPressed: () => _openComingSoon(context, 'Scan Settings', Icons.settings_outlined),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// [CameraPreview] renders at the sensor's native aspect ratio rather than
/// filling its box — this scales+crops it the way [BoxFit.cover] would for
/// a full-bleed background.
class _CameraPreviewCover extends StatelessWidget {
  const _CameraPreviewCover({required this.controller});

  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        var scale = size.aspectRatio * controller.value.aspectRatio;
        if (scale < 1) scale = 1 / scale;
        return ClipRect(
          child: Transform.scale(
            scale: scale,
            child: Center(child: CameraPreview(controller)),
          ),
        );
      },
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({required this.icon, required this.onPressed, this.active = false});

  final IconData icon;
  final VoidCallback? onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: active ? primary : Colors.black.withValues(alpha: 0.35),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, color: Colors.white, size: 20),
        onPressed: onPressed,
      ),
    );
  }
}

class _DetectedPill extends StatelessWidget {
  const _DetectedPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Flexible(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: primary, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                '$label DETECTED',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ViewfinderFrame extends StatelessWidget {
  const _ViewfinderFrame({required this.isScanning, required this.scanLineController});

  final bool isScanning;
  final AnimationController scanLineController;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: primary, width: 2.5),
        borderRadius: BorderRadius.circular(28),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (isScanning)
              LayoutBuilder(
                builder: (context, constraints) {
                  return AnimatedBuilder(
                    animation: scanLineController,
                    builder: (context, _) {
                      final travel = constraints.maxHeight - 40;
                      final top = 20 + travel * scanLineController.value;
                      return Positioned(
                        top: top,
                        left: 18,
                        right: 18,
                        child: Container(
                          height: 2.5,
                          decoration: BoxDecoration(
                            color: primary,
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: [BoxShadow(color: primary.withValues(alpha: 0.8), blurRadius: 8)],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            if (isScanning)
              Align(
                alignment: const Alignment(0, 0.82),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(999)),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 16),
                      SizedBox(width: 8),
                      Text(
                        'AI ANALYZING...',
                        style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w800, letterSpacing: 0.4),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HoldSteadyCard extends StatelessWidget {
  const _HoldSteadyCard({required this.isScanning});

  final bool isScanning;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: const Icon(Icons.info_outline_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isScanning ? 'Analyzing...' : 'Hold steady',
                  style: const TextStyle(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  isScanning
                      ? "Don't move the camera until the scan finishes."
                      : 'Scan the crop under direct light for best accuracy.',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShutterButton extends StatelessWidget {
  const _ShutterButton({required this.loading, required this.onPressed});

  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 76,
        height: 76,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 3),
        ),
        child: Container(
          decoration: BoxDecoration(color: primary, shape: BoxShape.circle),
          child: loading
              ? const Padding(
                  padding: EdgeInsets.all(22),
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                )
              : const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 30),
        ),
      ),
    );
  }
}
