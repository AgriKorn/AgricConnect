import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/motion.dart';
import '../application/onboarding_controller.dart';

const _scanImage = 'assets/images/cropscan_results.jpg';
const _marketImage = 'assets/images/market.png';
const _trackingImage = 'assets/images/navigation.jpg';
const _markAsset = 'assets/images/agri_mark.png';

// Reserved vertical space for the persistent header/footer chrome overlaid
// on every page — the backdrop's glass card is padded by these so it never
// sits underneath the Skip/brand lockup or the dots/CTA.
const _headerReserve = 108.0;
const _footerReserve = 148.0;

class _OnboardingPageData {
  const _OnboardingPageData({
    required this.imageAsset,
    required this.badgeLabel,
    required this.badgeIcon,
    required this.title,
    required this.subtitle,
  });

  final String imageAsset;
  final String badgeLabel;
  final IconData badgeIcon;
  final String title;
  final String subtitle;
}

const _pages = [
  _OnboardingPageData(
    imageAsset: _scanImage,
    badgeLabel: 'AI SCAN',
    badgeIcon: Icons.auto_awesome_rounded,
    title: 'Precision Harvesting',
    subtitle:
        'Use AI to scan your produce for instant freshness scores and market-ready GHS price recommendations.',
  ),
  _OnboardingPageData(
    imageAsset: _marketImage,
    badgeLabel: 'MARKETPLACE',
    badgeIcon: Icons.storefront_rounded,
    title: 'Sell Direct, Earn More',
    subtitle: 'List your harvest and reach buyers nearby — no middlemen, better prices for every sale.',
  ),
  _OnboardingPageData(
    imageAsset: _trackingImage,
    badgeLabel: 'LIVE TRACKING',
    badgeIcon: Icons.local_shipping_rounded,
    title: 'Track Every Delivery',
    subtitle: 'Follow your order from farm to doorstep and know exactly when it lands.',
  ),
];

/// First-launch carousel (3 pages) shown to unauthenticated users before
/// /login, gated by [onboardingControllerProvider] so it appears only once.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _index = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  bool get _isLastPage => _index == _pages.length - 1;

  Future<void> _finish() async {
    await ref.read(onboardingControllerProvider.notifier).complete();
    if (mounted) context.go('/login');
  }

  void _next() {
    if (_isLastPage) {
      _finish();
      return;
    }
    _pageController.nextPage(duration: kAgriConnectDuration, curve: kAgriConnectCurve);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: _pages.length,
            onPageChanged: (index) => setState(() => _index = index),
            itemBuilder: (context, index) => _OnboardingBackdrop(data: _pages[index]),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.topRight,
                      child: Opacity(
                        opacity: _isLastPage ? 0 : 1,
                        child: IgnorePointer(
                          ignoring: _isLastPage,
                          child: TextButton(
                            onPressed: _finish,
                            style: TextButton.styleFrom(foregroundColor: Colors.white),
                            child: const Text('Skip'),
                          ),
                        ),
                      ),
                    ),
                    const _BrandLockup(),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < _pages.length; i++) _PageDot(active: i == _index),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _HeroCta(label: _isLastPage ? 'Get Started' : 'Next', onPressed: _next),
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

class _OnboardingBackdrop extends StatelessWidget {
  const _OnboardingBackdrop({required this.data});

  final _OnboardingPageData data;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(data.imageAsset, fit: BoxFit.cover),
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(color: Colors.black.withValues(alpha: 0.3)),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.25),
                Colors.black.withValues(alpha: 0.75),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, _headerReserve, 24, _footerReserve),
          child: Center(child: _GlassCard(data: data, accent: accent)),
        ),
      ],
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.data, required this.accent});

  final _OnboardingPageData data;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ThumbnailWithBadge(
                imageAsset: data.imageAsset,
                badgeLabel: data.badgeLabel,
                badgeIcon: data.badgeIcon,
                accent: accent,
              ),
              const SizedBox(height: 26),
              Text(
                data.title,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Text(
                data.subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 14, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThumbnailWithBadge extends StatelessWidget {
  const _ThumbnailWithBadge({
    required this.imageAsset,
    required this.badgeLabel,
    required this.badgeIcon,
    required this.accent,
  });

  final String imageAsset;
  final String badgeLabel;
  final IconData badgeIcon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomCenter,
      children: [
        Container(
          width: 132,
          height: 132,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: accent, width: 2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.asset(imageAsset, fit: BoxFit.cover),
          ),
        ),
        Positioned(
          bottom: -14,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: accent.withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(badgeIcon, size: 13, color: Colors.white),
                const SizedBox(width: 5),
                Text(
                  badgeLabel,
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.4),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BrandLockup extends StatelessWidget {
  const _BrandLockup();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 52,
          height: 52,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.35),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: Image.asset(_markAsset, fit: BoxFit.contain),
        ),
        const SizedBox(height: 8),
        const Text(
          'AgriConnect',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _HeroCta extends StatelessWidget {
  const _HeroCta({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 6,
          shadowColor: primary.withValues(alpha: 0.5),
          shape: const StadiumBorder(),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_rounded, size: 20),
          ],
        ),
      ),
    );
  }
}

class _PageDot extends StatelessWidget {
  const _PageDot({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return AnimatedContainer(
      duration: kAgriConnectDuration,
      curve: kAgriConnectCurve,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: active ? 22 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: active ? primary : Colors.white.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
