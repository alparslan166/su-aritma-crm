import "package:flutter/material.dart";
import "package:flutter_hooks/flutter_hooks.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";

import "../../../core/session/session_provider.dart";
import "../../../routing/app_router.dart";
import "../../../widgets/primary_button.dart";
import "../../dashboard/presentation/admin_dashboard_page.dart";
import "../../dashboard/presentation/personnel_dashboard_page.dart";
import "../application/auth_service.dart";
import "../application/login_controller.dart";
import "../domain/auth_role.dart";

class LoginPage extends HookConsumerWidget {
  const LoginPage({super.key});

  static const routeName = "login";

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loginState = ref.watch(loginControllerProvider);
    final controller = ref.read(loginControllerProvider.notifier);

    final identifierController = useTextEditingController(
      text: loginState.identifier,
    );
    final secretController = useTextEditingController(text: loginState.secret);

    useEffect(() {
      identifierController.text = loginState.identifier;
      secretController.text = loginState.secret;
      return null;
    }, [loginState.role]);

    ref.listen(loginControllerProvider, (previous, next) {
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
          final target = result.role == AuthRole.admin
              ? AdminDashboardPage.routeName
              : PersonnelDashboardPage.routeName;
          ref.read(appRouterProvider).goNamed(target);
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

    final isLoading = loginState.status.isLoading;

    return Scaffold(
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
                      const SizedBox(height: 40),
                      // Logo/Icon Area
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.water_drop,
                          size: 64,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        "Su Arıtma Platformu",
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1F2937),
                              letterSpacing: -1,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Rolünü seç ve güvenli giriş yap",
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
                        child: SegmentedButton<AuthRole>(
                          segments: AuthRole.values
                              .map(
                                (role) => ButtonSegment<AuthRole>(
                                  value: role,
                                  label: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: Text(
                                      role.label,
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                          selected: {loginState.role},
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
                        controller: identifierController,
                        decoration: InputDecoration(
                          labelText: loginState.role.identifierLabel,
                          hintText: loginState.role == AuthRole.admin
                              ? "ör. ALT-ADM-01"
                              : "ör. PRS-2025-11",
                          prefixIcon: const Icon(Icons.person_outline),
                        ),
                        textInputAction: TextInputAction.next,
                        onChanged: controller.updateIdentifier,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: secretController,
                        decoration: InputDecoration(
                          labelText: loginState.role.passwordLabel,
                          prefixIcon: const Icon(Icons.lock_outline),
                        ),
                        obscureText: true,
                        onChanged: controller.updateSecret,
                        onSubmitted: (_) => controller.submit(),
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: const Text(
                          "Bu cihazda hatırla",
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text(
                          "Yetkili cihazlarda otomatik giriş",
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                        value: loginState.rememberDevice,
                        onChanged: controller.toggleRemember,
                        contentPadding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      const SizedBox(height: 24),
                      PrimaryButton(
                        label: "Giriş Yap",
                        onPressed: () => controller.submit(),
                        isLoading: isLoading,
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                "Adminler ana admin tarafından verilen şifreyi, personeller ise 6 haneli kodu kullanır.",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue.shade900,
                                ),
                              ),
                            ),
                          ],
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
