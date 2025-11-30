import "dart:async";

import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_hooks/flutter_hooks.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";

import "../../../core/session/session_provider.dart";
import "../../../routing/app_router.dart";
import "../../../widgets/primary_button.dart";
import "../../dashboard/presentation/admin_dashboard_page.dart";
import "../application/auth_service.dart";

class EmailVerificationPage extends HookConsumerWidget {
  const EmailVerificationPage({
    required this.email,
    required this.name,
    required this.password,
    super.key,
  });

  final String email;
  final String name;
  final String password;

  static const routeName = "email-verification";

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authService = ref.watch(authServiceProvider);
    final isLoading = useState(false);
    final isResending = useState(false);
    final errorMessage = useState<String?>(null);
    final codeController = useTextEditingController();
    final resendCountdown = useState(0);

    // Countdown timer for resend button
    useEffect(() {
      if (resendCountdown.value > 0) {
        final timer = Timer(const Duration(seconds: 1), () {
          resendCountdown.value--;
        });
        return timer.cancel;
      }
      return null;
    }, [resendCountdown.value]);

    Future<void> verifyCode() async {
      if (codeController.text.length != 6) {
        errorMessage.value = "Lütfen 6 haneli kodu giriniz";
        return;
      }

      isLoading.value = true;
      errorMessage.value = null;

      try {
        final result = await authService.verifyEmail(
          email,
          codeController.text.trim(),
        );

        // Auto-login after verification
        await ref
            .read(authSessionProvider.notifier)
            .setSession(
              AuthSession(role: result.role, identifier: result.identifier),
              remember: true,
            );

        if (context.mounted) {
          ref.read(appRouterProvider).goNamed(AdminDashboardPage.routeName);
        }
      } on AuthException catch (e) {
        errorMessage.value = e.message;
      } finally {
        isLoading.value = false;
      }
    }

    Future<void> resendCode() async {
      isResending.value = true;
      errorMessage.value = null;

      try {
        await authService.sendVerificationCode(email);
        resendCountdown.value = 60; // 60 seconds cooldown
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Doğrulama kodu tekrar gönderildi"),
              backgroundColor: Colors.green,
            ),
          );
        }
      } on AuthException catch (e) {
        errorMessage.value = e.message;
      } finally {
        isResending.value = false;
      }
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => ref.read(appRouterProvider).go("/"),
        ),
        title: const Text("E-posta Doğrulama"),
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
                      // Icon
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.mark_email_read_outlined,
                          size: 64,
                          color: Color(0xFF10B981),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        "E-postanızı Doğrulayın",
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1F2937),
                            ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "Aşağıdaki adrese 6 haneli bir doğrulama kodu gönderdik:",
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        email,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF2563EB),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Code input
                      TextField(
                        controller: codeController,
                        decoration: InputDecoration(
                          labelText: "Doğrulama Kodu",
                          hintText: "6 haneli kod",
                          prefixIcon: const Icon(Icons.pin_outlined),
                          errorText: errorMessage.value,
                        ),
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 24,
                          letterSpacing: 8,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLength: 6,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onSubmitted: (_) => verifyCode(),
                      ),
                      const SizedBox(height: 24),

                      // Verify button
                      PrimaryButton(
                        label: "Doğrula",
                        onPressed: verifyCode,
                        isLoading: isLoading.value,
                      ),
                      const SizedBox(height: 16),

                      // Resend code
                      Center(
                        child: resendCountdown.value > 0
                            ? Text(
                                "Tekrar gönder (${resendCountdown.value}s)",
                                style: TextStyle(color: Colors.grey.shade500),
                              )
                            : TextButton(
                                onPressed: isResending.value
                                    ? null
                                    : resendCode,
                                child: isResending.value
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text("Kodu tekrar gönder"),
                              ),
                      ),
                      const SizedBox(height: 32),

                      // Info box
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.shade100),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.blue.shade700,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                "Kod 10 dakika içinde geçerliliğini yitirecektir. Spam klasörünüzü de kontrol edin.",
                                style: TextStyle(
                                  fontSize: 13,
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
