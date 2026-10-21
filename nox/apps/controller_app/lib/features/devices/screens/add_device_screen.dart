import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nox_design_system/nox_design_system.dart';
import '../../../core/models/nox_models.dart';
import '../../../core/network/api_client.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/utils/formatters.dart';

enum _PairingStep { enterCode, confirm, success }

/// Pairing flow:
///   1. User enters the 6-character code shown by the NOX agent app.
///   2. POST /pairing/validate  → shows which device the code belongs to.
///   3. User optionally renames, then POST /pairing/complete.
class AddDeviceScreen extends ConsumerStatefulWidget {
  const AddDeviceScreen({super.key});

  @override
  ConsumerState<AddDeviceScreen> createState() => _AddDeviceScreenState();
}

class _AddDeviceScreenState extends ConsumerState<AddDeviceScreen>
    with SingleTickerProviderStateMixin {
  static const _codeLength = 6;
  static final _codeChars = RegExp(r'[^A-Z0-9]');

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();

  _PairingStep _step = _PairingStep.enterCode;
  bool _isBusy = false;
  String? _error;
  String _validatedCode = '';
  Device? _pendingDevice;
  DateTime? _expiresAt;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _codeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  /// Uppercases and strips separators / an optional "NOX-" prefix.
  String _normalizeCode(String input) {
    var code = input.toUpperCase().trim();
    if (code.startsWith('NOX-')) code = code.substring(4);
    return code.replaceAll(_codeChars, '');
  }

  Future<void> _validateCode() async {
    final code = _normalizeCode(_codeController.text);
    if (code.length != _codeLength) {
      setState(() => _error = 'Enter the 6-character code from the device');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isBusy = true;
      _error = null;
    });

    try {
      // backend-project: POST /devices/pair { pairingCode }
      // This validates AND pairs in one step.
      final response = await ref.read(apiClientProvider).pairDevice(code);
      final data = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : <String, dynamic>{};

      final device = Device.fromJson(data);

      if (!mounted) return;
      setState(() {
        _validatedCode = code;
        _pendingDevice = device;
        _nameController.text = device.name;
        _step = _PairingStep.confirm;
        _isBusy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isBusy = false;
        _error = errorMessage(e);
      });
    }
  }

  Future<void> _completePairing() async {
    setState(() {
      _isBusy = true;
      _error = null;
    });

    try {
      // Device is already paired from _validateCode step.
      // If user changed the name, update it.
      final name = _nameController.text.trim();
      if (_pendingDevice != null && name.isNotEmpty && name != _pendingDevice!.name) {
        await ref.read(apiClientProvider).updateDevice(_pendingDevice!.id, {'name': name});
      }
      ref.invalidate(devicesProvider);

      if (!mounted) return;
      setState(() {
        _isBusy = false;
        _step = _PairingStep.success;
      });

      await Future.delayed(const Duration(seconds: 2));
      if (mounted) context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isBusy = false;
        _error = errorMessage(e);
      });
    }
  }

  void _startOver() {
    setState(() {
      _step = _PairingStep.enterCode;
      _error = null;
      _validatedCode = '';
      _pendingDevice = null;
      _expiresAt = null;
      _nameController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: NoxAppBar(
        title: 'Add Device',
        showBackButton: true,
        onBackPressed: () => context.pop(),
      ),
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(NoxSpacing.xxl),
          child: switch (_step) {
            _PairingStep.enterCode => _buildEnterCodeStep(),
            _PairingStep.confirm => _buildConfirmStep(),
            _PairingStep.success => _buildSuccessState(),
          },
        ),
      ),
    );
  }

  Widget _buildPulsingCard({required Widget child}) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(NoxSpacing.radiusXl),
            boxShadow: [
              BoxShadow(
                color: NoxColors.lavenderPrimary.withValues(
                  alpha: 0.2 * _pulseAnimation.value,
                ),
                blurRadius: 40,
                spreadRadius: 10,
              ),
            ],
          ),
          child: child,
        );
      },
      child: NoxCard(
        variant: NoxCardVariant.elevated,
        padding: const EdgeInsets.all(NoxSpacing.xxl),
        child: child,
      ),
    );
  }

  Widget _buildEnterCodeStep() {
    return Column(
      children: [
        _buildPulsingCard(
          child: Column(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: NoxColors.lavenderPrimary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: NoxColors.lavenderPrimary.withValues(alpha: 0.2),
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.keyboard_rounded,
                    size: 32,
                    color: NoxColors.lavenderLight,
                  ),
                ),
              ),

              const SizedBox(height: NoxSpacing.xxl),

              Text(
                'Enter the code displayed on your device',
                style: NoxTypography.subtitle.copyWith(
                  color: NoxColors.softWhite,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: NoxSpacing.sm),

              Text(
                'Open the NOX Agent app on the device you want to add — it shows a 6-character pairing code.',
                style: NoxTypography.bodySmall,
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: NoxSpacing.xxl),

              NoxTextField(
                hint: 'e.g. A7K9QX',
                controller: _codeController,
                leadingIcon: Icons.vpn_key_rounded,
                keyboardType: TextInputType.visiblePassword, // no autocorrect
                textInputAction: TextInputAction.done,
                maxLength: 10, // allows an optional "NOX-" prefix
                enabled: !_isBusy,
                errorText: _error,
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                onSubmitted: (_) => _validateCode(),
              ),
            ],
          ),
        ),

        const SizedBox(height: NoxSpacing.xxxl),

        _buildInstructions(),

        const SizedBox(height: NoxSpacing.xxxl),

        NoxButton(
          label: 'Verify Code',
          onPressed: _isBusy ? null : _validateCode,
          isLoading: _isBusy,
          isExpanded: true,
          icon: Icons.link_rounded,
        ),
      ],
    );
  }

  Widget _buildConfirmStep() {
    final device = _pendingDevice;

    return Column(
      children: [
        _buildPulsingCard(
          child: Column(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: NoxColors.primaryGradient,
                  borderRadius: BorderRadius.circular(NoxSpacing.radiusLg),
                ),
                child: Center(
                  child: Icon(
                    device != null ? deviceIcon(device) : Icons.devices_other_rounded,
                    size: 34,
                    color: NoxColors.pureWhite,
                  ),
                ),
              ),
              const SizedBox(height: NoxSpacing.xl),
              Text(
                device?.name ?? 'Device found',
                style: NoxTypography.h2,
                textAlign: TextAlign.center,
              ),
              if (device != null && device.typeDescription.isNotEmpty) ...[
                const SizedBox(height: NoxSpacing.xs),
                Text(
                  device.typeDescription,
                  style: NoxTypography.bodySmall.copyWith(
                    color: NoxColors.moonlightSilver,
                  ),
                ),
              ],
              const SizedBox(height: NoxSpacing.lg),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: NoxSpacing.xl,
                  vertical: NoxSpacing.md,
                ),
                decoration: BoxDecoration(
                  color: NoxColors.darkSurface,
                  borderRadius: BorderRadius.circular(NoxSpacing.radiusMd),
                  border: Border.all(color: NoxColors.glassBorder),
                ),
                child: Text(
                  _validatedCode,
                  style: NoxTypography.h2.copyWith(
                    letterSpacing: 3,
                    color: NoxColors.lavenderLight,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (_expiresAt != null) ...[
                const SizedBox(height: NoxSpacing.sm),
                Text(
                  'Code expires at ${formatTime(_expiresAt)}',
                  style: NoxTypography.caption,
                ),
              ],
              const SizedBox(height: NoxSpacing.xxl),
              NoxTextField(
                label: 'Device name',
                hint: 'Give this device a name',
                controller: _nameController,
                leadingIcon: Icons.edit_rounded,
                maxLength: 100,
                enabled: !_isBusy,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _completePairing(),
              ),
              if (_error != null) ...[
                const SizedBox(height: NoxSpacing.md),
                Text(
                  _error!,
                  style: NoxTypography.bodySmall.copyWith(color: NoxColors.offlineRed),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: NoxSpacing.xxxl),

        NoxButton(
          label: 'Pair Device',
          onPressed: _isBusy ? null : _completePairing,
          isLoading: _isBusy,
          isExpanded: true,
          icon: Icons.check_rounded,
        ),
        const SizedBox(height: NoxSpacing.md),
        NoxButton(
          label: 'Use a different code',
          variant: NoxButtonVariant.ghost,
          onPressed: _isBusy ? null : _startOver,
          isExpanded: true,
        ),
      ],
    );
  }

  Widget _buildInstructions() {
    return NoxCard(
      variant: NoxCardVariant.glass,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('How to pair', style: NoxTypography.h3),
          const SizedBox(height: NoxSpacing.lg),
          const _InstructionStep(
            step: '1',
            text: 'Install the NOX Agent app on the target device',
          ),
          const SizedBox(height: NoxSpacing.md),
          const _InstructionStep(
            step: '2',
            text: 'Open the agent app and tap "Pair with Controller"',
          ),
          const SizedBox(height: NoxSpacing.md),
          const _InstructionStep(
            step: '3',
            text: 'Enter the 6-character code it displays here',
          ),
          const SizedBox(height: NoxSpacing.md),
          const _InstructionStep(
            step: '4',
            text: 'Confirm the device details and tap "Pair Device"',
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessState() {
    return Column(
      children: [
        const SizedBox(height: NoxSpacing.huge),
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: NoxColors.onlineGreen.withValues(alpha: 0.12),
            boxShadow: [
              BoxShadow(
                color: NoxColors.onlineGreen.withValues(alpha: 0.2),
                blurRadius: 40,
                spreadRadius: 10,
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.check_circle_rounded,
              size: 56,
              color: NoxColors.onlineGreen,
            ),
          ),
        ),
        const SizedBox(height: NoxSpacing.xxxl),
        Text(
          'Device Paired!',
          style: NoxTypography.heroTitle.copyWith(
            color: NoxColors.onlineGreen,
          ),
        ),
        const SizedBox(height: NoxSpacing.md),
        Text(
          'Your device has been successfully paired and is now being monitored.',
          style: NoxTypography.body.copyWith(color: NoxColors.mistGray),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: NoxSpacing.xxxl),
        const NoxLoadingSpinner(
          size: 24,
          color: NoxColors.onlineGreen,
          message: 'Redirecting...',
        ),
      ],
    );
  }
}

class _InstructionStep extends StatelessWidget {
  final String step;
  final String text;

  const _InstructionStep({required this.step, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            gradient: NoxColors.primaryGradient,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              step,
              style: NoxTypography.caption.copyWith(
                color: NoxColors.pureWhite,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ),
        const SizedBox(width: NoxSpacing.md),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              text,
              style: NoxTypography.body.copyWith(color: NoxColors.moonlightSilver),
            ),
          ),
        ),
      ],
    );
  }
}
