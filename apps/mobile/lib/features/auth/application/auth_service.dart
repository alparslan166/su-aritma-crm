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
    String? adminId,
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
    String? adminId,
  }) async {
    try {
      final requestData = <String, dynamic>{
        "identifier": identifier,
        "password": secret,
        "role": role == AuthRole.admin ? "admin" : "personnel",
      };
      if (adminId != null && adminId.isNotEmpty) {
        requestData["adminId"] = adminId;
      }
      final response = await _client.post(
        "/auth/login",
        data: requestData,
      );
      final data = response.data["data"] as Map<String, dynamic>;
      debugPrint("Signed in as $role (${data["id"]})");
      return AuthResult(role: role, identifier: data["id"] as String);
    } on DioException catch (error) {
      // Parse error message from backend
      String message = "Giriş başarısız";

      if (error.response?.data != null) {
        final errorData = error.response!.data;

        // Check for Zod validation errors
        if (errorData is Map<String, dynamic>) {
          // Check for issues array (Zod validation errors)
          if (errorData.containsKey("issues") && errorData["issues"] is List) {
            final issues = errorData["issues"] as List;
            if (issues.isNotEmpty) {
              final firstIssue = issues[0] as Map<String, dynamic>;
              message = firstIssue["message"]?.toString() ?? message;
            }
          }
          // Check for direct message
          else if (errorData.containsKey("message")) {
            message = errorData["message"].toString();
          }
          // Check for error field
          else if (errorData.containsKey("error")) {
            message = errorData["error"].toString();
          }
        }
      }

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
      // Parse error message from backend
      String message = "Kayıt başarısız";

      if (error.response?.data != null) {
        final errorData = error.response!.data;

        // Check for Zod validation errors
        if (errorData is Map<String, dynamic>) {
          // Check for issues array (Zod validation errors)
          if (errorData.containsKey("issues") && errorData["issues"] is List) {
            final issues = errorData["issues"] as List;
            if (issues.isNotEmpty) {
              final firstIssue = issues[0] as Map<String, dynamic>;
              message = firstIssue["message"]?.toString() ?? message;
            }
          }
          // Check for direct message
          else if (errorData.containsKey("message")) {
            message = errorData["message"].toString();
          }
          // Check for error field
          else if (errorData.containsKey("error")) {
            message = errorData["error"].toString();
          }
        }
      }

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
    String? adminId,
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
