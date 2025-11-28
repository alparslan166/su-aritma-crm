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

  Future<void> _performLogout(BuildContext context, WidgetRef ref) async {
    debugPrint("🔴 LOGOUT BUTONU TIKLANDI!");

    // Önce dialog'u göster (bottom sheet açıkken)
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Çıkış Yap"),
        content: const Text("Çıkış yapmak istediğinize emin misiniz?"),
        actions: [
          TextButton(
            onPressed: () {
              debugPrint("❌ İptal butonuna tıklandı");
              Navigator.of(dialogContext).pop(false);
            },
            child: const Text("İptal"),
          ),
          FilledButton(
            onPressed: () {
              debugPrint("✅ Çıkış Yap butonuna tıklandı");
              Navigator.of(dialogContext).pop(true);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Çıkış Yap"),
          ),
        ],
      ),
    );

    // Dialog kapandıktan sonra bottom sheet'i kapat
    if (context.mounted) {
      Navigator.of(context).pop(); // Bottom sheet'i kapat
    }

    debugPrint("🔍 Dialog sonucu: $confirm (type: ${confirm.runtimeType})");

    // Onaylanmadıysa işlemi durdur
    if (confirm != true) {
      debugPrint("⚠️ Logout iptal edildi (confirm: $confirm)");
      return;
    }

    try {
      debugPrint("🔴 Logout işlemi başlatılıyor...");

      // Ref'i erken al (widget dispose edilmeden önce)
      final sessionNotifier = ref.read(authSessionProvider.notifier);
      final router = ref.read(appRouterProvider);

      // Session'ı temizle
      await sessionNotifier.clearSession();
      debugPrint("✅ Session temizlendi");

      // Router'ı invalidate et
      ref.invalidate(appRouterProvider);
      debugPrint("✅ Router invalidate edildi");

      // Router'ın yeniden oluşturulmasını bekle
      await Future.delayed(const Duration(milliseconds: 150));

      // Login sayfasına git
      router.go("/");
      debugPrint("✅ Navigation tamamlandı!");
    } catch (e, stackTrace) {
      debugPrint("❌ Logout hatası: $e");
      debugPrint("Stack: $stackTrace");

      // Hata durumunda da login sayfasına git
      try {
        // Yeni router instance al
        final newRouter = ref.read(appRouterProvider);
        newRouter.go("/");
        debugPrint("✅ Hata durumunda navigation yapıldı");
      } catch (e2) {
        debugPrint("❌ Navigation hatası: $e2");
      }
    }
  }
}
