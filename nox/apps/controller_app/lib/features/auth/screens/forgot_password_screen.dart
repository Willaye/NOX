import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nox_design_system/nox_design_system.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isSubmitting = false;
  bool _isSubmitted = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) return 'Email is required';
    final emailRegex = RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,63}$');
    if (!emailRegex.hasMatch(value)) return 'Enter a valid email address';
    return null;
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    // Simulate API call
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() {
        _isSubmitting = false;
        _isSubmitted = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [NoxColors.deepAbyss, NoxColors.voidBlack],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: NoxSpacing.xxl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: NoxSpacing.lg),

                NoxIconButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  onPressed: () => context.pop(),
                  size: 40,
                ),

                const SizedBox(height: NoxSpacing.xxxl),

                if (_isSubmitted) _buildSuccessState() else _buildFormState(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormState() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: NoxColors.lavenderPrimary.withValues(alpha: 0.1),
              border: Border.all(
                color: NoxColors.lavenderPrimary.withValues(alpha: 0.2),
              ),
              boxShadow: [
                BoxShadow(
                  color: NoxColors.lavenderPrimary.withValues(alpha: 0.15),
                  blurRadius: 24,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.lock_reset_rounded,
                size: 32,
                color: NoxColors.lavenderLight,
              ),
            ),
          ),

          const SizedBox(height: NoxSpacing.xxl),

          Text('Reset password', style: NoxTypography.heroTitle),
          const SizedBox(height: NoxSpacing.sm),
          Text(
            'Enter the email address associated with your account. We\'ll send you a link to reset your password.',
            style: NoxTypography.body.copyWith(
              color: NoxColors.mistGray,
              height: 1.6,
            ),
          ),

          const SizedBox(height: NoxSpacing.xxxl),

          NoxTextField(
            label: 'Email Address',
            hint: 'you@example.com',
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            leadingIcon: Icons.email_outlined,
            validator: _validateEmail,
            onSubmitted: (_) => _handleSubmit(),
          ),

          const SizedBox(height: NoxSpacing.xxxl),

          NoxButton(
            label: 'Send Reset Link',
            onPressed: _isSubmitting ? null : _handleSubmit,
            isLoading: _isSubmitting,
            isExpanded: true,
            icon: Icons.send_rounded,
          ),

          const SizedBox(height: NoxSpacing.xxl),

          Center(
            child: GestureDetector(
              onTap: () => context.pop(),
              child: Text(
                'Back to sign in',
                style: NoxTypography.body.copyWith(
                  color: NoxColors.lavenderLight,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: NoxSpacing.huge),

        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: NoxColors.onlineGreen.withValues(alpha: 0.1),
            border: Border.all(
              color: NoxColors.onlineGreen.withValues(alpha: 0.25),
            ),
            boxShadow: [
              BoxShadow(
                color: NoxColors.onlineGreen.withValues(alpha: 0.15),
                blurRadius: 32,
                spreadRadius: 8,
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.mark_email_read_rounded,
              size: 44,
              color: NoxColors.onlineGreen,
            ),
          ),
        ),

        const SizedBox(height: NoxSpacing.xxxl),

        Text(
          'Check your email',
          style: NoxTypography.heroTitle,
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: NoxSpacing.md),

        Text(
          'We\'ve sent a password reset link to',
          style: NoxTypography.body.copyWith(color: NoxColors.mistGray),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: NoxSpacing.xs),
        Text(
          _emailController.text,
          style: NoxTypography.subtitle.copyWith(
            color: NoxColors.lavenderLight,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: NoxSpacing.sm),

        Text(
          'The link will expire in 30 minutes.',
          style: NoxTypography.bodySmall.copyWith(color: NoxColors.dimGray),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: NoxSpacing.huge),

        NoxButton(
          label: 'Back to Sign In',
          onPressed: () => context.go('/login'),
          variant: NoxButtonVariant.primary,
          isExpanded: true,
        ),

        const SizedBox(height: NoxSpacing.lg),

        GestureDetector(
          onTap: () {
            setState(() => _isSubmitted = false);
          },
          child: Text(
            'Didn\'t receive it? Resend email',
            style: NoxTypography.bodySmall.copyWith(
              color: NoxColors.lavenderLight,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
