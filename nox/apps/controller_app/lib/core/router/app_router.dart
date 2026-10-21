import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../providers/role_provider.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/auth/screens/welcome_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/signup_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/shell/main_shell.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/devices/screens/devices_screen.dart';
import '../../features/devices/screens/device_detail_screen.dart';
import '../../features/files/screens/files_screen.dart';
import '../../features/more/screens/more_screen.dart';
import '../../features/notifications/screens/notifications_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/enroll/screens/invite_employee_screen.dart';
import '../../features/employee/screens/enrollment_screen.dart';
import '../../features/employee/screens/running_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

class _AuthRefreshNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _AuthRefreshNotifier();

  ref.listen<AuthState>(authStateProvider, (previous, next) {
    if (previous?.isAuthenticated != next.isAuthenticated) {
      refreshNotifier.notify();
    }
    if (previous?.user?.role != next.user?.role) {
      refreshNotifier.notify();
    }
  });

  final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: refreshNotifier,
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/welcome', builder: (_, __) => const WelcomeScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (_, __) => const SignupScreen()),
      // Legacy direct-password register kept for backwards compatibility; the
      // primary signup flow is OTP-based at /signup.
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(
        path: '/forgot-password',
        builder: (_, __) => const ForgotPasswordScreen(),
      ),

      // ── Admin shell (bottom-nav) ────────────────────────────
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: HomeScreen()),
          ),
          GoRoute(
            path: '/devices',
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: DevicesScreen()),
            routes: [
              GoRoute(
                path: ':id',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (context, state) => DeviceDetailScreen(
                  deviceId: state.pathParameters['id']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/files',
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: FilesScreen()),
          ),
          GoRoute(
            path: '/more',
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: MoreScreen()),
          ),
        ],
      ),

      // ── Admin: invite flow (replaces /add-device) ────────────
      GoRoute(
        path: '/invite',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, __) => const InviteEmployeeScreen(),
      ),
      // Backwards-compat shim: the old nav used /add-device.
      GoRoute(
        path: '/add-device',
        parentNavigatorKey: _rootNavigatorKey,
        redirect: (_, __) => '/invite',
      ),

      GoRoute(
        path: '/notifications',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, __) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/settings',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, __) => const SettingsScreen(),
      ),

      // ── Employee flow ────────────────────────────────────────
      GoRoute(
        path: '/enroll',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final token = state.uri.queryParameters['token'];
          return EnrollmentScreen(inviteToken: token);
        },
      ),
      GoRoute(
        path: '/employee/running',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, __) => const EmployeeRunningScreen(),
      ),
    ],
    redirect: (context, state) {
      final auth = ref.read(authStateProvider);
      final role = ref.read(currentRoleProvider);
      final loc = state.matchedLocation;

      // Public routes: splash, auth screens, and the employee enrollment
      // deep-link landing (employees won't have an account before enrollment).
      final isPublic = loc == '/splash' ||
          loc == '/welcome' ||
          loc == '/login' ||
          loc == '/signup' ||
          loc == '/register' ||
          loc == '/forgot-password' ||
          loc.startsWith('/enroll') ||
          loc == '/employee/running';

      if (!auth.isAuthenticated) {
        return isPublic ? null : '/welcome';
      }

      // Signed-in employees should not see the admin shell.
      if (role == NoxRole.employee) {
        if (loc.startsWith('/home') ||
            loc.startsWith('/devices') ||
            loc.startsWith('/files') ||
            loc.startsWith('/invite') ||
            loc.startsWith('/add-device')) {
          return '/employee/running';
        }
      }

      // Signed-in admins should never land on the employee screens except
      // when deliberately testing (they can hit /enroll directly).
      return null;
    },
  );

  ref.onDispose(() {
    router.dispose();
    refreshNotifier.dispose();
  });

  return router;
});
