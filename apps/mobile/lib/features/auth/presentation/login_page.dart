import "dart:math" as math;

import "package:flutter/material.dart";
import "package:flutter/services.dart";
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
import "forgot_password_page.dart";
import "register_page.dart";

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
    final adminIdController = useTextEditingController(
      text: loginState.adminId,
    );

    useEffect(() {
      identifierController.text = loginState.identifier;
      secretController.text = loginState.secret;
      adminIdController.text = loginState.adminId;
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
          final remember = next.rememberDevice;
          // Async işlemi Future olarak başlat
          ref
              .read(authSessionProvider.notifier)
              .setSession(
                AuthSession(role: result.role, identifier: result.identifier),
                remember: remember,
              )
              .then((_) {
                final target = result.role == AuthRole.admin
                    ? AdminDashboardPage.routeName
                    : PersonnelDashboardPage.routeName;
                ref.read(appRouterProvider).goNamed(target);
              });
          return;
        }
      }

      final errored = nextStatus is AsyncError;
      if (errored) {
        final errorMessage = nextStatus.error.toString();
        // Show error message for both loading errors and validation errors
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
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
                      // Logo/Icon Area with Animation
                      _AnimatedLogo(),
                      const SizedBox(height: 20),
                      _AnimatedTitleText(),
                      const SizedBox(height: 8),
                      Text(
                        "Rolünü seç ve güvenli giriş yap",
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.grey.shade600,
                          letterSpacing: 0.2,
                          height: 1.4,
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
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    child: Text(
                                      role.label,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
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
                            backgroundColor: WidgetStateProperty.resolveWith((
                              states,
                            ) {
                              if (states.contains(WidgetState.selected)) {
                                return Colors.white;
                              }
                              return Colors.transparent;
                            }),
                            foregroundColor: WidgetStateProperty.resolveWith((
                              states,
                            ) {
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
                            elevation: WidgetStateProperty.resolveWith((
                              states,
                            ) {
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
                      // Admin ID field (only for personnel)
                      if (loginState.role == AuthRole.personnel) ...[
                        TextField(
                          controller: adminIdController,
                          decoration: const InputDecoration(
                            labelText: "Admin ID",
                            hintText: "ör. ABC12345",
                            prefixIcon: Icon(
                              Icons.admin_panel_settings_outlined,
                            ),
                          ),
                          keyboardType: TextInputType.text,
                          textInputAction: TextInputAction.next,
                          autocorrect: false,
                          enableSuggestions: false,
                          textCapitalization: TextCapitalization.characters,
                          onChanged: controller.updateAdminId,
                        ),
                        const SizedBox(height: 16),
                      ],
                      TextField(
                        controller: identifierController,
                        decoration: InputDecoration(
                          labelText: loginState.role == AuthRole.admin
                              ? "E-posta"
                              : loginState.role.identifierLabel,
                          hintText: loginState.role == AuthRole.admin
                              ? "ör. admin@example.com"
                              : "ör. PRS-2025-11",
                          prefixIcon: Icon(
                            loginState.role == AuthRole.admin
                                ? Icons.email_outlined
                                : Icons.person_outline,
                          ),
                        ),
                        keyboardType: loginState.role == AuthRole.admin
                            ? TextInputType.emailAddress
                            : TextInputType.text,
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        enableSuggestions: false,
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
                        keyboardType: loginState.role == AuthRole.admin
                            ? TextInputType.visiblePassword
                            : TextInputType.text,
                        inputFormatters: loginState.role == AuthRole.personnel
                            ? [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[a-zA-Z0-9]'),
                                ),
                              ]
                            : null,
                        textCapitalization: TextCapitalization.none,
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
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
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
                      if (loginState.role == AuthRole.admin) ...[
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextButton(
                              onPressed: () => ref
                                  .read(appRouterProvider)
                                  .goNamed(RegisterPage.routeName),
                              child: const Text("Hesabınız yok mu? Kayıt olun"),
                            ),
                          ],
                        ),
                        TextButton(
                          onPressed: () => ref
                              .read(appRouterProvider)
                              .goNamed(ForgotPasswordPage.routeName),
                          child: Text(
                            "Şifremi unuttum",
                            style: TextStyle(color: Colors.red.shade600),
                          ),
                        ),
                      ],
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
                            Icon(
                              Icons.info_outline,
                              color: Colors.blue.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                loginState.role == AuthRole.admin
                                    ? "Adminler e-posta ve şifre ile giriş yapar. Hesabınız yoksa kayıt olabilirsiniz."
                                    : "Personeller Admin ID, Personel ID ve 6 haneli kodu kullanır.",
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

class _AnimatedLogo extends StatefulWidget {
  const _AnimatedLogo();

  @override
  State<_AnimatedLogo> createState() => _AnimatedLogoState();
}

class _AnimatedLogoState extends State<_AnimatedLogo>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );

    _rotationAnimation = Tween<double>(begin: 0.0, end: 2 * math.pi).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.8, curve: Curves.easeInOut),
      ),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
      ),
    );

    _controller.forward();

    // Pulse animation
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _controller.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF2563EB).withValues(alpha: 0.15),
                    const Color(0xFF10B981).withValues(alpha: 0.15),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                    offset: const Offset(0, 8),
                  ),
                ],
                border: Border.all(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: Container(
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF2563EB).withValues(alpha: 0.1),
                      const Color(0xFF10B981).withValues(alpha: 0.1),
                    ],
                  ),
                ),
                child: Center(
                  child: Transform.rotate(
                    angle: _rotationAnimation.value * 0.1,
                    child: Icon(
                      Icons.water_drop,
                      size: 64,
                      color: const Color(0xFF2563EB),
                      shadows: [
                        Shadow(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.5),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AnimatedTitleText extends StatefulWidget {
  const _AnimatedTitleText();

  @override
  State<_AnimatedTitleText> createState() => _AnimatedTitleTextState();
}

class _AnimatedTitleTextState extends State<_AnimatedTitleText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: -1.0,
      end: 2.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        // Animasyon değerini 0-1 aralığına normalize et
        final normalizedValue = ((_animation.value + 1.0) / 3.0).clamp(0.0, 1.0);
        
        // Işığın genişliği ve pozisyonu
        const lightWidth = 0.4;
        final lightPosition = normalizedValue;
        final lightStart = math.max(0.0, lightPosition - lightWidth / 2);
        final lightEnd = math.min(1.0, lightPosition + lightWidth / 2);
        
        return LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                // Mat siyah yazı (arka plan)
                Text(
                  "Su Arıtma Platformu",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    letterSpacing: -0.5,
                    height: 1.2,
                  ),
                ),
                // Lacivert ışık efekti (üstte)
                Positioned.fill(
                  child: ClipRect(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      widthFactor: lightEnd - lightStart,
                      child: Transform.translate(
                        offset: Offset(constraints.maxWidth * lightStart, 0),
                        child: ShaderMask(
                          shaderCallback: (bounds) {
                            return LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                const Color(0xFF1E3A8A),
                                const Color(0xFF2563EB),
                                const Color(0xFF1E3A8A),
                              ],
                            ).createShader(bounds);
                          },
                          child: Text(
                            "Su Arıtma Platformu",
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: -0.5,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
