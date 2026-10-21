import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/api_client.dart';
import '../storage/secure_storage.dart';

// ── User Model ───────────────────────────────────────────────
// backend-project returns: { id, email, role, createdAt }
// No firstName/lastName — we derive display name from email.
class NoxUser {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String? role;
  final String? avatarUrl;
  final DateTime? createdAt;

  const NoxUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.role,
    this.avatarUrl,
    this.createdAt,
  });

  String get fullName {
    final name = '$firstName $lastName'.trim();
    return name.isNotEmpty ? name : email.split('@').first;
  }

  factory NoxUser.fromJson(Map<String, dynamic> json) {
    var firstName = json['firstName']?.toString() ?? '';
    var lastName = json['lastName']?.toString() ?? '';

    // backend-project has no firstName/lastName — derive from email
    if (firstName.isEmpty && lastName.isEmpty) {
      final name = json['name']?.toString().trim() ?? '';
      if (name.isNotEmpty) {
        final idx = name.indexOf(' ');
        firstName = idx == -1 ? name : name.substring(0, idx);
        lastName = idx == -1 ? '' : name.substring(idx + 1).trim();
      } else {
        // Use email prefix as first name
        firstName = (json['email']?.toString() ?? '').split('@').first;
      }
    }

    final avatar = json['avatarUrl']?.toString();

    return NoxUser(
      id: json['id']?.toString() ?? '',
      firstName: firstName,
      lastName: lastName,
      email: json['email']?.toString() ?? '',
      role: json['role']?.toString(),
      avatarUrl: (avatar != null && avatar.isNotEmpty) ? avatar : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'firstName': firstName,
    'lastName': lastName,
    'email': email,
    'role': role,
    'avatarUrl': avatarUrl,
    'createdAt': createdAt?.toIso8601String(),
  };

  String get initials {
    final f = firstName.trim();
    final l = lastName.trim();
    if (f.isNotEmpty && l.isNotEmpty) return '${f[0]}${l[0]}'.toUpperCase();
    if (f.isNotEmpty) return f[0].toUpperCase();
    if (l.isNotEmpty) return l[0].toUpperCase();
    return email.isNotEmpty ? email[0].toUpperCase() : '?';
  }
}

// ── Auth State ───────────────────────────────────────────────
class AuthState {
  final NoxUser? user;
  final String? token;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.user,
    this.token,
    this.isLoading = false,
    this.error,
  });

  bool get isAuthenticated => token != null && user != null;

  AuthState copyWith({
    NoxUser? user,
    String? token,
    bool? isLoading,
    String? error,
    bool clearUser = false,
    bool clearToken = false,
    bool clearError = false,
  }) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      token: clearToken ? null : (token ?? this.token),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// ── Auth Notifier ────────────────────────────────────────────
class AuthNotifier extends StateNotifier<AuthState> {
  final ApiClient _api;
  final SecureStorageService _storage;

  AuthNotifier(this._api, this._storage) : super(const AuthState()) {
    _api.onSessionExpired = () {
      if (mounted) state = const AuthState();
    };
  }

  @override
  void dispose() {
    _api.onSessionExpired = null;
    super.dispose();
  }

  Future<void> checkAuth() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final hasToken = await _storage.hasToken();
      if (!hasToken) {
        state = state.copyWith(isLoading: false);
        return;
      }

      final response = await _api.getProfile();
      final userData = response.data;

      NoxUser user;
      if (userData is Map<String, dynamic>) {
        user = NoxUser.fromJson(userData);
      } else {
        throw Exception('Invalid profile response');
      }

