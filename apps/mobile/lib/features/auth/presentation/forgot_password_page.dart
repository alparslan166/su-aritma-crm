import "dart:async";

import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_hooks/flutter_hooks.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";

import "../../../routing/app_router.dart";
import "../../../widgets/primary_button.dart";
import "../application/auth_service.dart";

class ForgotPasswordPage extends HookConsumerWidget {
  const ForgotPasswordPage({super.key});

  static const routeName = "forgot-password";

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authService = ref.watch(authServiceProvider);
    
    // Step: 0 = email input, 1 = code input, 2 = new password
    final step = useState(0);
    final isLoading = useState(false);
    final errorMessage = useState<String?>(null);
    final successMessage = useState<String?>(null);
    
    final emailController = useTextEditingController();
    final codeController = useTextEditingController();
    final passwordController = useTextEditingController();
    final confirmPasswordController = useTextEditingController();
    
    final resendCountdown = useState(0);
    final passwordVisible = useState(false);

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

    Future<void> sendResetCode() async {
      final email = emailController.text.trim();
      if (email.isEmpty || !email.contains("@")) {
        errorMessage.value = "Geçerli bir e-posta adresi giriniz";
        return;
      }

      isLoading.value = true;
      errorMessage.value = null;

      try {
        await authService.forgotPassword(email);
        step.value = 1;
        resendCountdown.value = 60;
        successMessage.value = "Şifre sıfırlama kodu gönderildi";
      } on AuthException catch (e) {
        errorMessage.value = e.message;
      } finally {
        isLoading.value = false;
      }
    }

    Future<void> verifyCode() async {
      final code = codeController.text.trim();
      if (code.length != 6) {
        errorMessage.value = "Lütfen 6 haneli kodu giriniz";
        return;
      }

      // Move to password step
      step.value = 2;
      errorMessage.value = null;
    }

    Future<void> resetPassword() async {
      final password = passwordController.text;
      final confirmPassword = confirmPasswordController.text;

      if (password.length < 6) {
        errorMessage.value = "Şifre en az 6 karakter olmalıdır";
        return;
      }

      if (password != confirmPassword) {
        errorMessage.value = "Şifreler eşleşmiyor";
        return;
      }

      isLoading.value = true;
      errorMessage.value = null;

      try {
        await authService.resetPassword(
          emailController.text.trim(),
          codeController.text.trim(),
          password,
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Şifreniz başarıyla değiştirildi"),
              backgroundColor: Colors.green,
            ),
          );
          ref.read(appRouterProvider).go("/");
        }
      } on AuthException catch (e) {
        errorMessage.value = e.message;
        // If code is invalid, go back to code step
        if (e.message.contains("kod")) {
          step.value = 1;
        }
      } finally {
        isLoading.value = false;
      }
    }

    Future<void> resendCode() async {
      isLoading.value = true;
      errorMessage.value = null;

      try {
        await authService.forgotPassword(emailController.text.trim());
        resendCountdown.value = 60;
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Kod tekrar gönderildi"),
              backgroundColor: Colors.green,
            ),
          );
        }
      } on AuthException catch (e) {
        errorMessage.value = e.message;
      } finally {
        isLoading.value = false;
      }
    }

    Widget buildStepContent() {
      switch (step.value) {
        case 0:
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "E-posta Adresinizi Girin",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "Kayıtlı e-posta adresinize şifre sıfırlama kodu göndereceğiz.",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  labelText: "E-posta",
                  hintText: "ör. admin@example.com",
                  prefixIcon: const Icon(Icons.email_outlined),
                  errorText: errorMessage.value,
                ),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => sendResetCode(),
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: "Kod Gönder",
                onPressed: sendResetCode,
                isLoading: isLoading.value,
              ),
            ],
          );

        case 1:
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "Doğrulama Kodu",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "Aşağıdaki adrese gönderilen 6 haneli kodu girin:",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                emailController.text,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF2563EB),
                ),
              ),
              const SizedBox(height: 32),
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
              PrimaryButton(
                label: "Devam Et",
                onPressed: verifyCode,
                isLoading: isLoading.value,
              ),
              const SizedBox(height: 16),
              Center(
                child: resendCountdown.value > 0
                    ? Text(
                        "Tekrar gönder (${resendCountdown.value}s)",
                        style: TextStyle(color: Colors.grey.shade500),
                      )
                    : TextButton(
                        onPressed: isLoading.value ? null : resendCode,
                        child: const Text("Kodu tekrar gönder"),
                      ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  step.value = 0;
                  errorMessage.value = null;
                },
                child: const Text("← E-postayı değiştir"),
              ),
            ],
          );

        case 2:
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "Yeni Şifre Belirleyin",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "Hesabınız için yeni bir şifre oluşturun.",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: passwordController,
                decoration: InputDecoration(
                  labelText: "Yeni Şifre",
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
                  errorText: errorMessage.value,
                ),
                obscureText: !passwordVisible.value,
                textInputAction: TextInputAction.next,
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
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => resetPassword(),
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: "Şifreyi Değiştir",
                onPressed: resetPassword,
                isLoading: isLoading.value,
              ),
            ],
          );

        default:
          return const SizedBox.shrink();
      }
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => ref.read(appRouterProvider).go("/"),
        ),
        title: const Text("Şifremi Unuttum"),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFDC2626).withValues(alpha: 0.05),
              const Color(0xFFF59E0B).withValues(alpha: 0.05),
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
                          color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          step.value == 2
                              ? Icons.lock_reset
                              : Icons.password_outlined,
                          size: 64,
                          color: const Color(0xFFDC2626),
                        ),
                      ),
                      const SizedBox(height: 32),
                      
                      // Step indicator
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (int i = 0; i < 3; i++) ...[
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: step.value >= i
                                    ? const Color(0xFF2563EB)
                                    : Colors.grey.shade300,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  "${i + 1}",
                                  style: TextStyle(
                                    color: step.value >= i
                                        ? Colors.white
                                        : Colors.grey.shade600,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            if (i < 2)
                              Container(
                                width: 40,
                                height: 2,
                                color: step.value > i
                                    ? const Color(0xFF2563EB)
                                    : Colors.grey.shade300,
                              ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 32),

                      // Dynamic content based on step
                      buildStepContent(),
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

