import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Deep-link scheme + host for enrollment. Matches the backend landing
/// page's "Open NOX" button which emits `nox://enroll?token=…`.
const _enrollScheme = 'nox';
const _enrollHost = 'enroll';

/// Riverpod-managed listener for incoming deep links. Exposes the most
/// recent invite token so the enrollment screen can pick it up even if the
/// user arrived here before the screen was mounted.
class EnrollmentLinkState {
  final String? pendingInviteToken;
  const EnrollmentLinkState({this.pendingInviteToken});
}

class EnrollmentLinkController extends StateNotifier<EnrollmentLinkState> {
  final AppLinks _appLinks;
  StreamSubscription<Uri>? _sub;

  EnrollmentLinkController(this._appLinks) : super(const EnrollmentLinkState()) {
    _start();
  }

  Future<void> _start() async {
    // Cold-start: process whatever URL opened the app.
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) _handle(initial);
    } catch (e) {
      debugPrint('[deeplink] initial link failed: $e');
    }

    // Warm-start: keep listening while the app is alive.
    _sub = _appLinks.uriLinkStream.listen(
      _handle,
      onError: (e) => debugPrint('[deeplink] stream error: $e'),
    );
  }

  void _handle(Uri uri) {
    if (uri.scheme != _enrollScheme || uri.host != _enrollHost) return;
    final token = uri.queryParameters['token'];
    if (token == null || token.isEmpty) return;
    state = EnrollmentLinkState(pendingInviteToken: token);
  }

  /// Called by the enrollment screen once it has consumed the token so the
  /// state doesn't re-trigger navigation on rebuild.
  void consume() {
    state = const EnrollmentLinkState();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final enrollmentLinkProvider =
    StateNotifierProvider<EnrollmentLinkController, EnrollmentLinkState>((ref) {
  return EnrollmentLinkController(AppLinks());
});

/// Side-effect widget: push `/enroll?token=…` on the router whenever a new
/// invite link arrives. Place once near the root of the widget tree.
class DeepLinkListener extends ConsumerWidget {
  final Widget child;
  const DeepLinkListener({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<EnrollmentLinkState>(enrollmentLinkProvider, (prev, next) {
      final token = next.pendingInviteToken;
      if (token == null || token == prev?.pendingInviteToken) return;
      // Navigate on the next frame so any current build completes first.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          final router = GoRouter.of(context);
          router.push('/enroll?token=${Uri.encodeComponent(token)}');
        } catch (e) {
          debugPrint('[deeplink] navigate failed: $e');
        }
      });
    });
    return child;
  }
}
