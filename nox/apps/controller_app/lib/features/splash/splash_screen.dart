import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _mainCtrl;
  late AnimationController _shimmerCtrl;
  late AnimationController _fadeOutCtrl;

  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _glowPulse;
  late Animation<double> _textFade;
  late Animation<double> _starsFade;

  @override
  void initState() {
    super.initState();

    _mainCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));
    _shimmerCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))
      ..repeat();
    _fadeOutCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));

    _logoScale = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _mainCtrl, curve: const Interval(0.0, 0.5, curve: Curves.elasticOut)));
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _mainCtrl, curve: const Interval(0.0, 0.25, curve: Curves.easeIn)));
    _glowPulse = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _mainCtrl, curve: const Interval(0.2, 0.7, curve: Curves.easeInOut)));
    _textFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _mainCtrl, curve: const Interval(0.4, 0.8, curve: Curves.easeIn)));
    _starsFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _mainCtrl, curve: const Interval(0.5, 1.0, curve: Curves.easeIn)));

    _mainCtrl.forward();
    _startAuthCheck();
  }

  Future<void> _startAuthCheck() async {
    await Future.delayed(const Duration(milliseconds: 800));
    await ref.read(authStateProvider.notifier).checkAuth();
    await Future.delayed(const Duration(milliseconds: 1600));
    if (!mounted) return;
    _fadeOutCtrl.forward().then((_) {
      if (!mounted) return;
      final authState = ref.read(authStateProvider);
      if (authState.isAuthenticated) {
        context.go('/home');
      } else {
        context.go('/welcome');
      }
    });
  }

  @override
  void dispose() {
    _mainCtrl.dispose();
    _shimmerCtrl.dispose();
    _fadeOutCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _fadeOutCtrl,
        builder: (context, child) => Opacity(opacity: 1.0 - _fadeOutCtrl.value, child: child),
        child: Container(
          width: double.infinity, height: double.infinity,
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.3),
              radius: 1.2,
              colors: [
                Color(0xFF1A0A2E), // deep purple center
                Color(0xFF0D0614), // near-black
                Color(0xFF050208), // void
              ],
            ),
          ),
          child: AnimatedBuilder(
            animation: _mainCtrl,
            builder: (context, _) => Stack(
              alignment: Alignment.center,
              children: [
                // Decorative sparkle particles
                ..._buildSparkles(),

                // Main glow behind logo
                Positioned(
                  child: Container(
                    width: 200 + 60 * _glowPulse.value,
                    height: 200 + 60 * _glowPulse.value,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [
                        const Color(0xFFB388FF).withValues(alpha: 0.15 * _glowPulse.value),
                        const Color(0xFFE8B4F8).withValues(alpha: 0.08 * _glowPulse.value),
                        Colors.transparent,
                      ]),
                    ),
                  ),
                ),

                // NOX Logo text with shimmer
                Column(mainAxisSize: MainAxisSize.min, children: [
                  Transform.scale(
                    scale: _logoScale.value,
                    child: Opacity(
                      opacity: _logoOpacity.value,
                      child: _buildShimmerLogo(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Opacity(
                    opacity: _textFade.value,
                    child: Text(
                      'Monitor  •  Protect  •  Stay Connected',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 11, letterSpacing: 3, fontWeight: FontWeight.w300,
                      ),
                    ),
                  ),
                  const SizedBox(height: 60),
                  Opacity(
                    opacity: _textFade.value,
                    child: const SizedBox(width: 24, height: 24,
                      child: CircularProgressIndicator(strokeWidth: 1.5,
                        color: Color(0xFF9C6ADE))),
                  ),
                ]),

                // Bottom reflection line
                Positioned(
                  bottom: MediaQuery.of(context).size.height * 0.32,
                  child: Opacity(
                    opacity: 0.3 * _glowPulse.value,
                    child: Container(
                      width: 240, height: 1,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(colors: [
                          Colors.transparent,
                          Color(0xFFB388FF),
                          Color(0xFFE8B4F8),
                          Color(0xFFB388FF),
                          Colors.transparent,
                        ]),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerLogo() {
    return AnimatedBuilder(
      animation: _shimmerCtrl,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            final dx = bounds.width * 2 * (_shimmerCtrl.value - 0.5);
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: const [
                Color(0xFFD4B8FF), // light lavender
                Color(0xFFF8E8FF), // near white shimmer peak
                Color(0xFFFFD6E8), // pink accent
                Color(0xFFD4B8FF), // back to lavender
              ],
              stops: const [0.0, 0.4, 0.6, 1.0],
              transform: GradientRotation(dx * 0.02),
            ).createShader(Rect.fromLTWH(dx, 0, bounds.width, bounds.height));
          },
          blendMode: BlendMode.srcIn,
          child: child,
        );
      },
      child: const Text(
        'NOX',
        style: TextStyle(
          fontSize: 72,
          fontWeight: FontWeight.w200,
          letterSpacing: 20,
          height: 1,
        ),
      ),
    );
  }

  List<Widget> _buildSparkles() {
    final rng = math.Random(42);
    final screen = MediaQuery.of(context).size;
    return List.generate(12, (i) {
      final x = rng.nextDouble() * screen.width;
      final y = rng.nextDouble() * screen.height * 0.7 + screen.height * 0.1;
      final size = 2.0 + rng.nextDouble() * 4;
      final delay = rng.nextDouble();
      final appear = _starsFade.value > delay ? (_starsFade.value - delay) / (1 - delay) : 0.0;
      return Positioned(
        left: x, top: y,
        child: Opacity(
          opacity: appear.clamp(0.0, 1.0) * (0.3 + rng.nextDouble() * 0.5),
          child: Icon(Icons.star, size: size, color: const Color(0xFFE8D5FF)),
        ),
      );
    });
  }
}