      final token = await _storage.getToken();
      await _storage.saveUserData(jsonEncode(user.toJson()));
      state = AuthState(user: user, token: token);
    } catch (e) {
      final cached = await _storage.getUserData();
      final token = await _storage.getToken();
      if (cached != null && token != null && token.isNotEmpty) {
        final user = NoxUser.fromJson(jsonDecode(cached));
        state = AuthState(user: user, token: token);
      } else {
        await _storage.clearAll();
        state = const AuthState();
      }
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _api.login(email, password);
      final data = response.data as Map<String, dynamic>;

      // backend-project returns: { user: {...}, accessToken: "..." }
      final token = data['accessToken']?.toString() ?? '';
      if (token.isEmpty) throw Exception('Missing access token');
      await _storage.saveToken(token);

      // User is in the response, also fetch fresh profile
      final profileResponse = await _api.getProfile();
      final user = NoxUser.fromJson(profileResponse.data as Map<String, dynamic>);
      await _storage.saveUserData(jsonEncode(user.toJson()));

      state = AuthState(user: user, token: token);
      return true;
    } catch (e) {
      final message = _parseError(e);
      state = state.copyWith(isLoading: false, error: message);
      return false;
    }
  }

  Future<bool> register(
    String firstName,
    String lastName,
    String email,
    String password,
  ) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _api.signup(firstName, lastName, email, password);
      final data = response.data as Map<String, dynamic>;

      // backend-project signup returns same shape as login
      final token = data['accessToken']?.toString() ?? '';
      if (token.isEmpty) throw Exception('Missing access token');
      await _storage.saveToken(token);

      final userJson = data['user'];
      final user = userJson is Map<String, dynamic>
          ? NoxUser.fromJson(userJson)
          : NoxUser.fromJson(
              (await _api.getProfile()).data as Map<String, dynamic>,
            );
      await _storage.saveUserData(jsonEncode(user.toJson()));

      state = AuthState(user: user, token: token);
      return true;
    } catch (e) {
      final message = _parseError(e);
      state = state.copyWith(isLoading: false, error: message);
      return false;
    }
  }

  Future<void> logout() async {
    // backend-project has no logout endpoint — just clear locally
    await _api.logout();
    state = const AuthState();
  }

  // ── 3-step signup via email OTP ─────────────────────────────
  // Step 1: request an OTP sent to the email.
  Future<String?> requestOtp(String email) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _api.requestMagicLink(email);
      state = state.copyWith(isLoading: false);
      return null;
    } catch (e) {
      final message = _parseError(e);
      state = state.copyWith(isLoading: false, error: message);
      return message;
    }
  }

  // Step 2: verify the OTP and remember the resulting JWT so we can call
  // /auth/set-password straight afterwards. Returns null on success.
  Future<String?> verifyOtp(String token) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _api.verifyMagicLink(token);
      final data = response.data as Map<String, dynamic>;
      final accessToken = data['accessToken']?.toString() ?? '';
      if (accessToken.isEmpty) throw Exception('Missing access token');
      await _storage.saveToken(accessToken);
      final userJson = data['user'];
      final user = userJson is Map<String, dynamic>
          ? NoxUser.fromJson(userJson)
          : NoxUser.fromJson(
              (await _api.getProfile()).data as Map<String, dynamic>,
            );
      await _storage.saveUserData(jsonEncode(user.toJson()));
      // Keep isLoading=false but don't flip authState to "authenticated" yet —
      // the set-password step is still required for new users. Routers can
      // continue listening to isAuthenticated once the password step completes.
      state = AuthState(user: user, token: accessToken);
      return null;
    } catch (e) {
      final message = _parseError(e);
      state = state.copyWith(isLoading: false, error: message);
      return message;
    }
  }

  // Step 3: set the account password. Requires verifyOtp() to have run.
  Future<String?> setPassword(String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _api.setPassword(password);
      state = state.copyWith(isLoading: false);
      return null;
    } catch (e) {
      final message = _parseError(e);
      state = state.copyWith(isLoading: false, error: message);
      return message;
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  String _parseError(dynamic e) {
    if (e is Exception) {
      final str = e.toString();
      if (str.contains('401')) return 'Invalid email, password or code';
      if (str.contains('409')) return 'An account with this email already exists';
      if (str.contains('429')) return 'Too many attempts. Try again in a minute.';
      // 503 = backend accepted the request but the email provider could not
      // deliver the code. Tell the user to retry with Resend.
      if (str.contains('503')) {
        return "We couldn't send your code right now. Please tap Resend in a few seconds.";
      }
      if (str.contains('422') || str.contains('400')) {
        return 'Please check your input and try again';
      }
      if (str.contains('timeout') ||
          str.contains('SocketException') ||
          str.contains('Connection')) {
        return 'Unable to reach the server. Check your connection and try again.';
      }
    }
    return 'Something went wrong. Please try again.';
  }
}

// ── Providers ────────────────────────────────────────────────
final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final api = ref.watch(apiClientProvider);
  final storage = ref.watch(secureStorageProvider);
  return AuthNotifier(api, storage);
});
