import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Terminal screen for enrolled employees. Phase 4 (native agent) replaces
/// this with a hidden MainActivity, but for Phase 3 we show a static page
/// so manual QA knows the setup finished.
class EmployeeRunningScreen extends ConsumerWidget {
  const EmployeeRunningScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Scaffold(
      backgroundColor: Color(0xFF050505),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.shield_outlined, size: 72, color: Color(0xFF00E5FF)),
              SizedBox(height: 16),
              Text(
                'NOX is active',
                style: TextStyle(
                    color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 8),
              Text(
                'This device is enrolled and reporting to your administrator. '
                'You can close this app — it will keep running in the background.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Color(0xFFCCCCCC), fontSize: 14, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
