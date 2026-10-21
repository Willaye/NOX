import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nox_design_system/nox_design_system.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _entryController;
  late Animation<double> _backgroundOpacity;
  late Animation<Offset> _logoSlide;
  late Animation<double> _contentOpacity;
  late Animation<Offset> _buttonsSlide;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _backgroundOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
      ),
    );

    _logoSlide = Tween<Offset>(
      begin: const Offset(0, -0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.1, 0.6, curve: Curves.easeOutCubic),
    ));

    _contentOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.3, 0.7, curve: Curves.easeIn),
      ),
    );

    _buttonsSlide = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.5, 1.0, curve: Curves.easeOutCubic),
    ));

    _entryController.forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: AnimatedBuilder(
        animation: _entryController,
        builder: (context, child) {
          return Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  NoxColors.deepAbyss.withValues(alpha: _backgroundOpacity.value),
                  NoxColors.voidBlack,
                  NoxColors.midnightNavy.withValues(alpha: _backgroundOpacity.value * 0.6),
                ],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: NoxSpacing.xxl),
                child: Column(
                  children: [
                    SizedBox(height: screenHeight * 0.12),

                    // Logo and branding
                    SlideTransition(
                      position: _logoSlide,
                      child: Opacity(
                        opacity: _contentOpacity.value.clamp(0, 1),
                        child: _buildLogo(),
                      ),
                    ),

                    const SizedBox(height: NoxSpacing.xxxl),

                    // Tagline
                    Opacity(
                      opacity: _contentOpacity.value,
                      child: _buildTagline(),
                    ),

                    const Spacer(),

                    // Features list
                    Opacity(
                      opacity: _contentOpacity.value,
                      child: _buildFeatures(),
                    ),

                    const SizedBox(height: NoxSpacing.huge),

                    // CTA Buttons
                    SlideTransition(
                      position: _buttonsSlide,
                      child: Opacity(
                        opacity: _contentOpacity.value,
                        child: _buildButtons(context),
                      ),
                    ),

                    const SizedBox(height: NoxSpacing.xxxl),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: NoxColors.primaryGradient,
            boxShadow: [
              BoxShadow(
                color: NoxColors.lavenderPrimary.withValues(alpha: 0.35),
                blurRadius: 40,
                spreadRadius: 8,
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.nightlight_round,
              size: 48,
              color: NoxColors.pureWhite,
            ),
          ),
        ),
        const SizedBox(height: NoxSpacing.xxl),
        Text(
          'NOX',
          style: NoxTypography.heroTitle.copyWith(
            fontSize: 38,
            letterSpacing: 10,
            foreground: Paint()
              ..shader = NoxColors.primaryGradient.createShader(
                const Rect.fromLTWH(0, 0, 180, 50),
              ),
          ),
        ),
      ],
    );
  }

  Widget _buildTagline() {
    return Column(
      children: [
        Text(
          'Your devices, everywhere',
          style: NoxTypography.h2.copyWith(
            color: NoxColors.softWhite,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: NoxSpacing.sm),
        Text(
          'Monitor, manage, and control your devices\nfrom anywhere in the world.',
          style: NoxTypography.body.copyWith(
            color: NoxColors.mistGray,
            height: 1.6,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildFeatures() {
    return const Column(
      children: [
        _FeatureRow(
          icon: Icons.devices_rounded,
          title: 'Multi-device tracking',
          subtitle: 'Monitor all your devices in real-time',
        ),
        SizedBox(height: NoxSpacing.lg),
        _FeatureRow(
          icon: Icons.location_on_rounded,
          title: 'Location history',
          subtitle: 'Track device movements over time',
        ),
        SizedBox(height: NoxSpacing.lg),
        _FeatureRow(
          icon: Icons.shield_rounded,
          title: 'Secure & encrypted',
          subtitle: 'End-to-end encrypted communication',
        ),
      ],
    );
  }

  Widget _buildButtons(BuildContext context) {
    return Column(
      children: [
        NoxButton(
          label: 'Create admin account',
          onPressed: () => context.push('/signup'),
          isExpanded: true,
          icon: Icons.arrow_forward_rounded,
        ),
        const SizedBox(height: NoxSpacing.md),
        NoxButton(
          label: 'I already have an account',
          onPressed: () => context.push('/login'),
          variant: NoxButtonVariant.ghost,
          isExpanded: true,
        ),
      ],
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: NoxColors.lavenderPrimary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(NoxSpacing.radiusMd),
            border: Border.all(
              color: NoxColors.lavenderPrimary.withValues(alpha: 0.2),
              width: 0.5,
            ),
          ),
          child: Center(
            child: Icon(icon, size: 22, color: NoxColors.lavenderLight),
          ),
        ),
        const SizedBox(width: NoxSpacing.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: NoxTypography.subtitle.copyWith(
                color: NoxColors.softWhite,
              )),
              const SizedBox(height: 2),
              Text(subtitle, style: NoxTypography.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}
