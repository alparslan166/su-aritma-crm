import "dart:async";

import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_hooks/flutter_hooks.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";

import "../../../core/session/session_provider.dart";
import "../../../routing/app_router.dart";
import "../../../widgets/primary_button.dart";
import "../../admin/presentation/views/admin_profile_page.dart";
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
    final isVerified = useState(false);
    final verifiedResult = useState<AuthResult?>(null);

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

        // Show success screen
        verifiedResult.value = result;
        isVerified.value = true;
      } on AuthException catch (e) {
        errorMessage.value = e.message;
        isLoading.value = false;
      }
    }

    Future<void> proceedToDashboard() async {
      if (verifiedResult.value == null) return;

      await ref
          .read(authSessionProvider.notifier)
          .setSession(
            AuthSession(
              role: verifiedResult.value!.role,
              identifier: verifiedResult.value!.identifier,
            ),
            remember: true,
          );

      // Invalidate profile to fetch fresh data with adminId
      ref.invalidate(adminProfileProvider);

      if (context.mounted) {
        ref.read(appRouterProvider).goNamed(AdminDashboardPage.routeName);
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

    // Success screen
    if (isVerified.value) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF10B981).withValues(alpha: 0.1),
                const Color(0xFF10B981).withValues(alpha: 0.05),
                Colors.white,
              ],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Animated success icon
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.elasticOut,
                      builder: (context, value, child) {
                        return Transform.scale(scale: value, child: child);
                      },
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF10B981,
                              ).withValues(alpha: 0.3),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          size: 64,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Success title with animation
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOut,
                      builder: (context, value, child) {
                        return Opacity(
                          opacity: value,
                          child: Transform.translate(
                            offset: Offset(0, 20 * (1 - value)),
                            child: child,
                          ),
                        );
                      },
                      child: Column(
                        children: [
                          Text(
                            "Hoş Geldiniz! 🎉",
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF1F2937),
                                ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            name,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF10B981),
                                ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Success message with animation
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeOut,
                      builder: (context, value, child) {
                        return Opacity(
                          opacity: value,
                          child: Transform.translate(
                            offset: Offset(0, 20 * (1 - value)),
                            child: child,
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.verified_user_rounded,
                              size: 32,
                              color: Colors.green.shade600,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              "E-posta adresiniz başarıyla doğrulandı!",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Artık FiltreFix'in tüm özelliklerini kullanabilirsiniz.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Continue button with animation
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOut,
                      builder: (context, value, child) {
                        return Opacity(
                          opacity: value,
                          child: Transform.translate(
                            offset: Offset(0, 20 * (1 - value)),
                            child: child,
                          ),
                        );
                      },
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: proceedToDashboard,
                          icon: const Icon(Icons.arrow_forward_rounded),
                          label: const Text(
                            "Panele Git",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Verification code input screen
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
