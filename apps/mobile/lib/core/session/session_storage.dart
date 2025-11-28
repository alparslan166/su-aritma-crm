import "dart:convert";

import "package:shared_preferences/shared_preferences.dart";

class SessionStorage {
  static const String _sessionKey = "auth_session";
  static const String _rememberKey = "remember_device";

  /// Save session to persistent storage
  static Future<void> saveSession({
    required String role,
    required String identifier,
    required bool remember,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    if (remember) {
      await prefs.setString(
        _sessionKey,
        jsonEncode({"role": role, "identifier": identifier}),
      );
      await prefs.setBool(_rememberKey, true);
    } else {
      // If not remembering, clear any existing session
      await prefs.remove(_sessionKey);
      await prefs.setBool(_rememberKey, false);
    }
  }

  /// Load session from persistent storage
  static Future<Map<String, dynamic>?> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final remember = prefs.getBool(_rememberKey) ?? false;

    if (!remember) {
      return null;
    }

    final sessionJson = prefs.getString(_sessionKey);
    if (sessionJson == null) {
      return null;
    }

    try {
      return jsonDecode(sessionJson) as Map<String, dynamic>;
    } catch (e) {
      // Invalid session data, clear it
      await clearSession();
      return null;
    }
  }

  /// Clear session from persistent storage
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
    await prefs.remove(_rememberKey);
  }

  /// Check if remember device is enabled
  static Future<bool> isRememberEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_rememberKey) ?? false;
  }
}
