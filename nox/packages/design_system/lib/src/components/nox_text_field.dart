import 'package:flutter/material.dart';
import '../theme/nox_colors.dart';
import '../theme/nox_typography.dart';
import '../theme/nox_spacing.dart';

class NoxTextField extends StatefulWidget {
  final String? label;
  final String? hint;
  final String? errorText;
  final TextEditingController? controller;
  final bool obscureText;
  final bool showPasswordToggle;
  final IconData? leadingIcon;
  final Widget? trailing;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;
  final bool enabled;
  final int maxLines;
  final int? maxLength;
  final bool autofocus;
  final EdgeInsets? contentPadding;

  const NoxTextField({
    super.key,
    this.label,
    this.hint,
    this.errorText,
    this.controller,
    this.obscureText = false,
    this.showPasswordToggle = false,
    this.leadingIcon,
    this.trailing,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
    this.enabled = true,
    this.maxLines = 1,
    this.maxLength,
    this.autofocus = false,
    this.contentPadding,
  });

  @override
  State<NoxTextField> createState() => _NoxTextFieldState();
}

class _NoxTextFieldState extends State<NoxTextField> {
  late bool _isObscured;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _isObscured = widget.obscureText;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!.toUpperCase(),
            style: NoxTypography.label,
          ),
          const SizedBox(height: NoxSpacing.sm),
        ],
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(NoxSpacing.radiusMd),
            boxShadow: _isFocused
                ? [
                    BoxShadow(
                      color: NoxColors.lavenderPrimary.withValues(alpha: 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Focus(
            onFocusChange: (hasFocus) {
              setState(() => _isFocused = hasFocus);
            },
            child: TextFormField(
              controller: widget.controller,
              obscureText: _isObscured,
              keyboardType: widget.keyboardType,
              textInputAction: widget.textInputAction,
              validator: widget.validator,
              onChanged: widget.onChanged,
              onFieldSubmitted: widget.onSubmitted,
              focusNode: widget.focusNode,
              enabled: widget.enabled,
              maxLines: widget.maxLines,
              maxLength: widget.maxLength,
              autofocus: widget.autofocus,
              style: NoxTypography.body.copyWith(color: NoxColors.pureWhite),
              cursorColor: NoxColors.lavenderPrimary,
              decoration: InputDecoration(
                hintText: widget.hint,
                errorText: widget.errorText,
                contentPadding: widget.contentPadding,
                prefixIcon: widget.leadingIcon != null
                    ? Icon(
                        widget.leadingIcon,
                        size: 20,
                        color: _isFocused
                            ? NoxColors.lavenderPrimary
                            : NoxColors.mistGray,
                      )
                    : null,
                suffixIcon: _buildTrailingWidget(),
                errorStyle: NoxTypography.caption.copyWith(
                  color: NoxColors.offlineRed,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget? _buildTrailingWidget() {
    if (widget.showPasswordToggle && widget.obscureText) {
      return GestureDetector(
        onTap: () => setState(() => _isObscured = !_isObscured),
        child: Icon(
          _isObscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          size: 20,
          color: NoxColors.mistGray,
        ),
      );
    }
    return widget.trailing;
  }
}
