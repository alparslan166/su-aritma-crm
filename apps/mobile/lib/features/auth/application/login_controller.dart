import "package:flutter/foundation.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:shared_preferences/shared_preferences.dart";

import "../domain/auth_role.dart";
import "auth_service.dart";
import "login_state.dart";

const _savedEmailKey = "saved_email";
const _savedPasswordKey = "saved_password";
const _rememberCredentialsKey = "remember_credentials";

final loginControllerProvider =
    StateNotifierProvider<LoginController, LoginState>(
      (ref) => LoginController(ref.watch(authServiceProvider)),
    );

class LoginController extends StateNotifier<LoginState> {
  LoginController(this._authService) : super(LoginState.initial());

  final AuthService _authService;

  /// Load saved email/password from SharedPreferences
  Future<void> loadSavedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final remembered = prefs.getBool(_rememberCredentialsKey) ?? false;
      
      if (remembered) {
        final savedEmail = prefs.getString(_savedEmailKey) ?? "";
        final savedPassword = prefs.getString(_savedPasswordKey) ?? "";
        
        if (savedEmail.isNotEmpty) {
          state = state.copyWith(
            identifier: savedEmail,
            secret: savedPassword,
            rememberDevice: true,
          );
          debugPrint("✅ Credentials loaded from storage");
        }
      }
    } catch (e) {
      debugPrint("❌ Failed to load saved credentials: $e");
    }
  }

  /// Get saved credentials (email, password) without changing state
  static Future<(String?, String?)> getSavedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final remembered = prefs.getBool(_rememberCredentialsKey) ?? false;
      
      if (remembered) {
        final savedEmail = prefs.getString(_savedEmailKey);
        final savedPassword = prefs.getString(_savedPasswordKey);
        return (savedEmail, savedPassword);
      }
    } catch (e) {
      debugPrint("❌ Failed to get saved credentials: $e");
    }
    return (null, null);
  }

  /// Fill credentials from saved data
  void fillSavedCredentials(String email, String password) {
    state = state.copyWith(
      identifier: email,
      secret: password,
    );
  }

  /// Save email/password to SharedPreferences
  Future<void> _saveCredentials(String email, String password) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_savedEmailKey, email);
      await prefs.setString(_savedPasswordKey, password);
      await prefs.setBool(_rememberCredentialsKey, true);
      debugPrint("✅ Credentials saved to storage");
    } catch (e) {
      debugPrint("❌ Failed to save credentials: $e");
    }
  }

  /// Clear saved credentials from SharedPreferences
  Future<void> _clearCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_savedEmailKey);
      await prefs.remove(_savedPasswordKey);
      await prefs.setBool(_rememberCredentialsKey, false);
      debugPrint("✅ Credentials cleared from storage");
    } catch (e) {
      debugPrint("❌ Failed to clear credentials: $e");
    }
  }

  void updateRole(AuthRole role) {
    state = state.copyWith(
      role: role,
      identifier: "",
      secret: "",
      adminId: "",
      status: const AsyncData(null),
    );
  }

  void updateIdentifier(String value) {
    state = state.copyWith(identifier: value);
  }

  void updateSecret(String value) {
    state = state.copyWith(secret: value);
  }

  void updateAdminId(String value) {
    // Trim and convert to uppercase for consistency
    state = state.copyWith(adminId: value.trim().toUpperCase());
  }

  void toggleRemember(bool value) {
    state = state.copyWith(rememberDevice: value);
  }

  Future<void> submit() async {
    debugPrint("🔵 Login submit called");
    debugPrint("🔵 Role: ${state.role}");
    debugPrint(
      "🔵 Admin ID: '${state.adminId}' (length: ${state.adminId.length})",
    );
    debugPrint(
      "🔵 Identifier: '${state.identifier}' (length: ${state.identifier.length})",
    );
    debugPrint("🔵 Secret: '${state.secret}' (length: ${state.secret.length})");

    // Validate required fields
    if (state.role == AuthRole.personnel) {
      if (state.adminId.trim().isEmpty) {
        debugPrint("❌ Admin ID is empty");
        state = state.copyWith(
          status: AsyncError(
            AuthException(message: "Admin ID gereklidir"),
            StackTrace.current,
          ),
        );
        return;
      }
      if (state.identifier.trim().isEmpty) {
        debugPrint("❌ Identifier is empty");
        state = state.copyWith(
          status: AsyncError(
            AuthException(message: "Personel ID gereklidir"),
            StackTrace.current,
          ),
        );
        return;
      }
      if (state.secret.trim().isEmpty) {
        debugPrint("❌ Secret is empty");
        state = state.copyWith(
          status: AsyncError(
            AuthException(message: "Personel şifresi gereklidir"),
            StackTrace.current,
          ),
        );
        return;
      }
    } else {
      if (state.identifier.trim().isEmpty) {
        state = state.copyWith(
          status: AsyncError(
            AuthException(message: "E-posta gereklidir"),
            StackTrace.current,
          ),
        );
        return;
      }
      if (state.secret.trim().isEmpty) {
        state = state.copyWith(
          status: AsyncError(
            AuthException(message: "Şifre gereklidir"),
            StackTrace.current,
          ),
        );
        return;
      }
    }

    debugPrint("✅ Validation passed, starting login...");
    state = state.copyWith(status: const AsyncLoading());
    try {
      final result = await _authService.signIn(
        role: state.role,
        identifier: state.identifier.trim(),
        secret: state.role == AuthRole.personnel
            ? state.secret.trim().toUpperCase()
            : state.secret.trim(),
        adminId: state.role == AuthRole.personnel
            ? state.adminId.trim().toUpperCase()
            : null,
      );
      debugPrint("✅ Login successful: ${result.identifier}");
      
      // Save or clear credentials based on rememberDevice setting
      if (state.rememberDevice && state.role == AuthRole.admin) {
        await _saveCredentials(state.identifier.trim(), state.secret.trim());
      } else {
        await _clearCredentials();
      }
      
      state = state.copyWith(status: AsyncData(result));
    } on AuthException catch (error) {
      debugPrint("❌ AuthException: ${error.message}");
      state = state.copyWith(status: AsyncError(error, StackTrace.current));
    } catch (error, stackTrace) {
      debugPrint("❌ Error: $error");
      state = state.copyWith(status: AsyncError(error, stackTrace));
    }
  }
}
