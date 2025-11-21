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
}

class AuthException implements Exception {
  AuthException({required this.message});

  final String message;

  @override
  String toString() => message;
}
