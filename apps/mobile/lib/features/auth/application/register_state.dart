import "package:equatable/equatable.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "auth_service.dart";

class RegisterState extends Equatable {
  const RegisterState({
    required this.name,
    required this.email,
    required this.password,
    required this.confirmPassword,
    required this.phone,
    required this.role,
    required this.status,
  });

  factory RegisterState.initial() => const RegisterState(
    name: "",
    email: "",
    password: "",
    confirmPassword: "",
    phone: "",
    role: "ALT",
    status: AsyncData<AuthResult?>(null),
  );

  final String name;
  final String email;
  final String password;
  final String confirmPassword;
  final String phone;
  final String role; // "ANA" or "ALT"
  final AsyncValue<AuthResult?> status;

  RegisterState copyWith({
    String? name,
    String? email,
    String? password,
    String? confirmPassword,
    String? phone,
    String? role,
    AsyncValue<AuthResult?>? status,
  }) {
    return RegisterState(
      name: name ?? this.name,
      email: email ?? this.email,
      password: password ?? this.password,
      confirmPassword: confirmPassword ?? this.confirmPassword,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      status: status ?? this.status,
    );
  }

  bool get isValid {
    return name.isNotEmpty &&
        email.isNotEmpty &&
        password.length >= 6 &&
        password == confirmPassword &&
        phone.isNotEmpty;
  }

  @override
  List<Object?> get props => [
        name,
        email,
        password,
        confirmPassword,
        phone,
        role,
        status,
      ];
}

