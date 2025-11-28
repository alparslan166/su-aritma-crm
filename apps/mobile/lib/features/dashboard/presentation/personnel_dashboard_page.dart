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
                  MaterialPageRoute(builder: (_) => const AddCustomerSheet()),
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

    if (confirm != true || !context.mounted) {
      return;
    }

    try {
      debugPrint("🔴 Logout başlatılıyor...");

      // 1. Önce session'ı temizle
      await ref.read(authSessionProvider.notifier).clearSession();
      debugPrint("✅ Session temizlendi");

      // 2. Router'ı invalidate et ki yeniden oluşturulsun
      ref.invalidate(appRouterProvider);
      debugPrint("✅ Router invalidate edildi");

      // 3. Router'ın yeniden oluşturulması için kısa bir süre bekle
      await Future.delayed(const Duration(milliseconds: 100));
      debugPrint("✅ Bekleme tamamlandı");

      // 4. Yeni router instance'ını al ve login sayfasına git
      if (context.mounted) {
        final router = ref.read(appRouterProvider);
        debugPrint(
          "✅ Router instance alındı, login sayfasına yönlendiriliyor...",
        );
        router.go("/");
        debugPrint("✅ Navigation tamamlandı");
      } else {
        debugPrint("⚠️ Context mounted değil");
      }
    } catch (e, stackTrace) {
      debugPrint("❌ Logout error: $e");
      debugPrint("Stack trace: $stackTrace");
      // Hata durumunda da login sayfasına git
      if (context.mounted) {
        try {
          final router = ref.read(appRouterProvider);
          router.go("/");
          debugPrint("✅ Hata durumunda navigation yapıldı");
        } catch (e2) {
          debugPrint("❌ Navigation hatası: $e2");
        }
      }
    }
  }
}
