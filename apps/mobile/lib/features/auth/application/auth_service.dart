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

  Future<SignUpResult> signUp({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String role,
  });

  Future<void> sendVerificationCode(String email);
  Future<AuthResult> verifyEmail(String email, String code);
  Future<void> forgotPassword(String email);
  Future<void> resetPassword(String email, String code, String newPassword);
}

class SignUpResult {
  SignUpResult({
    required this.id,
    required this.email,
    required this.name,
    required this.emailVerified,
  });

  final String id;
  final String email;
  final String name;
  final bool emailVerified;
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
  Future<SignUpResult> signUp({
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
      return SignUpResult(
        id: data["id"] as String,
        email: data["email"] as String,
        name: data["name"] as String,
        emailVerified: data["emailVerified"] as bool? ?? false,
      );
    } on DioException catch (error) {
      throw AuthException(message: _parseErrorMessage(error, "Kayıt başarısız"));
    }
  }

  @override
  Future<void> sendVerificationCode(String email) async {
    try {
      await _client.post(
        "/auth/send-verification-code",
        data: {"email": email},
      );
    } on DioException catch (error) {
      throw AuthException(message: _parseErrorMessage(error, "Kod gönderilemedi"));
    }
  }

  @override
  Future<AuthResult> verifyEmail(String email, String code) async {
    try {
      final response = await _client.post(
        "/auth/verify-email",
        data: {"email": email, "code": code},
      );
      final data = response.data["data"] as Map<String, dynamic>;
      debugPrint("Email verified for ${data["email"]}");
      return AuthResult(role: AuthRole.admin, identifier: data["id"] as String);
    } on DioException catch (error) {
      throw AuthException(message: _parseErrorMessage(error, "Doğrulama başarısız"));
    }
  }

  @override
  Future<void> forgotPassword(String email) async {
    try {
      await _client.post(
        "/auth/forgot-password",
        data: {"email": email},
      );
    } on DioException catch (error) {
      throw AuthException(message: _parseErrorMessage(error, "İşlem başarısız"));
    }
  }

  @override
  Future<void> resetPassword(String email, String code, String newPassword) async {
    try {
      await _client.post(
        "/auth/reset-password",
        data: {
          "email": email,
          "code": code,
          "newPassword": newPassword,
        },
      );
    } on DioException catch (error) {
      throw AuthException(message: _parseErrorMessage(error, "Şifre sıfırlanamadı"));
    }
  }

  String _parseErrorMessage(DioException error, String defaultMessage) {
    if (error.response?.data != null) {
      final errorData = error.response!.data;
      if (errorData is Map<String, dynamic>) {
        if (errorData.containsKey("issues") && errorData["issues"] is List) {
          final issues = errorData["issues"] as List;
          if (issues.isNotEmpty) {
            final firstIssue = issues[0] as Map<String, dynamic>;
            return firstIssue["message"]?.toString() ?? defaultMessage;
          }
        } else if (errorData.containsKey("message")) {
          return errorData["message"].toString();
        } else if (errorData.containsKey("error")) {
          return errorData["error"].toString();
        }
      }
    }
    return defaultMessage;
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
  Future<SignUpResult> signUp({
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
    return SignUpResult(
      id: "mock-id",
      email: email,
      name: name,
      emailVerified: false,
    );
  }

  @override
  Future<void> sendVerificationCode(String email) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    debugPrint("Mock: Verification code sent to $email");
  }

  @override
  Future<AuthResult> verifyEmail(String email, String code) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (code != "123456") {
      throw AuthException(message: "Geçersiz kod");
    }
    return AuthResult(role: AuthRole.admin, identifier: "mock-id");
  }

  @override
  Future<void> forgotPassword(String email) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    debugPrint("Mock: Password reset code sent to $email");
  }

  @override
  Future<void> resetPassword(String email, String code, String newPassword) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (code != "123456") {
      throw AuthException(message: "Geçersiz kod");
    }
    debugPrint("Mock: Password reset for $email");
  }
}

class AuthException implements Exception {
  AuthException({required this.message});

  final String message;

  @override
  String toString() => message;
}
