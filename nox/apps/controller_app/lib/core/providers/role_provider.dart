import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../storage/secure_storage.dart';
import 'auth_provider.dart';

/// Normalized role for routing/UI decisions. ADMIN or EMPLOYEE; UNKNOWN
/// means we haven't finished loading the profile yet (treat as neither).
enum NoxRole { admin, employee, unknown }

final currentRoleProvider = Provider<NoxRole>((ref) {
  final auth = ref.watch(authStateProvider);
  if (!auth.isAuthenticated) return NoxRole.unknown;
  final role = auth.user?.role?.toUpperCase();
  return switch (role) {
    'ADMIN' => NoxRole.admin,
    'EMPLOYEE' => NoxRole.employee,
    _ => NoxRole.unknown,
  };
});

/// True if the device has previously enrolled via an invite (i.e. we have a
/// stored device token). Phase 4 agent code reads this to decide whether to
/// kick off background services on boot.
final hasEnrolledDeviceProvider = FutureProvider<bool>((ref) async {
  // Depends on auth state so re-logging-in refreshes it.
  ref.watch(authStateProvider);
  final storage = ref.watch(secureStorageProvider);
  return storage.hasDeviceToken();
});
