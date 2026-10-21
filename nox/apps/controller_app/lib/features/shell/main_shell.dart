import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nox_design_system/nox_design_system.dart';

class MainShell extends StatelessWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/home')) return 0;
    if (location.startsWith('/devices')) return 1;
    if (location.startsWith('/files')) return 2;
    if (location.startsWith('/more')) return 3;
    return 0;
  }

  void _onTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/home');
      case 1:
        context.go('/devices');
      case 2:
        context.go('/files');
      case 3:
        context.go('/more');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: NoxBottomNav(
        currentIndex: _currentIndex(context),
        onTap: (index) => _onTap(context, index),
      ),
    );
  }
}
