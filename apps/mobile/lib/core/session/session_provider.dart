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
  AuthSessionNotifier() : super(null);

  /// Set session - only stored in memory, not persisted to device
  Future<void> setSession(AuthSession? session, {bool remember = false}) async {
    state = session;
    // Session is only kept in memory, never saved to device storage
  }

  /// Clear session from memory
  Future<void> clearSession() async {
    state = null;
    // No device storage to clear
  }
}
