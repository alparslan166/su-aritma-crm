import "package:flutter_riverpod/flutter_riverpod.dart";

import "../domain/auth_role.dart";
import "auth_service.dart";
import "login_state.dart";

final loginControllerProvider =
    StateNotifierProvider<LoginController, LoginState>(
      (ref) => LoginController(ref.watch(authServiceProvider)),
    );

class LoginController extends StateNotifier<LoginState> {
  LoginController(this._authService) : super(LoginState.initial());

  final AuthService _authService;

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
    // Validate required fields
    if (state.role == AuthRole.personnel) {
      if (state.adminId.trim().isEmpty) {
        state = state.copyWith(
          status: AsyncError(
            AuthException(message: "Admin ID gereklidir"),
            StackTrace.current,
          ),
        );
        return;
      }
      if (state.identifier.trim().isEmpty) {
        state = state.copyWith(
          status: AsyncError(
            AuthException(message: "Personel ID gereklidir"),
            StackTrace.current,
          ),
        );
        return;
      }
      if (state.secret.trim().isEmpty || state.secret.length != 6) {
        state = state.copyWith(
          status: AsyncError(
            AuthException(message: "6 haneli giriş kodu gereklidir"),
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

    state = state.copyWith(status: const AsyncLoading());
    try {
      final result = await _authService.signIn(
        role: state.role,
        identifier: state.identifier.trim(),
        secret: state.secret.trim(),
        adminId: state.role == AuthRole.personnel ? state.adminId.trim().toUpperCase() : null,
      );
      state = state.copyWith(status: AsyncData(result));
    } on AuthException catch (error) {
      state = state.copyWith(status: AsyncError(error, StackTrace.current));
    } catch (error, stackTrace) {
      state = state.copyWith(status: AsyncError(error, stackTrace));
    }
  }
}
