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
    final isPasswordVisible = useState<bool>(false);
    final savedCredentials = useState<(String?, String?)?>(null);
    final showSuggestion = useState<bool>(false);
    
    // Focus nodes for email and password fields
    final emailFocusNode = useFocusNode();
    final passwordFocusNode = useFocusNode();

    // Load saved credentials for suggestion on mount
    useEffect(() {
      LoginController.getSavedCredentials().then((creds) {
        savedCredentials.value = creds;
      });
      return null;
    }, []);

    // Show suggestion when email or password field is focused
    useEffect(() {
      void onFocusChange() {
        showSuggestion.value = emailFocusNode.hasFocus || passwordFocusNode.hasFocus;
      }
      emailFocusNode.addListener(onFocusChange);
      passwordFocusNode.addListener(onFocusChange);
      return () {
        emailFocusNode.removeListener(onFocusChange);
        passwordFocusNode.removeListener(onFocusChange);
      };
    }, [emailFocusNode, passwordFocusNode]);

    useEffect(() {
      identifierController.text = loginState.identifier;
      secretController.text = loginState.secret;
      adminIdController.text = loginState.adminId;
      return null;
    }, [loginState.role, loginState.identifier, loginState.secret]);

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

      // Only show error if transitioning from loading to error (new error)
      // This prevents showing the same error multiple times
      final nextErrored = nextStatus is AsyncError;
      final prevErrored = prevStatus is AsyncError;
      final wasLoading = prevStatus?.isLoading == true;

      // Show error only if:
      // 1. Current status is error AND
      // 2. Previous status was loading (transitioned from loading to error) OR
      // 3. Previous status was NOT error (new error occurred)
      if (nextErrored && (wasLoading || !prevErrored)) {
        final errorMessage = (nextStatus as AsyncError).error.toString();
        if (context.mounted) {
          // Hide any existing snackbars first
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    });

    final isLoading = loginState.status.isLoading;

    return Scaffold(
      body: Stack(
        children: [
          // Animated wave background
          const _AnimatedWaveBackground(),
          // Content
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 16),
                      // Logo/Icon Area with Animation
                      _AnimatedLogo(),
                      _TypewriterText(
                        text: "www.filtrefix.com",
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: const Color(0xFF1E3A8A),
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                        duration: const Duration(milliseconds: 1500),
                      ),
                      const SizedBox(height: 8),
                      _TypewriterText(
                        text: "Müşteri ve Stok yönetiminin kolaylaştırılmış hali",
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade600,
                          letterSpacing: 0.1,
                        ),
                        duration: const Duration(milliseconds: 1500),
                      ),
                      const SizedBox(height: 32),
                      // Role Selection - Glassmorphism
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.5),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF1E3A8A).withValues(alpha: 0.1),
                              blurRadius: 20,
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: SegmentedButton<AuthRole>(
                          segments: AuthRole.values
                              .map(
                                (role) => ButtonSegment<AuthRole>(
                                  value: role,
                                  label: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    child: Text(
                                      role.label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
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
                                return const Color(0xFF3B82F6).withValues(alpha: 0.15);
                              }
                              return Colors.transparent;
                            }),
                            foregroundColor: WidgetStateProperty.resolveWith((
                              states,
                            ) {
                              if (states.contains(WidgetState.selected)) {
                                return const Color(0xFF1E3A8A);
                              }
                              return const Color(0xFF64748B);
                            }),
                            side: WidgetStateProperty.all(BorderSide.none),
                            shape: WidgetStateProperty.all(
                              RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            elevation: WidgetStateProperty.resolveWith((
                              states,
                            ) {
                              if (states.contains(WidgetState.selected)) {
                                return 4;
                              }
                              return 0;
                            }),
                            shadowColor: WidgetStateProperty.all(
                              const Color(0xFF1E3A8A).withValues(alpha: 0.2),
                            ),
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
                      AutofillGroup(
                        child: Column(
                          children: [
                            // Kayıtlı hesap önerisi - sadece focus varken göster
                            if (showSuggestion.value &&
                                loginState.role == AuthRole.admin &&
                                savedCredentials.value != null &&
                                savedCredentials.value!.$1 != null &&
                                savedCredentials.value!.$1!.isNotEmpty &&
                                loginState.identifier.isEmpty)
                              GestureDetector(
                                onTap: () {
                                  final email = savedCredentials.value!.$1!;
                                  final password = savedCredentials.value!.$2 ?? "";
                                  controller.fillSavedCredentials(email, password);
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2563EB).withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF2563EB).withValues(alpha: 1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(
                                          Icons.key,
                                          color: Color(0xFF2563EB),
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              savedCredentials.value!.$1!,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                                color: Color(0xFF1F2937),
                                              ),
                                            ),
                                            const Text(
                                              "Kayıtlı hesap ile giriş yap",
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Color(0xFF6B7280),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(
                                        Icons.arrow_forward_ios,
                                        size: 16,
                                        color: Color(0xFF2563EB),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            TextField(
                              controller: identifierController,
                              focusNode: emailFocusNode,
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
                              autofillHints: loginState.role == AuthRole.admin
                                  ? const [AutofillHints.email, AutofillHints.username]
                                  : null,
                              onChanged: controller.updateIdentifier,
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: secretController,
                              focusNode: passwordFocusNode,
                              decoration: InputDecoration(
                                labelText: loginState.role.passwordLabel,
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    isPasswordVisible.value
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                  onPressed: () {
                                    isPasswordVisible.value =
                                        !isPasswordVisible.value;
                                  },
                                  tooltip: isPasswordVisible.value
                                      ? "Şifreyi Gizle"
                                      : "Şifreyi Göster",
                                ),
                              ),
                              obscureText: !isPasswordVisible.value,
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
                              autofillHints: loginState.role == AuthRole.admin
                                  ? const [AutofillHints.password]
                                  : null,
                              onChanged: controller.updateSecret,
                              onSubmitted: (_) => controller.submit(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    "Bu cihazda hatırla",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    "Yetkili cihazlarda otomatik giriş",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white60,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: loginState.rememberDevice,
                              onChanged: controller.toggleRemember,
                              activeColor: Colors.white,
                              activeTrackColor: const Color(0xFF22C55E),
                              inactiveThumbColor: Colors.white,
                              inactiveTrackColor: const Color(0xFFEF4444),
                            ),
                          ],
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
                            // Kayıt ol butonu
                            GestureDetector(
                              onTap: () => ref
                                  .read(appRouterProvider)
                                  .goNamed(RegisterPage.routeName),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF93C5FD).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0xFF93C5FD).withValues(alpha: 0.5),
                                    width: 1,
                                  ),
                                  // boxShadow: [
                                  //   BoxShadow(
                                  //     color: const Color(0xFF93C5FD).withValues(alpha: 0.3),
                                  //     blurRadius: 20,
                                  //     spreadRadius: 0,
                                  //   ),
                                  // ],
                                ),
                                child: const Text(
                                  "Kayıt ol",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Şifremi unuttum butonu
                            GestureDetector(
                              onTap: () => ref
                                  .read(appRouterProvider)
                                  .goNamed(ForgotPasswordPage.routeName),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF6B6B).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0xFFFF6B6B).withValues(alpha: 0.5),
                                    width: 1,
                                  ),
                                ),
                                child: const Text(
                                  "Şifremi unuttum",
                                  style: TextStyle(
                                    color: Color(0xFFFF6B6B),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ],
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
          )),
        ],
      ),
    );
  }
}

