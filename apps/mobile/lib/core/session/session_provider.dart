import "dart:convert";

import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:shared_preferences/shared_preferences.dart";

import "../../features/auth/domain/auth_role.dart";

class AuthSession {
  AuthSession({required this.role, required this.identifier});

  final AuthRole role;
  final String identifier;

  Map<String, dynamic> toJson() => {
    "role": role.name,
    "identifier": identifier,
  };

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
    role: AuthRole.values.firstWhere(
      (r) => r.name == json["role"],
      orElse: () => AuthRole.admin,
    ),
    identifier: json["identifier"] as String,
  );
}

final authSessionProvider =
    StateNotifierProvider<AuthSessionNotifier, AuthSession?>(
      (ref) => AuthSessionNotifier(),
    );

class AuthSessionNotifier extends StateNotifier<AuthSession?> {
  AuthSessionNotifier() : super(null) {
    _loadSession();
  }

  static const String _sessionKey = "auth_session";
  static const String _rememberKey = "remember_device";

  /// Load session from device storage
  Future<void> _loadSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final remember = prefs.getBool(_rememberKey) ?? false;
      
      if (remember) {
        final sessionJson = prefs.getString(_sessionKey);
        if (sessionJson != null) {
          final sessionMap = jsonDecode(sessionJson) as Map<String, dynamic>;
          state = AuthSession.fromJson(sessionMap);
        }
      }
    } catch (e) {
      // Session yüklenemezse null kalır
      state = null;
    }
  }

  /// Set session - stored in memory and optionally persisted to device
  Future<void> setSession(AuthSession? session, {bool remember = false}) async {
    state = session;
    
    final prefs = await SharedPreferences.getInstance();
    
    if (remember && session != null) {
      // Session'ı kaydet
      await prefs.setString(_sessionKey, jsonEncode(session.toJson()));
      await prefs.setBool(_rememberKey, true);
    } else {
      // Session'ı temizle
      await prefs.remove(_sessionKey);
      await prefs.setBool(_rememberKey, false);
    }
  }

  /// Clear session from memory and device storage
  Future<void> clearSession() async {
    state = null;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
    await prefs.setBool(_rememberKey, false);
  }
}
