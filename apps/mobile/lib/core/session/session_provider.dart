import "package:hooks_riverpod/hooks_riverpod.dart";

import "../../features/auth/domain/auth_role.dart";
import "session_storage.dart";

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

  Future<void> _loadSession() async {
    final sessionData = await SessionStorage.loadSession();
    if (sessionData != null) {
      state = AuthSession.fromJson(sessionData);
    }
  }

  Future<void> setSession(AuthSession? session, {bool remember = false}) async {
    state = session;

    if (session != null && remember) {
      await SessionStorage.saveSession(
        role: session.role.name,
        identifier: session.identifier,
        remember: remember,
      );
    } else if (session == null) {
      await SessionStorage.clearSession();
    }
  }

  Future<void> clearSession() async {
    state = null;
    await SessionStorage.clearSession();
  }
}
