import "package:flutter_riverpod/flutter_riverpod.dart";

import "auth_service.dart";
import "register_state.dart";

final registerControllerProvider =
    StateNotifierProvider<RegisterController, RegisterState>(
      (ref) => RegisterController(ref.watch(authServiceProvider)),
    );

class RegisterController extends StateNotifier<RegisterState> {
  RegisterController(this._authService) : super(RegisterState.initial());

  final AuthService _authService;

  void updateName(String value) {
    state = state.copyWith(name: value);
  }

  void updateEmail(String value) {
    state = state.copyWith(email: value);
  }

  void updatePassword(String value) {
    state = state.copyWith(password: value);
  }

  void updateConfirmPassword(String value) {
    state = state.copyWith(confirmPassword: value);
  }

  void updatePhone(String value) {
    state = state.copyWith(phone: value);
  }

  void updateRole(String value) {
    state = state.copyWith(role: value);
  }

  Future<void> submit() async {
    if (!state.isValid) {
      state = state.copyWith(
        status: AsyncError(
          AuthException(message: "Lütfen tüm alanları doğru şekilde doldurun"),
          StackTrace.current,
        ),
      );
      return;
    }

    state = state.copyWith(status: const AsyncLoading());
    try {
      final result = await _authService.signUp(
        name: state.name,
        email: state.email,
        password: state.password,
        phone: state.phone,
        role: state.role,
      );
      state = state.copyWith(status: AsyncData(result));
    } on AuthException catch (error) {
      state = state.copyWith(status: AsyncError(error, StackTrace.current));
    } catch (error, stackTrace) {
      state = state.copyWith(status: AsyncError(error, stackTrace));
    }
  }
}

