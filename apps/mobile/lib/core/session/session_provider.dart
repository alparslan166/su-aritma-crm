import "dart:convert";

import "package:flutter/foundation.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:shared_preferences/shared_preferences.dart";

import "../../features/auth/domain/auth_role.dart";

const _sessionKey = "auth_session";
const _rememberKey = "remember_device";

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
    // Load saved session on initialization
    _loadSavedSession();
  }

  Future<void> _loadSavedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final remembered = prefs.getBool(_rememberKey) ?? false;
      
      if (remembered) {
        final sessionJson = prefs.getString(_sessionKey);
        if (sessionJson != null) {
          final sessionData = jsonDecode(sessionJson) as Map<String, dynamic>;
          state = AuthSession.fromJson(sessionData);
          debugPrint("✅ Session restored from storage");
        }
      }
    } catch (e) {
      debugPrint("❌ Failed to load saved session: $e");
    }
  }

  /// Set session - if remember is true, saves to device storage
  Future<void> setSession(AuthSession? session, {bool remember = false}) async {
    state = session;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      if (session != null && remember) {
        // Save session to device storage
        await prefs.setString(_sessionKey, jsonEncode(session.toJson()));
        await prefs.setBool(_rememberKey, true);
        debugPrint("✅ Session saved to storage (remember=true)");
      } else {
        // Clear saved session if not remembering
        await prefs.remove(_sessionKey);
        await prefs.setBool(_rememberKey, false);
        debugPrint("🔄 Session not saved (remember=false)");
      }
    } catch (e) {
      debugPrint("❌ Failed to save session: $e");
    }
  }

  /// Clear session from memory and storage
  Future<void> clearSession() async {
    state = null;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionKey);
      await prefs.setBool(_rememberKey, false);
      debugPrint("✅ Session cleared from storage");
    } catch (e) {
      debugPrint("❌ Failed to clear session: $e");
    }
  }
}
