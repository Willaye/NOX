import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nox_design_system/nox_design_system.dart';
import '../../../core/providers/auth_provider.dart';

/// 3-step email signup wizard:
///   1) email → request OTP
///   2) 6-digit OTP → verify (saves JWT so step 3 can authenticate)
///   3) set password → account ready
///
/// On completion the auth state is already flipped to authenticated, so the
/// router pushes the user to /home automatically.
class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  int _step = 0;

  final _emailCtl = TextEditingController();
  final _otpCtl = TextEditingController();
  final _passwordCtl = TextEditingController();
  final _confirmCtl = TextEditingController();

  final _emailKey = GlobalKey<FormState>();
  final _otpKey = GlobalKey<FormState>();
  final _passwordKey = GlobalKey<FormState>();

  bool _showPassword = false;
  String? _localError;

  // Resend cooldown: seconds remaining before the user may request another
  // code. Prevents mailbox flooding and matches the backend 5/min rate limit.
  static const int _resendCooldownSeconds = 45;
  int _resendRemaining = 0;
  Timer? _cooldownTimer;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _emailCtl.dispose();
    _otpCtl.dispose();
    _passwordCtl.dispose();
    _confirmCtl.dispose();
    super.dispose();
  }

  void _startResendCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _resendRemaining = _resendCooldownSeconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendRemaining <= 1) {
        timer.cancel();
        setState(() => _resendRemaining = 0);
      } else {
        setState(() => _resendRemaining -= 1);
      }
    });
  }

  Future<void> _submitEmail() async {
    if (!_emailKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final err = await ref
        .read(authStateProvider.notifier)
        .requestOtp(_emailCtl.text.trim());
    if (!mounted) return;
    if (err != null) {
      setState(() => _localError = err);
      return;
    }
    setState(() {
      _localError = null;
      _step = 1;
    });
    _startResendCooldown();
  }

  // Resend from step 1. Guarded by the cooldown so repeated taps can't flood
  // the mailbox or trip the backend rate limit.
  Future<void> _resendCode() async {
    if (_resendRemaining > 0) return;
    final err = await ref
        .read(authStateProvider.notifier)
        .requestOtp(_emailCtl.text.trim());
    if (!mounted) return;
    if (err != null) {
      setState(() => _localError = err);
      return;
    }
    setState(() => _localError = null);
    _startResendCooldown();
  }

  Future<void> _submitOtp() async {
    if (!_otpKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final err = await ref
        .read(authStateProvider.notifier)
        .verifyOtp(_otpCtl.text.trim());
    if (!mounted) return;
    if (err != null) {
      setState(() => _localError = err);
      return;
    }
    setState(() {
      _localError = null;
      _step = 2;
    });
  }

  Future<void> _submitPassword() async {
    if (!_passwordKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final err = await ref
        .read(authStateProvider.notifier)
        .setPassword(_passwordCtl.text);
    if (!mounted) return;
    if (err != null) {
      setState(() => _localError = err);
      return;
    }
    // Router listens to authStateProvider; it will land on /home as soon as
    // auth is complete. Push explicitly in case the redirect was debounced.
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider);
    final isLoading = auth.isLoading;

    return Scaffold(
      backgroundColor: NoxColors.voidBlack,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () {
            if (_step == 0) {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/welcome');
              }
            } else {
              setState(() {
                _localError = null;
                _step -= 1;
              });
            }
          },
          icon: const Icon(Icons.arrow_back_rounded,
              color: NoxColors.softWhite),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: NoxSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StepperDots(active: _step, total: 3),
              const SizedBox(height: NoxSpacing.xxxl),
              _buildHeader(),
              const SizedBox(height: NoxSpacing.xxl),
              _buildBody(isLoading),
              if (_localError != null) ...[
                const SizedBox(height: NoxSpacing.lg),
                _ErrorBanner(message: _localError!),
              ],
              const SizedBox(height: NoxSpacing.xxxl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    switch (_step) {
      case 0:
        return _HeaderBlock(
          icon: Icons.mail_rounded,
          title: 'Create your admin account',
          subtitle:
              'Enter your email. We will send a 6-digit verification code.',
        );
      case 1:
        return _HeaderBlock(
          icon: Icons.pin_rounded,
          title: 'Enter verification code',
          subtitle:
              'A 6-digit code was sent to ${_emailCtl.text.trim()}. '
              'The code expires in 15 minutes.',
        );
      case 2:
      default:
        return const _HeaderBlock(
          icon: Icons.lock_rounded,
          title: 'Create a password',
          subtitle:
              'This password will be used for future logins. '
              'Use at least 8 characters.',
        );
    }
  }

  Widget _buildBody(bool isLoading) {
    switch (_step) {
      case 0:
        return Form(
          key: _emailKey,
          child: Column(
            children: [
              NoxTextField(
                controller: _emailCtl,
                label: 'Email',
                hint: 'you@example.com',
                keyboardType: TextInputType.emailAddress,
                leadingIcon: Icons.mail_rounded,
                validator: (v) {
                  final value = (v ?? '').trim();
                  if (value.isEmpty) return 'Enter your email';
                  final re = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                  if (!re.hasMatch(value)) return 'Enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: NoxSpacing.xxl),
              NoxButton(
                label: 'Send code',
                onPressed: isLoading ? null : _submitEmail,
                isLoading: isLoading,
                isExpanded: true,
                icon: Icons.arrow_forward_rounded,
              ),
            ],
          ),
        );
      case 1:
        return Form(
          key: _otpKey,
          child: Column(
            children: [
              NoxTextField(
                controller: _otpCtl,
                label: 'Verification code',
                hint: '123456',
                keyboardType: TextInputType.number,
                leadingIcon: Icons.pin_rounded,
                maxLength: 8,
                validator: (v) {
                  final value = (v ?? '').trim();
                  if (value.isEmpty) return 'Enter the code';
                  if (value.length < 6) return 'Enter the 6-digit code';
                  return null;
                },
              ),
              const SizedBox(height: NoxSpacing.md),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: (isLoading || _resendRemaining > 0)
                      ? null
                      : _resendCode,
                  child: Text(
                    _resendRemaining > 0
                        ? 'Resend code in ${_resendRemaining}s'
                        : 'Resend code',
                    style: NoxTypography.bodySmall.copyWith(
                      color: _resendRemaining > 0
                          ? NoxColors.mistGray
                          : NoxColors.lavenderLight,
                      decoration: _resendRemaining > 0
                          ? TextDecoration.none
                          : TextDecoration.underline,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: NoxSpacing.lg),
              NoxButton(
                label: 'Verify',
                onPressed: isLoading ? null : _submitOtp,
                isLoading: isLoading,
                isExpanded: true,
                icon: Icons.verified_rounded,
              ),
            ],
          ),
        );
      case 2:
      default:
        return Form(
          key: _passwordKey,
          child: Column(
            children: [
              NoxTextField(
                controller: _passwordCtl,
                label: 'Password',
                hint: 'At least 8 characters',
                obscureText: !_showPassword,
                showPasswordToggle: true,
                leadingIcon: Icons.lock_rounded,
                validator: (v) {
                  if ((v ?? '').length < 8) {
                    return 'Use at least 8 characters';
                  }
                  if (v!.length > 72) return 'Keep it under 72 characters';
                  return null;
                },
              ),
              const SizedBox(height: NoxSpacing.lg),
              NoxTextField(
                controller: _confirmCtl,
                label: 'Confirm password',
                obscureText: !_showPassword,
                showPasswordToggle: true,
                leadingIcon: Icons.lock_outline_rounded,
                validator: (v) {
                  if (v != _passwordCtl.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
              const SizedBox(height: NoxSpacing.xxl),
              NoxButton(
                label: 'Create account',
                onPressed: isLoading ? null : _submitPassword,
                isLoading: isLoading,
                isExpanded: true,
                icon: Icons.check_rounded,
              ),
            ],
          ),
        );
    }
  }
}

class _StepperDots extends StatelessWidget {
  final int active;
  final int total;
  const _StepperDots({required this.active, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final isActive = i == active;
        final isDone = i < active;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 28 : 10,
          height: 10,
          decoration: BoxDecoration(
            color: isActive
                ? NoxColors.lavenderPrimary
                : (isDone
                    ? NoxColors.lavenderPrimary.withValues(alpha: 0.5)
                    : NoxColors.elevatedSurface),
            borderRadius: BorderRadius.circular(5),
          ),
        );
      }),
    );
  }
}

class _HeaderBlock extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _HeaderBlock({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: NoxColors.primaryGradient,
            boxShadow: [
              BoxShadow(
                color: NoxColors.lavenderPrimary.withValues(alpha: 0.3),
                blurRadius: 28,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Icon(icon, size: 34, color: NoxColors.pureWhite),
        ),
        const SizedBox(height: NoxSpacing.xl),
        Text(
          title,
          style: NoxTypography.h2.copyWith(color: NoxColors.softWhite),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: NoxSpacing.sm),
        Text(
          subtitle,
          style: NoxTypography.body.copyWith(
            color: NoxColors.mistGray,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: NoxSpacing.lg,
        vertical: NoxSpacing.md,
      ),
      decoration: BoxDecoration(
        color: const Color(0x33FF4D6D),
        border: Border.all(color: const Color(0x66FF4D6D)),
        borderRadius: BorderRadius.circular(NoxSpacing.radiusMd),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: Color(0xFFFF8FA3), size: 20),
          const SizedBox(width: NoxSpacing.sm),
          Expanded(
            child: Text(
              message,
              style:
                  NoxTypography.bodySmall.copyWith(color: NoxColors.softWhite),
            ),
          ),
        ],
      ),
    );
  }
}
