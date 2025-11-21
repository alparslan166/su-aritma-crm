import "package:flutter/material.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";

import "../../../core/session/session_provider.dart";
import "../../../routing/app_router.dart";
import "../../personnel/presentation/views/notifications_view.dart";
import "../../personnel/presentation/views/personnel_jobs_page.dart";

class PersonnelDashboardPage extends ConsumerWidget {
  const PersonnelDashboardPage({super.key});

  static const routeName = "personnel-dashboard";

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.person_outline,
                  color: Color(0xFF10B981),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text("Personel Paneli"),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.red),
              tooltip: "Çıkış Yap",
              onPressed: () => _handleLogout(context, ref),
            ),
          ],
          bottom: TabBar(
            labelColor: const Color(0xFF10B981),
            unselectedLabelColor: Colors.grey.shade600,
            indicatorColor: const Color(0xFF10B981),
            indicatorWeight: 3,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            tabs: const [
              Tab(icon: Icon(Icons.work_outline, size: 20), text: "İşlerim"),
              Tab(
                icon: Icon(Icons.notifications_outlined, size: 20),
                text: "Bildirimler",
              ),
            ],
          ),
        ),
        body: const TabBarView(
          children: [PersonnelJobsPage(), PersonnelNotificationsView()],
        ),
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Çıkış Yap"),
        content: const Text("Çıkış yapmak istediğinize emin misiniz?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text("İptal"),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Çıkış Yap"),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      // Oturumu sil
      ref.read(authSessionProvider.notifier).state = null;

      // Login'e git (redirect mekanizması otomatik çalışacak)
      ref.read(appRouterProvider).go("/");
    }
  }
}
