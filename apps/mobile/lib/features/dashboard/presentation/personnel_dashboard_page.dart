import "package:flutter/material.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";

import "../../../core/session/session_provider.dart";
import "../../../routing/app_router.dart";
import "../../admin/presentation/views/add_customer_sheet.dart";
import "../../personnel/presentation/views/notifications_view.dart";
import "../../personnel/presentation/views/personnel_jobs_page.dart";
import "../../personnel/presentation/views/personnel_profile_page.dart";

class PersonnelDashboardPage extends ConsumerWidget {
  const PersonnelDashboardPage({super.key});

  static const routeName = "personnel-dashboard";

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => _showMenu(context, ref),
            ),
          ),
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

  void _showMenu(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person, color: Color(0xFF10B981)),
              title: const Text("Profil"),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const PersonnelProfilePage(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_add, color: Color(0xFF2563EB)),
              title: const Text("Müşteri Ekle"),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AddCustomerSheet(),
                  ),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text("Çıkış Yap"),
              onTap: () {
                Navigator.of(context).pop();
                _handleLogout(context, ref);
              },
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
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
