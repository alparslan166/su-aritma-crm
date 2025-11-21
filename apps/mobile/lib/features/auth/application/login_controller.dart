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
      status: const AsyncData(null),
    );
  }

  void updateIdentifier(String value) {
    state = state.copyWith(identifier: value);
  }

  void updateSecret(String value) {
    state = state.copyWith(secret: value);
  }

  void toggleRemember(bool value) {
    state = state.copyWith(rememberDevice: value);
  }

  Future<void> submit() async {
    state = state.copyWith(status: const AsyncLoading());
    try {
      final result = await _authService.signIn(
        role: state.role,
        identifier: state.identifier,
        secret: state.secret,
      );
      state = state.copyWith(status: AsyncData(result));
    } on AuthException catch (error) {
      state = state.copyWith(status: AsyncError(error, StackTrace.current));
    } catch (error, stackTrace) {
      state = state.copyWith(status: AsyncError(error, stackTrace));
    }
  }
}
