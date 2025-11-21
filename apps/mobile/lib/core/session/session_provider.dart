import "package:hooks_riverpod/hooks_riverpod.dart";

import "../../features/auth/domain/auth_role.dart";

class AuthSession {
  AuthSession({required this.role, required this.identifier});

  final AuthRole role;
  final String identifier;
}

final authSessionProvider = StateProvider<AuthSession?>((ref) => null);
