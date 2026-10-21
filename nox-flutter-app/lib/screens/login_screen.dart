import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _tokenController = TextEditingController();
  bool _linkSent = false;
  bool _isLoading = false;
  String? _error;
  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  @override
  void dispose() {
    _emailController.dispose();
    _tokenController.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _sendMagicLink() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Enter a valid company email');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final auth = context.read<AuthService>();
      await auth.requestMagicLink(email);
      setState(() {
        _linkSent = true;
        _resendCooldown = 60;
      });
      _startCooldown();
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      setState(() => _error =
          msg.isNotEmpty ? msg : 'Failed to send magic link. Try again.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCooldown <= 0) {
        timer.cancel();
        return;
      }
      setState(() => _resendCooldown--);
    });
  }

  Future<void> _verifyToken() async {
    final token = _tokenController.text.trim();
    if (token.isEmpty) {
      setState(() => _error = 'Paste the token from your email');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final auth = context.read<AuthService>();
      final success = await auth.verifyMagicLink(token);
      if (success && mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        setState(() => _error = 'Invalid or expired token');
      }
    } catch (e) {
      setState(() => _error = 'Verification failed. Try again.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NoxTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 60),
              // Logo
              Center(
                child: Column(
                  children: [
                    Text(
                      'NOX',
                      style: Theme.of(context)
                          .textTheme
                          .headlineLarge
                          ?.copyWith(fontSize: 48, letterSpacing: 12),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 40,
                      height: 3,
                      decoration: BoxDecoration(
                        color: NoxTheme.accent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),

              // Title
              Text(
                _linkSent ? 'Check Your Email' : 'Sign In',
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _linkSent
                    ? 'We sent a magic link to ${_emailController.text}'
                    : 'Enter your company email to receive a sign-in link',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              if (!_linkSent) ...[
                // Email input
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    hintText: 'your.name@company.com',
                    prefixIcon:
                        Icon(Icons.email_outlined, color: NoxTheme.textSecondary),
                  ),
                  style: const TextStyle(color: NoxTheme.textPrimary),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isLoading ? null : _sendMagicLink,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: NoxTheme.background,
                          ),
                        )
                      : const Text('Send Magic Link'),
                ),
              ] else ...[
                // Token input
                Text(
                  'Paste the token from your email:',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _tokenController,
                  decoration: const InputDecoration(
                    hintText: 'Paste token here...',
                    prefixIcon:
                        Icon(Icons.key, color: NoxTheme.textSecondary),
                  ),
                  style: const TextStyle(color: NoxTheme.textPrimary),
                  maxLines: 1,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isLoading ? null : _verifyToken,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: NoxTheme.background,
                          ),
                        )
                      : const Text('Verify & Sign In'),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _resendCooldown > 0 ? null : _sendMagicLink,
                  child: Text(
                    _resendCooldown > 0
                        ? 'Resend in ${_resendCooldown}s'
                        : 'Resend Magic Link',
                    style: TextStyle(
                      color: _resendCooldown > 0
                          ? NoxTheme.textSecondary
                          : NoxTheme.accent,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _linkSent = false;
                    _error = null;
                  }),
                  child: const Text(
                    'Use a different email',
                    style: TextStyle(color: NoxTheme.textSecondary),
                  ),
                ),
              ],

              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: const TextStyle(color: NoxTheme.danger),
                  textAlign: TextAlign.center,
                ),
              ],

              const SizedBox(height: 48),
              // Disclaimer
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: NoxTheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: NoxTheme.accent.withAlpha(50),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: NoxTheme.accent, size: 20),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'This device will be managed by NOX. '
                        'Usage data will be monitored.',
                        style: TextStyle(
                          color: NoxTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
