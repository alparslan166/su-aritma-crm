import "dart:async";

import "package:dio/dio.dart";
import "package:flutter/foundation.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";

import "../../../core/network/api_client.dart";
import "../domain/auth_role.dart";

class AuthResult {
  AuthResult({required this.role, required this.identifier});

  final AuthRole role;
  final String identifier;
}

abstract class AuthService {
  Future<AuthResult> signIn({
    required AuthRole role,
    required String identifier,
    required String secret,
  });

  Future<AuthResult> signUp({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String role,
  });
}

class ApiAuthService implements AuthService {
  ApiAuthService(this._client);

  final Dio _client;

  @override
  Future<AuthResult> signIn({
    required AuthRole role,
    required String identifier,
    required String secret,
  }) async {
    try {
      final response = await _client.post(
        "/auth/login",
        data: {
          "identifier": identifier,
          "password": secret,
          "role": role == AuthRole.admin ? "admin" : "personnel",
        },
      );
      final data = response.data["data"] as Map<String, dynamic>;
      debugPrint("Signed in as $role (${data["id"]})");
      return AuthResult(role: role, identifier: data["id"] as String);
    } on DioException catch (error) {
      final message =
          error.response?.data?["message"]?.toString() ?? "Giriş başarısız";
      throw AuthException(message: message);
    }
  }

  @override
  Future<AuthResult> signUp({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String role,
  }) async {
    try {
      final response = await _client.post(
        "/auth/register",
        data: {
          "name": name,
          "email": email,
          "password": password,
          "phone": phone,
          "role": role,
        },
      );
      final data = response.data["data"] as Map<String, dynamic>;
      debugPrint("Signed up as admin (${data["id"]})");
      // After signup, automatically sign in
      return await signIn(
        role: AuthRole.admin,
        identifier: email,
        secret: password,
      );
    } on DioException catch (error) {
      final message =
          error.response?.data?["message"]?.toString() ?? "Kayıt başarısız";
      throw AuthException(message: message);
    }
  }
}

final authServiceProvider = Provider<AuthService>((ref) {
  final client = ref.watch(apiClientProvider);
  return ApiAuthService(client);
});

class MockAuthService implements AuthService {
  @override
  Future<AuthResult> signIn({
    required AuthRole role,
    required String identifier,
    required String secret,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    final isValid = identifier.isNotEmpty && secret.length >= 4;
    if (!isValid) {
      throw AuthException(
        message: role == AuthRole.admin
            ? "Admin bilgilerini kontrol edin"
            : "Personel kodu hatalı",
      );
    }
    debugPrint("Signed in as $role ($identifier)");
    return AuthResult(role: role, identifier: identifier);
  }

  @override
  Future<AuthResult> signUp({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String role,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (email.isEmpty || password.length < 6) {
      throw AuthException(message: "Geçersiz bilgiler");
    }
    debugPrint("Signed up as admin ($email)");
    return AuthResult(role: AuthRole.admin, identifier: email);
  }
}

class AuthException implements Exception {
  AuthException({required this.message});

  final String message;

  @override
  String toString() => message;
}
