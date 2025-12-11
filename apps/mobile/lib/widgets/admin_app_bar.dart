import "package:flutter/material.dart";
import "package:go_router/go_router.dart";

import "../features/dashboard/presentation/admin_dashboard_page.dart";

class AdminAppBar extends StatelessWidget implements PreferredSizeWidget {
  const AdminAppBar({
    super.key,
    this.title,
    this.showBackButton = true,
    this.actions,
  });

  final Widget? title;
  final bool showBackButton;
  final List<Widget>? actions;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  void _goToHome(BuildContext context) {
    context.goNamed(AdminDashboardPage.routeName);
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();

    return AppBar(
      leading: showBackButton && canPop
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).pop(),
            )
          : null,
      title: Row(
        children: [
          GestureDetector(
            onTap: () => _goToHome(context),
            child: _AnimatedLogoButton(),
          ),
          if (title != null) ...[
            const SizedBox(width: 12),
            Expanded(child: title!),
          ] else ...[
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "Alt Admin Paneli",
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.3,
                ),
              ),
            ),
          ],
        ],
      ),
      actions: actions,
    );
  }
}

class _AnimatedLogoButton extends StatefulWidget {
  const _AnimatedLogoButton();

  @override
  State<_AnimatedLogoButton> createState() => _AnimatedLogoButtonState();
}

class _AnimatedLogoButtonState extends State<_AnimatedLogoButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _controller.repeat(reverse: true);
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
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF2563EB).withValues(alpha: 0.15),
                  const Color(0xFF10B981).withValues(alpha: 0.15),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.2),
                  blurRadius: 8,
                  spreadRadius: 0,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.water_drop,
              color: Color(0xFF2563EB),
              size: 22,
            ),
          ),
        );
      },
    );
  }
}
