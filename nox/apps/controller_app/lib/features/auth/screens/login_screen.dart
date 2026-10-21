import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nox_design_system/nox_design_system.dart';
import '../../../core/providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) return 'Email is required';
    final emailRegex = RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,63}$');
    if (!emailRegex.hasMatch(value)) return 'Enter a valid email address';
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    ref.read(authStateProvider.notifier).clearError();
    final success = await ref.read(authStateProvider.notifier).login(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (success && mounted) {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

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
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: NoxSpacing.lg),

                  // Back button
                  NoxIconButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onPressed: () => context.go('/welcome'),
                    size: 40,
                  ),

                  const SizedBox(height: NoxSpacing.xxxl),

                  // Header
                  Text('Welcome back', style: NoxTypography.heroTitle),
                  const SizedBox(height: NoxSpacing.sm),
                  Text(
                    'Sign in to your NOX account to continue monitoring your devices.',
                    style: NoxTypography.body.copyWith(color: NoxColors.mistGray),
                  ),

                  const SizedBox(height: NoxSpacing.huge),

                  // Error banner
                  if (authState.error != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(NoxSpacing.lg),
                      decoration: BoxDecoration(
                        color: NoxColors.offlineRed.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(NoxSpacing.radiusMd),
                        border: Border.all(
                          color: NoxColors.offlineRed.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: NoxColors.offlineRed,
                            size: 20,
                          ),
                          const SizedBox(width: NoxSpacing.md),
                          Expanded(
                            child: Text(
                              authState.error!,
                              style: NoxTypography.bodySmall.copyWith(
                                color: NoxColors.offlineRed,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => ref.read(authStateProvider.notifier).clearError(),
                            child: const Icon(
                              Icons.close_rounded,
                              color: NoxColors.offlineRed,
                              size: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: NoxSpacing.xxl),
                  ],

                  // Email field
                  NoxTextField(
                    label: 'Email',
                    hint: 'you@example.com',
                    controller: _emailController,
                    focusNode: _emailFocus,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    leadingIcon: Icons.email_outlined,
                    validator: _validateEmail,
                    onSubmitted: (_) => _passwordFocus.requestFocus(),
                  ),

                  const SizedBox(height: NoxSpacing.xl),

                  // Password field
                  NoxTextField(
                    label: 'Password',
                    hint: 'Enter your password',
                    controller: _passwordController,
                    focusNode: _passwordFocus,
                    obscureText: true,
                    showPasswordToggle: true,
                    textInputAction: TextInputAction.done,
                    leadingIcon: Icons.lock_outline_rounded,
                    validator: _validatePassword,
                    onSubmitted: (_) => _handleLogin(),
                  ),

                  const SizedBox(height: NoxSpacing.md),

                  // Forgot password
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: () => context.push('/forgot-password'),
                      child: Text(
                        'Forgot password?',
                        style: NoxTypography.bodySmall.copyWith(
                          color: NoxColors.lavenderLight,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: NoxSpacing.xxxl),

                  // Login button
                  NoxButton(
                    label: 'Sign In',
                    onPressed: authState.isLoading ? null : _handleLogin,
                    isLoading: authState.isLoading,
                    isExpanded: true,
                    icon: Icons.login_rounded,
                  ),

                  const SizedBox(height: NoxSpacing.xxl),

                  // Divider
                  Row(
                    children: [
                      const Expanded(child: Divider(color: NoxColors.glassBorder)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: NoxSpacing.lg),
                        child: Text(
                          'or',
                          style: NoxTypography.bodySmall.copyWith(color: NoxColors.dimGray),
                        ),
                      ),
                      const Expanded(child: Divider(color: NoxColors.glassBorder)),
                    ],
                  ),

                  const SizedBox(height: NoxSpacing.xxl),

                  // Register link
                  Center(
                    child: GestureDetector(
                      onTap: () => context.push('/register'),
                      child: RichText(
                        text: TextSpan(
                          style: NoxTypography.body.copyWith(color: NoxColors.mistGray),
                          children: [
                            const TextSpan(text: "Don't have an account? "),
                            TextSpan(
                              text: 'Create one',
                              style: NoxTypography.body.copyWith(
                                color: NoxColors.lavenderLight,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: NoxSpacing.xxxl),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
