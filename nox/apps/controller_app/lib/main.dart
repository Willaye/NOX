import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nox_design_system/nox_design_system.dart';

import 'core/network/admin_ws.dart';
import 'core/network/deep_link_handler.dart';
import 'core/network/push_service.dart';
import 'core/router/app_router.dart';
import 'features/alerts/admin_alert_banner.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: NoxColors.voidBlack,
  ));
  runApp(const ProviderScope(child: NoxApp()));
}

class NoxApp extends ConsumerWidget {
  const NoxApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Eagerly build these so their listeners attach to auth state before any
    // UI tries to use them. All three degrade gracefully if dependencies are
    // missing (no Firebase config, no admin session, no deep link).
    ref.watch(adminWsProvider);
    ref.watch(pushServiceProvider);
    ref.watch(enrollmentLinkProvider);

    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'NOX',
      debugShowCheckedModeBanner: false,
      theme: NoxTheme.dark,
      routerConfig: router,
      builder: (context, child) {
        // Deep-link navigation + alert banner wrap the whole app so they
        // work on every screen without each one wiring them individually.
        return DeepLinkListener(
          child: AdminAlertBanner.wrap(child ?? const SizedBox.shrink()),
        );
      },
    );
  }
}
