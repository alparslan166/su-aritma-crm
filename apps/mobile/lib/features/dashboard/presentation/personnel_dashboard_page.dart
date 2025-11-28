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
            InkWell(
              onTap: () {
                debugPrint("🔴 ÇIKIŞ YAP BUTONU TIKLANDI!");
                _performLogout(context, ref);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                color: Colors.red.withOpacity(0.1),
                child: const Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red, size: 24),
                    SizedBox(width: 16),
                    Text(
                      "Çıkış Yap",
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  void _performLogout(BuildContext context, WidgetRef ref) {
    debugPrint("🔴 LOGOUT BUTONU TIKLANDI!");

    // Bottom sheet'i hemen kapat
    Navigator.of(context).pop();

    // Kısa bir delay sonra logout işlemini başlat
    Future.delayed(const Duration(milliseconds: 100), () async {
      try {
        debugPrint("🔴 Logout işlemi başlatılıyor...");

        // Session'ı temizle
        await ref.read(authSessionProvider.notifier).clearSession();
        debugPrint("✅ Session temizlendi");

        // Router'ı invalidate et
        ref.invalidate(appRouterProvider);
        debugPrint("✅ Router invalidate edildi");

        // Router'ın yeniden oluşturulmasını bekle
        await Future.delayed(const Duration(milliseconds: 150));

        // Login sayfasına git
        if (context.mounted) {
          final router = ref.read(appRouterProvider);
          debugPrint("✅ Router alındı, login sayfasına gidiliyor...");
          router.go("/");
          debugPrint("✅ Navigation tamamlandı!");
        }
      } catch (e, stackTrace) {
        debugPrint("❌ Logout hatası: $e");
        debugPrint("Stack: $stackTrace");

        // Hata durumunda da login sayfasına git
        if (context.mounted) {
          try {
            final router = ref.read(appRouterProvider);
            router.go("/");
          } catch (e2) {
            debugPrint("❌ Navigation hatası: $e2");
          }
        }
      }
    });
  }
}
