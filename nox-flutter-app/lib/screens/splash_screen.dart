import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/auth_service.dart';
import 'package:provider/provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
    _animController.forward();
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    final auth = context.read<AuthService>();
    await auth.checkAuth();

    // Wait at least 2 seconds for splash effect
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    if (auth.isAuthenticated) {
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NoxTheme.background,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // NOX Logo
              Text(
                'NOX',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontSize: 64,
                      letterSpacing: 16,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 8),
              // Accent line
              Container(
                width: 60,
                height: 3,
                decoration: BoxDecoration(
                  color: NoxTheme.accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 40),
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(NoxTheme.accent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
