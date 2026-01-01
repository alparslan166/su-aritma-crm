import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_hooks/flutter_hooks.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";

import "../../../routing/app_router.dart";
import "../../../widgets/primary_button.dart";
import "../application/auth_service.dart";
import "../application/register_controller.dart";
import "email_verification_page.dart";

class RegisterPage extends HookConsumerWidget {
  const RegisterPage({super.key});

  static const routeName = "register";

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final registerState = ref.watch(registerControllerProvider);
    final controller = ref.read(registerControllerProvider.notifier);

    final nameController = useTextEditingController();
    final emailController = useTextEditingController();
    final passwordController = useTextEditingController();
    final confirmPasswordController = useTextEditingController();
    final phoneController = useTextEditingController();

    ref.listen(registerControllerProvider, (previous, next) {
      final prevStatus = previous?.status;
      final nextStatus = next.status;

      final transitionedFromLoading =
          prevStatus?.isLoading == true &&
          nextStatus is AsyncData<SignUpResult?>;
      if (transitionedFromLoading) {
        final result = nextStatus.value;
        if (result != null) {
          // Navigate to email verification page
          ref
              .read(appRouterProvider)
              .goNamed(
                EmailVerificationPage.routeName,
                extra: {
                  "email": result.email,
                  "name": result.name,
                  "password": registerState.password,
                },
              );
          return;
        }
      }

      final errored = nextStatus is AsyncError;
      if (errored && prevStatus?.isLoading == true) {
        final errorMessage = nextStatus.error.toString();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMessage)));
      }
    });

    final isLoading = registerState.status.isLoading;
    final passwordVisible = useState(false);
    final confirmPasswordVisible = useState(false);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => ref.read(appRouterProvider).go("/"),
        ),
        title: const Text("Admin Kayıt"),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white,
              Color(0xFFFFFFFF),
              Color(0xFF4A6FA5),
              Color(0xFF0B1F3A),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 20),
                      // Logo/Icon Area
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.person_add,
                          size: 64,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        "Admin Kayıt",
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineLarge
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1F2937),
                              letterSpacing: -1,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Yeni admin hesabı oluşturun",
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Form Fields
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: "Ad Soyad",
                          hintText: "ör. Ahmet Yılmaz",
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        textInputAction: TextInputAction.next,
                        textCapitalization: TextCapitalization.words,
                        onChanged: (value) {
                          controller.updateName(value);
                        },
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: emailController,
                        decoration: const InputDecoration(
                          labelText: "E-posta",
                          hintText: "ör. admin@example.com",
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        keyboardType: TextInputType.text,
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        enableSuggestions: false,
                        onChanged: (value) {
                          controller.updateEmail(value);
                        },
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: phoneController,
                        decoration: const InputDecoration(
                          labelText: "Telefon",
                          hintText: "ör. 05551234567",
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        onChanged: (value) {
                          controller.updatePhone(value);
                        },
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: passwordController,
                        decoration: InputDecoration(
                          labelText: "Şifre",
                          hintText: "En az 6 karakter",
                          prefixIcon: const Icon(Icons.lock_outline),
                          errorText: registerState.passwordError,
                          suffixIcon: IconButton(
                            icon: Icon(
                              passwordVisible.value
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () {
                              passwordVisible.value = !passwordVisible.value;
                            },
                          ),
                        ),
                        obscureText: !passwordVisible.value,
                        textInputAction: TextInputAction.next,
                        onChanged: (value) {
                          controller.updatePassword(value);
                        },
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: confirmPasswordController,
                        decoration: InputDecoration(
                          labelText: "Şifre Tekrar",
                          hintText: "Şifrenizi tekrar girin",
                          prefixIcon: const Icon(Icons.lock_outline),
                          errorText: registerState.confirmPasswordError,
                          suffixIcon: IconButton(
                            icon: Icon(
                              confirmPasswordVisible.value
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () {
                              confirmPasswordVisible.value =
                                  !confirmPasswordVisible.value;
                            },
                          ),
                        ),
                        obscureText: !confirmPasswordVisible.value,
                        textInputAction: TextInputAction.done,
                        onChanged: (value) {
                          controller.updateConfirmPassword(value);
                        },
                        onSubmitted: (_) {
                          // Update state from controllers before submit
                          controller.updateName(nameController.text);
                          controller.updateEmail(emailController.text);
                          controller.updatePhone(phoneController.text);
                          controller.updatePassword(passwordController.text);
                          controller.updateConfirmPassword(
                            confirmPasswordController.text,
                          );
                          controller.submit();
                        },
                      ),
                      const SizedBox(height: 24),
                      PrimaryButton(
                        label: "Kayıt Ol",
                        onPressed: () {
                          // Update state from controllers before submit
                          controller.updateName(nameController.text);
                          controller.updateEmail(emailController.text);
                          controller.updatePhone(phoneController.text);
                          controller.updatePassword(passwordController.text);
                          controller.updateConfirmPassword(
                            confirmPasswordController.text,
                          );

                          debugPrint("Register button pressed");
                          debugPrint("State isValid: ${registerState.isValid}");
                          debugPrint("Name: ${registerState.name}");
                          debugPrint("Email: ${registerState.email}");
                          debugPrint(
                            "Password: ${registerState.password.length}",
                          );
                          debugPrint(
                            "ConfirmPassword: ${registerState.confirmPassword.length}",
                          );
                          debugPrint("Phone: ${registerState.phone}");

                          controller.submit();
                        },
                        isLoading: isLoading,
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => ref.read(appRouterProvider).go("/"),
                        child: const Text(
                          "Zaten hesabınız var mı? Giriş yapın",
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
