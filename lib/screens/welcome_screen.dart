import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/agri_logo.dart';
import 'login_screen.dart';
import 'role_selection_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.heroFade,
      body: Column(
        children: [
          Expanded(flex: 11, child: _HeroPhoto()),
          Expanded(
            flex: 10,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 22, 28, 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Column(
                      children: [
                        const AgriLogo(width: 148),
                        const SizedBox(height: 14),
                        const Text(
                          'Fresh produce, fair prices.',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 14.5),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const LoginScreen()),
                          ),
                          child: const Text('Log In'),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
                          ),
                          child: const Text('Create Account'),
                        ),
                        const SizedBox(height: 16),
                        RichText(
                          textAlign: TextAlign.center,
                          text: const TextSpan(
                            style: TextStyle(fontSize: 11.5, color: AppColors.textMuted, height: 1.4),
                            children: [
                              TextSpan(text: 'By continuing you agree to our '),
                              TextSpan(text: 'Terms', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                              TextSpan(text: ' and '),
                              TextSpan(text: 'Privacy Policy', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ],
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

/// Farmer photo with a light-green vignette that fades inward, revealing
/// the photo clearly at the center and blending into the panel below.
class _HeroPhoto extends StatelessWidget {
  const _HeroPhoto();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(36),
        bottomRight: Radius.circular(36),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/farmer_hero.png',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => const _HeroPlaceholder(),
          ),
          // Vignette: green at the edges, fading to clear over the photo.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 0.95,
                colors: [Colors.transparent, AppColors.heroFade],
                stops: [0.35, 1.0],
              ),
            ),
          ),
          // Seam blend into the panel below.
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, AppColors.heroFade.withValues(alpha: 0.95)],
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 20,
            child: const AgriMark(size: 34),
          ),
        ],
      ),
    );
  }
}

class _HeroPlaceholder extends StatelessWidget {
  const _HeroPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.leaf, AppColors.primary],
        ),
      ),
      child: const Center(
        child: Icon(Icons.agriculture_rounded, size: 64, color: Colors.white38),
      ),
    );
  }
}
