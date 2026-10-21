import 'package:flutter/material.dart';
import '../config/theme.dart';

class NoxBanner extends StatelessWidget {
  const NoxBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: NoxTheme.surface,
        border: Border(
          bottom: BorderSide(
            color: NoxTheme.accent.withAlpha(60),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shield_outlined,
              color: NoxTheme.accent.withAlpha(180), size: 14),
          const SizedBox(width: 8),
          Text(
            'This device is managed by NOX',
            style: TextStyle(
              color: NoxTheme.textSecondary.withAlpha(180),
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
