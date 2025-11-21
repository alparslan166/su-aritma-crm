import "package:equatable/equatable.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../domain/auth_role.dart";
import "auth_service.dart";

class LoginState extends Equatable {
  const LoginState({
    required this.role,
    required this.identifier,
    required this.secret,
    required this.rememberDevice,
    required this.status,
  });

  factory LoginState.initial() => const LoginState(
    role: AuthRole.admin,
    identifier: "",
    secret: "",
    rememberDevice: true,
    status: AsyncData<AuthResult?>(null),
  );

  final AuthRole role;
  final String identifier;
  final String secret;
  final bool rememberDevice;
  final AsyncValue<AuthResult?> status;

  LoginState copyWith({
    AuthRole? role,
    String? identifier,
    String? secret,
    bool? rememberDevice,
    AsyncValue<AuthResult?>? status,
  }) {
    return LoginState(
      role: role ?? this.role,
      identifier: identifier ?? this.identifier,
      secret: secret ?? this.secret,
      rememberDevice: rememberDevice ?? this.rememberDevice,
      status: status ?? this.status,
    );
  }

  @override
  List<Object?> get props => [role, identifier, secret, rememberDevice, status];
}
