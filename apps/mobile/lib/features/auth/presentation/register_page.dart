import "package:flutter/material.dart";
import "package:flutter_hooks/flutter_hooks.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";

import "../../../core/session/session_provider.dart";
import "../../../routing/app_router.dart";
import "../../../widgets/primary_button.dart";
import "../../dashboard/presentation/admin_dashboard_page.dart";
import "../application/auth_service.dart";
import "../application/register_controller.dart";

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
          prevStatus?.isLoading == true && nextStatus is AsyncData<AuthResult?>;
      if (transitionedFromLoading) {
        final result = nextStatus.value;
        if (result != null) {
          ref.read(authSessionProvider.notifier).state = AuthSession(
            role: result.role,
            identifier: result.identifier,
          );
          ref.read(appRouterProvider).goNamed(AdminDashboardPage.routeName);
          return;
        }
      }

      final errored = nextStatus is AsyncError;
      if (errored && prevStatus?.isLoading == true) {
        final errorMessage = nextStatus.error.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
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
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF2563EB).withValues(alpha: 0.05),
              const Color(0xFF10B981).withValues(alpha: 0.05),
              Colors.white,
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
                        style: Theme.of(context).textTheme.headlineLarge?.copyWith(
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
                      // Role Selection
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: SegmentedButton<String>(
                          segments: const [
                            ButtonSegment<String>(
                              value: "ALT",
                              label: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  "Alt Admin",
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                            ButtonSegment<String>(
                              value: "ANA",
                              label: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  "Ana Admin",
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                          ],
                          selected: {registerState.role},
                          onSelectionChanged: (selection) {
                            controller.updateRole(selection.first);
                          },
                          style: ButtonStyle(
                            backgroundColor: WidgetStateProperty.resolveWith((states) {
                              if (states.contains(WidgetState.selected)) {
                                return Colors.white;
                              }
                              return Colors.transparent;
                            }),
                            foregroundColor: WidgetStateProperty.resolveWith((states) {
                              if (states.contains(WidgetState.selected)) {
                                return const Color(0xFF2563EB);
                              }
                              return Colors.grey.shade600;
                            }),
                            shape: WidgetStateProperty.all(
                              RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            elevation: WidgetStateProperty.resolveWith((states) {
                              if (states.contains(WidgetState.selected)) {
                                return 2;
                              }
                              return 0;
                            }),
                          ),
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
                        onChanged: controller.updateName,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: emailController,
                        decoration: const InputDecoration(
                          labelText: "E-posta",
                          hintText: "ör. admin@example.com",
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        onChanged: controller.updateEmail,
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
                        onChanged: controller.updatePhone,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: passwordController,
                        decoration: InputDecoration(
                          labelText: "Şifre",
                          hintText: "En az 6 karakter",
                          prefixIcon: const Icon(Icons.lock_outline),
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
                        onChanged: controller.updatePassword,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: confirmPasswordController,
                        decoration: InputDecoration(
                          labelText: "Şifre Tekrar",
                          hintText: "Şifrenizi tekrar girin",
                          prefixIcon: const Icon(Icons.lock_outline),
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
                        onChanged: controller.updateConfirmPassword,
                        onSubmitted: (_) => controller.submit(),
                      ),
                      const SizedBox(height: 24),
                      PrimaryButton(
                        label: "Kayıt Ol",
                        onPressed: () => controller.submit(),
                        isLoading: isLoading,
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => ref.read(appRouterProvider).go("/"),
                        child: const Text("Zaten hesabınız var mı? Giriş yapın"),
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

