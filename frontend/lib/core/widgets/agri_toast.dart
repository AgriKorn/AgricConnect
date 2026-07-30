import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

/// App-wide toast: replaces the default (bottom, opaque) [SnackBar] with a
/// top-right glassmorphic pill — a translucent blurred card with a green
/// outline, sliding/fading in over whatever's on screen via the root
/// [Overlay] (so it isn't clipped by the current Scaffold). Fire-and-forget,
/// same call shape as `ScaffoldMessenger.showSnackBar` (checklist
/// Non-Negotiable Rules: no raw/ad-hoc feedback widgets — this is the one
/// shared implementation every screen should use instead).
void showAgriToast(
  BuildContext context,
  String message, {
  IconData icon = Icons.check_circle_rounded,
  Duration duration = const Duration(seconds: 3),
}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  final colorScheme = Theme.of(context).colorScheme;
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => _AgriToast(
      message: message,
      icon: icon,
      duration: duration,
      colorScheme: colorScheme,
      onDismissed: () => entry.remove(),
    ),
  );
  overlay.insert(entry);
}

class _AgriToast extends StatefulWidget {
  const _AgriToast({
    required this.message,
    required this.icon,
    required this.duration,
    required this.colorScheme,
    required this.onDismissed,
  });

  final String message;
  final IconData icon;
  final Duration duration;
  final ColorScheme colorScheme;
  final VoidCallback onDismissed;

  @override
  State<_AgriToast> createState() => _AgriToastState();
}

class _AgriToastState extends State<_AgriToast> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;
  Timer? _timer;
  bool _dismissing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 220));
    _slide = Tween<Offset>(begin: const Offset(0.12, -0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
    _timer = Timer(widget.duration, _dismiss);
  }

  Future<void> _dismiss() async {
    if (_dismissing) return;
    _dismissing = true;
    _timer?.cancel();
    await _controller.reverse();
    widget.onDismissed();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = widget.colorScheme;
    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      right: 16,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: _dismiss,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: colorScheme.surface.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: colorScheme.primary, width: 1.5),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 18, offset: const Offset(0, 8)),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(widget.icon, color: colorScheme.primary, size: 20),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              widget.message,
                              style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w600, fontSize: 13.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
