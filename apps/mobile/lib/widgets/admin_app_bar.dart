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
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.water_drop,
                color: Color(0xFF2563EB),
                size: 20,
              ),
            ),
          ),
          if (title != null) ...[
            const SizedBox(width: 12),
            Expanded(child: title!),
          ] else ...[
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                "Alt Admin Paneli",
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ],
      ),
      actions: actions,
    );
  }
}
