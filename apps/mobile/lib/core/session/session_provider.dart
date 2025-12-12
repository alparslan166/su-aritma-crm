import "package:hooks_riverpod/hooks_riverpod.dart";

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
    // No persistent storage - session only in memory
    // All data should be stored in database, not on device
  }

  /// Set session - stored only in memory (no device storage)
  /// "remember" parameter is kept for API compatibility but has no effect
  /// Session will be lost when app is closed or uninstalled
  Future<void> setSession(AuthSession? session, {bool remember = false}) async {
    // Store session only in memory - no device storage
    // All authentication data should come from database
    state = session;
  }

  /// Clear session from memory
  Future<void> clearSession() async {
    state = null;
  }
}
