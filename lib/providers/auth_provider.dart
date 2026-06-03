import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
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
  AuthNotifier(this._api) : super(const AuthState()) {
    _loadSession();
  }

  Future<void> _loadSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool('is_logged_in') ?? false;
      final savedUsername = prefs.getString('saved_username') ?? '';
      final savedPassword = prefs.getString('saved_password') ?? '';
      final savedRole = prefs.getString('saved_role') ?? '';

      if (isLoggedIn && savedUsername.isNotEmpty && savedPassword.isNotEmpty) {
        state = AuthState(
          isLoggedIn: true,
          username: savedUsername,
          role: savedRole.isNotEmpty ? savedRole : 'viewer',
        );
        // Silently re-authenticate in the background to refresh session cookies
        _api.login(savedUsername, savedPassword).then((data) {
          if (data['ok'] == true) {
            final newRole = data['role'] ?? 'viewer';
            state = state.copyWith(role: newRole);
            prefs.setString('saved_role', newRole);
          } else {
            // Bad credentials (e.g. password changed), trigger logout
            logout();
          }
        }).catchError((e) {
          debugPrint('Silent background re-login error: $e');
          // If it's a 401/403 credentials error, clear session.
          // Otherwise (like connection timeout), keep user logged in for offline/cached access.
          final errorStr = e.toString();
          if (errorStr.contains('401') || errorStr.contains('403')) {
            logout();
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading auth session: $e');
    }
  }

  Future<bool> login(String username, String password, {bool rememberMe = false}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await _api.login(username, password);
      if (data['ok'] == true) {
        final role = data['role'] ?? 'viewer';
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_logged_in', true);
        await prefs.setBool('remember_me', rememberMe);
        if (rememberMe) {
          await prefs.setString('saved_username', username);
          await prefs.setString('saved_password', password);
          await prefs.setString('saved_role', role);
        } else {
          await prefs.remove('saved_username');
          await prefs.remove('saved_password');
          await prefs.remove('saved_role');
        }

        state = state.copyWith(
          isLoggedIn: true,
          username:   data['username'] ?? username,
          role:       role,
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
        error: 'تعذّر الاتصال بالسيرفر — تحقق من الـ IP والشبكة\n($e)',
      );
      return false;
    }
  }

  Future<void> logout() async {
    try { await _api.logout(); } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_logged_in', false);
    } catch (_) {}
    state = const AuthState();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.read(apiClientProvider));
});
