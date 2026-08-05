import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/widgets/agri_toast.dart';
import '../application/scan_controller.dart';

/// Full-bleed live camera surface with a centered viewfinder (a plain black
/// screen with a loading spinner on platforms/devices with no camera —
/// desktop, simulators, or web without permission — never a stand-in photo).
/// Tapping the shutter takes a real photo and runs it through the on-device
/// `agriconnect.tflite` model: a loading-ellipsis skeleton pulses in the
/// frame while [ScanController.captureAndAnalyze] runs inference, then the
/// app moves to the results screen. Platforms with no camera fall back to
/// cycling fixed sample results instead (see [ScanController]).
class ScanCaptureScreen extends ConsumerStatefulWidget {
  const ScanCaptureScreen({super.key});

  @override
  ConsumerState<ScanCaptureScreen> createState() => _ScanCaptureScreenState();
}

class _ScanCaptureScreenState extends ConsumerState<ScanCaptureScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _scanLineController;
  final _imagePicker = ImagePicker();
  CameraController? _cameraController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
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
      // The model downsamples every photo to 224x224 regardless — capturing
      // at "high" (1080p+ on most devices) just makes takePicture() and the
      // JPEG decode both slower for no accuracy benefit. "medium" (~720p)
      // is still far more detail than the model uses.
      final controller = CameraController(
        description,
        ResolutionPreset.medium,
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
    // Flips the shutter button/overlay into their loading state right away
    // — takePicture() below is a real camera-hardware delay (autofocus,
    // exposure, JPEG encode), and without this the screen looked frozen for
    // that whole stretch with no acknowledgment the tap even registered.
    ref.read(scanControllerProvider.notifier).beginCapture();
    _scanLineController.repeat();

    String? imagePath;
    if (controller != null && controller.value.isInitialized && !controller.value.isTakingPicture) {
      try {
        final file = await controller.takePicture();
        imagePath = file.path;
      } catch (e) {
        if (kDebugMode) debugPrint('takePicture failed: $e');
      }
    }

    await _analyzeAndNavigate(imagePath);
  }

  /// Lets a farmer scan an existing photo (produce already photographed
  /// earlier, or sent to them) instead of only ever pointing the live
  /// camera at it — the same [_analyzeAndNavigate] pipeline the shutter
  /// button uses, just sourced from the gallery.
  Future<void> _pickFromGallery() async {
    final picked = await _imagePicker.pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
    if (picked == null || !mounted) return;

    ref.read(scanControllerProvider.notifier).beginCapture();
    _scanLineController.repeat();
    await _analyzeAndNavigate(picked.path);
  }

  /// Shared tail end of both capture paths: runs inference on [imagePath]
  /// (or the mock cycle when null — no camera on this device/platform),
  /// then either moves to the result screen or, on failure, stays put and
  /// surfaces the error as a toast instead of an uncaught exception
  /// freezing the screen mid-analysis.
  Future<void> _analyzeAndNavigate(String? imagePath) async {
    try {
      await ref.read(scanControllerProvider.notifier).captureAndAnalyze(imagePath: imagePath);
      _scanLineController.stop();
      if (!mounted) return;
      context.go('/farmer/scan/result');
    } catch (_) {
      _scanLineController.stop();
      if (!mounted) return;
      final message = ref.read(scanControllerProvider).errorMessage ?? 'Scan failed. Please try again.';
      showAgriToast(context, message, icon: Icons.error_outline_rounded, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scanState = ref.watch(scanControllerProvider);
    final isScanning = scanState.isScanning;
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
            const Center(child: CircularProgressIndicator(color: Colors.white)),
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
                      if (isScanning && !cameraReady) const _DetectedPill(),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _GlassIconButton(
                            icon: Icons.photo_library_outlined,
                            onPressed: isScanning ? null : _pickFromGallery,
                          ),
                          const SizedBox(width: 10),
                          _GlassIconButton(
                            icon: scanState.isFlashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                            active: scanState.isFlashOn,
                            onPressed: _toggleFlash,
                          ),
                        ],
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
                  child: Center(
                    child: _ShutterButton(loading: isScanning, onPressed: isScanning ? null : _capture),
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

/// Shown while a scan with no live camera preview is analyzing (no camera
/// on this device/platform, about to resolve to a mock result). Deliberately
/// doesn't name a crop: the previous "TOMATO DETECTED"-style pill echoed the
/// *upcoming mock result's* label before analysis had even run, which read
/// as a live species identification it wasn't — see crop_scan_presenter.dart
/// for why the real model can't make that claim reliably either.
class _DetectedPill extends StatelessWidget {
  const _DetectedPill();

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
            const Flexible(
              child: Text(
                'ANALYZING',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
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
              Center(child: _LoadingEllipsis(animation: scanLineController, color: primary)),
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

/// Three dots pulsing in sequence (a classic "loading" ellipsis) — the
/// skeleton shown in the viewfinder while a scan is analyzing.
class _LoadingEllipsis extends StatelessWidget {
  const _LoadingEllipsis({required this.animation, required this.color});

  final Animation<double> animation;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = (animation.value + i / 3) % 1.0;
            final scale = 0.55 + 0.45 * (0.5 - 0.5 * math.cos(2 * math.pi * phase));
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
              ),
            );
          }),
        );
      },
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
