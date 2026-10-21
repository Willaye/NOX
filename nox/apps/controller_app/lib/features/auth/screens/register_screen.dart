import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nox_design_system/nox_design_system.dart';
import '../../../core/providers/auth_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _firstNameFocus = FocusNode();
  final _lastNameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmFocus = FocusNode();
  bool _agreedToTerms = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _firstNameFocus.dispose();
    _lastNameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  String? _validateFirstName(String? value) {
    if (value == null || value.trim().isEmpty) return 'First name is required';
    if (value.trim().length < 2) return 'First name must be at least 2 characters';
    return null;
  }

  String? _validateLastName(String? value) {
    if (value == null || value.trim().isEmpty) return 'Last name is required';
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) return 'Email is required';
    final emailRegex = RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,63}$');
    if (!emailRegex.hasMatch(value)) return 'Enter a valid email address';
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 8) return 'Password must be at least 8 characters';
    if (!RegExp(r'[A-Z]').hasMatch(value)) return 'Include at least one uppercase letter';
    if (!RegExp(r'[0-9]').hasMatch(value)) return 'Include at least one number';
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) return 'Please confirm your password';
    if (value != _passwordController.text) return 'Passwords do not match';
    return null;
  }

  int get _passwordStrength {
    final password = _passwordController.text;
    if (password.isEmpty) return 0;
    int score = 0;
    if (password.length >= 8) score++;
    if (password.length >= 12) score++;
    if (RegExp(r'[A-Z]').hasMatch(password)) score++;
    if (RegExp(r'[0-9]').hasMatch(password)) score++;
    if (RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(password)) score++;
    return score;
  }

  Color get _strengthColor {
    switch (_passwordStrength) {
      case 0:
      case 1:
        return NoxColors.offlineRed;
      case 2:
      case 3:
        return NoxColors.warningAmber;
      case 4:
      case 5:
        return NoxColors.onlineGreen;
      default:
        return NoxColors.dimGray;
    }
  }

  String get _strengthLabel {
    switch (_passwordStrength) {
      case 0:
        return '';
      case 1:
        return 'Weak';
      case 2:
        return 'Fair';
      case 3:
        return 'Good';
      case 4:
        return 'Strong';
      case 5:
        return 'Excellent';
      default:
        return '';
    }
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please agree to the Terms of Service',
            style: NoxTypography.body.copyWith(color: NoxColors.pureWhite),
          ),
          backgroundColor: NoxColors.warningAmber.withValues(alpha: 0.9),
        ),
      );
      return;
    }

    ref.read(authStateProvider.notifier).clearError();
    final success = await ref.read(authStateProvider.notifier).register(
      _firstNameController.text.trim(),
      _lastNameController.text.trim(),
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

                  const SizedBox(height: NoxSpacing.xxl),

                  // Header
                  Text('Create account', style: NoxTypography.heroTitle),
                  const SizedBox(height: NoxSpacing.sm),
                  Text(
                    'Set up your NOX account to start monitoring your devices remotely.',
                    style: NoxTypography.body.copyWith(color: NoxColors.mistGray),
                  ),

                  const SizedBox(height: NoxSpacing.xxxl),

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
                          const Icon(Icons.error_outline_rounded,
                              color: NoxColors.offlineRed, size: 20),
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
                            child: const Icon(Icons.close_rounded,
                                color: NoxColors.offlineRed, size: 18),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: NoxSpacing.xxl),
                  ],

                  // First name
                  NoxTextField(
                    label: 'First Name',
                    hint: 'John',
                    controller: _firstNameController,
                    focusNode: _firstNameFocus,
                    textInputAction: TextInputAction.next,
                    leadingIcon: Icons.person_outline_rounded,
                    validator: _validateFirstName,
                    onSubmitted: (_) => _lastNameFocus.requestFocus(),
                  ),

                  const SizedBox(height: NoxSpacing.xl),

                  // Last name
                  NoxTextField(
                    label: 'Last Name',
                    hint: 'Doe',
                    controller: _lastNameController,
                    focusNode: _lastNameFocus,
                    textInputAction: TextInputAction.next,
                    leadingIcon: Icons.person_outline_rounded,
                    validator: _validateLastName,
                    onSubmitted: (_) => _emailFocus.requestFocus(),
                  ),

                  const SizedBox(height: NoxSpacing.xl),

                  // Email
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

                  // Password
                  NoxTextField(
                    label: 'Password',
                    hint: 'Create a strong password',
                    controller: _passwordController,
                    focusNode: _passwordFocus,
                    obscureText: true,
                    showPasswordToggle: true,
                    textInputAction: TextInputAction.next,
                    leadingIcon: Icons.lock_outline_rounded,
                    validator: _validatePassword,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _confirmFocus.requestFocus(),
                  ),

                  // Password strength indicator
                  if (_passwordController.text.isNotEmpty) ...[
                    const SizedBox(height: NoxSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: _passwordStrength / 5,
                              backgroundColor: NoxColors.elevatedSurface,
                              valueColor: AlwaysStoppedAnimation(_strengthColor),
                              minHeight: 3,
                            ),
                          ),
                        ),
                        const SizedBox(width: NoxSpacing.sm),
                        Text(
                          _strengthLabel,
                          style: NoxTypography.caption.copyWith(
                            color: _strengthColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: NoxSpacing.xl),

                  // Confirm Password
                  NoxTextField(
                    label: 'Confirm Password',
                    hint: 'Re-enter your password',
                    controller: _confirmPasswordController,
                    focusNode: _confirmFocus,
                    obscureText: true,
                    showPasswordToggle: true,
                    textInputAction: TextInputAction.done,
                    leadingIcon: Icons.lock_outline_rounded,
                    validator: _validateConfirmPassword,
                    onSubmitted: (_) => _handleRegister(),
                  ),

                  const SizedBox(height: NoxSpacing.xxl),

                  // Terms checkbox
                  GestureDetector(
                    onTap: () => setState(() => _agreedToTerms = !_agreedToTerms),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            color: _agreedToTerms
                                ? NoxColors.lavenderPrimary
                                : Colors.transparent,
                            border: Border.all(
                              color: _agreedToTerms
                                  ? NoxColors.lavenderPrimary
                                  : NoxColors.mistGray,
                              width: 1.5,
                            ),
                          ),
                          child: _agreedToTerms
                              ? const Icon(Icons.check_rounded,
                                  size: 16, color: NoxColors.pureWhite)
                              : null,
                        ),
                        const SizedBox(width: NoxSpacing.md),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: NoxTypography.bodySmall.copyWith(
                                color: NoxColors.mistGray,
                              ),
                              children: const [
                                TextSpan(text: 'I agree to the '),
                                TextSpan(
                                  text: 'Terms of Service',
                                  style: TextStyle(color: NoxColors.lavenderLight),
                                ),
                                TextSpan(text: ' and '),
                                TextSpan(
                                  text: 'Privacy Policy',
                                  style: TextStyle(color: NoxColors.lavenderLight),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: NoxSpacing.xxxl),

                  // Register button
                  NoxButton(
                    label: 'Create Account',
                    onPressed: authState.isLoading ? null : _handleRegister,
                    isLoading: authState.isLoading,
                    isExpanded: true,
                    icon: Icons.person_add_rounded,
                  ),

                  const SizedBox(height: NoxSpacing.xxl),

                  // Login link
                  Center(
                    child: GestureDetector(
                      onTap: () => context.push('/login'),
                      child: RichText(
                        text: TextSpan(
                          style: NoxTypography.body.copyWith(color: NoxColors.mistGray),
                          children: [
                            const TextSpan(text: 'Already have an account? '),
                            TextSpan(
                              text: 'Sign in',
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