class _TypewriterText extends StatefulWidget {
  const _TypewriterText({
    required this.text,
    this.style,
    this.duration = const Duration(milliseconds: 1000),
    this.delay = Duration.zero,
  });

  final String text;
  final TextStyle? style;
  final Duration duration;
  final Duration delay;

  @override
  State<_TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<_TypewriterText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<int> _charCount;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _charCount = IntTween(begin: 0, end: widget.text.length).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            _controller.reset();
            _controller.forward();
          }
        });
      }
    });

    Future.delayed(widget.delay, () {
      if (mounted) {
        _started = true;
        _controller.forward();
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
      animation: _charCount,
      builder: (context, child) {
        final displayText = widget.text.substring(0, _charCount.value);
        return Text(
          displayText,
          textAlign: TextAlign.center,
          style: widget.style,
        );
      },
    );
  }
}

class _AnimatedWaveBackground extends StatefulWidget {
  const _AnimatedWaveBackground();

  @override
  State<_AnimatedWaveBackground> createState() => _AnimatedWaveBackgroundState();
}

class _AnimatedWaveBackgroundState extends State<_AnimatedWaveBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat();
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
        return Container(
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
          child: CustomPaint(
            painter: _WavePainter(_controller.value),
            size: Size.infinite,
          ),
        );
      },
    );
  }
}

class _WavePainter extends CustomPainter {
  final double animationValue;

  _WavePainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF3B82F6).withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;

    final paint2 = Paint()
      ..color = const Color(0xFF1E3A8A).withValues(alpha: 0.06)
      ..style = PaintingStyle.fill;

    // First wave
    final path1 = Path();
    path1.moveTo(0, size.height * 0.7);
    
    for (double i = 0; i <= size.width; i++) {
      path1.lineTo(
        i,
        size.height * 0.7 +
            math.sin((i / size.width * 2 * math.pi) + (animationValue * 2 * math.pi)) * 20 +
            math.sin((i / size.width * 4 * math.pi) + (animationValue * 2 * math.pi * 1.5)) * 10,
      );
    }
    path1.lineTo(size.width, size.height);
    path1.lineTo(0, size.height);
    path1.close();
    canvas.drawPath(path1, paint);

    // Second wave
    final path2 = Path();
    path2.moveTo(0, size.height * 0.75);
    
    for (double i = 0; i <= size.width; i++) {
      path2.lineTo(
        i,
        size.height * 0.75 +
            math.sin((i / size.width * 2 * math.pi) + (animationValue * 2 * math.pi) + math.pi) * 15 +
            math.sin((i / size.width * 3 * math.pi) + (animationValue * 2 * math.pi * 0.8)) * 8,
      );
    }
    path2.lineTo(size.width, size.height);
    path2.lineTo(0, size.height);
    path2.close();
    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
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
            child: Image.asset(
              'assets/images/logo.png',
              width: 180,
              height: 180,
            ),
          ),
        );
      },
    );
  }
}
