import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';

// ── Auth State ────────────────────────────────────────────────────────────────
class AuthState {
  final bool isLoggedIn;
  final String username;
  final String role;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.isLoggedIn = false,
    this.username   = '',
    this.role       = '',
    this.isLoading  = false,
    this.error,
  });

  bool get isAdmin => role == 'admin';

  AuthState copyWith({
    bool?   isLoggedIn,
    String? username,
    String? role,
    bool?   isLoading,
    String? error,
  }) => AuthState(
    isLoggedIn: isLoggedIn ?? this.isLoggedIn,
    username:   username   ?? this.username,
    role:       role       ?? this.role,
    isLoading:  isLoading  ?? this.isLoading,
    error:      error,
  );
}

// ── Auth Notifier ─────────────────────────────────────────────────────────────
class AuthNotifier extends StateNotifier<AuthState> {
  final ApiClient _api;
  AuthNotifier(this._api) : super(const AuthState());

  Future<bool> login(String username, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await _api.login(username, password);
      if (data['ok'] == true) {
        state = state.copyWith(
          isLoggedIn: true,
          username:   data['username'] ?? username,
          role:       data['role']     ?? 'viewer',
          isLoading:  false,
        );
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          error: data['error'] ?? 'بيانات الدخول غير صحيحة',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'تعذّر الاتصال بالسيرفر — تحقق من الـ IP والشبكة',
      );
      return false;
    }
  }

  Future<void> logout() async {
    try { await _api.logout(); } catch (_) {}
    state = const AuthState();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.read(apiClientProvider));
});
