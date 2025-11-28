import "package:flutter/material.dart";
import "package:go_router/go_router.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";

import "../../../core/session/session_provider.dart";
import "../../../routing/app_router.dart";
import "../../admin/presentation/views/admin_profile_page.dart";
import "../../admin/presentation/views/assign_job_sheet.dart";
import "../../admin/presentation/views/customers_view.dart";
import "../../admin/presentation/views/inventory_view.dart";
import "../../admin/presentation/views/job_map_view.dart";
import "../../admin/presentation/views/notifications_view.dart";
import "../../admin/presentation/views/past_jobs_view.dart";
import "../../admin/presentation/views/personnel_view.dart";
import "home_page_tab.dart";

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  static const routeName = "admin-dashboard";

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    // Ekran genişliğine göre font boyutunu hesapla (5 tab için)
    final tabWidth = screenWidth / 5;
    // Minimum 8px padding, maksimum font boyutu 12
    final fontSize = (tabWidth - 16) / 6;
    final responsiveFontSize = fontSize.clamp(8.0, 12.0);

    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Row(
          children: [
            GestureDetector(
              onTap: () => context.goNamed(AdminDashboardPage.routeName),
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
            const SizedBox(width: 12),
            const Text("Admin Paneli"),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF2563EB),
          unselectedLabelColor: Colors.grey.shade600,
          indicatorColor: const Color(0xFF2563EB),
          indicatorWeight: 3,
          labelStyle: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: responsiveFontSize,
          ),
          unselectedLabelStyle: TextStyle(fontSize: responsiveFontSize),
          isScrollable: false,
          tabAlignment: TabAlignment.fill,
          dividerColor: Colors.transparent,
          labelPadding: EdgeInsets.symmetric(
            horizontal: 4,
            vertical: responsiveFontSize < 10 ? 8 : 4,
          ),
          tabs: [
            Tab(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Tüm",
                    style: TextStyle(fontSize: responsiveFontSize),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    "Müşteriler",
                    style: TextStyle(fontSize: responsiveFontSize),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Tab(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Ödemesi",
                    style: TextStyle(fontSize: responsiveFontSize),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    "Gelen",
                    style: TextStyle(fontSize: responsiveFontSize),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Tab(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Ana",
                    style: TextStyle(fontSize: responsiveFontSize),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    "Sayfa",
                    style: TextStyle(fontSize: responsiveFontSize),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Tab(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Bakımı",
                    style: TextStyle(fontSize: responsiveFontSize),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    "Gelen",
                    style: TextStyle(fontSize: responsiveFontSize),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Tab(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "İş",
                    style: TextStyle(fontSize: responsiveFontSize),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    "Atama",
                    style: TextStyle(fontSize: responsiveFontSize),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      drawer: _AdminDrawer(),
      body: TabBarView(
        controller: _tabController,
        children: [
          const CustomersView(filterType: CustomerFilterType.all),
          const CustomersView(filterType: CustomerFilterType.overduePayment),
          const HomePageTab(),
          const CustomersView(
            filterType: CustomerFilterType.upcomingMaintenance,
          ),
          _AssignJobTab(),
        ],
      ),
    );
  }
}

class _AssignJobTab extends StatelessWidget {
  const _AssignJobTab();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            iconSize: 64,
            icon: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, color: Color(0xFF2563EB), size: 48),
            ),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AssignJobSheet(),
                  fullscreenDialog: true,
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          const Text(
            "İş Ata",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            "Yeni iş atamak için tıklayın",
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _AdminDrawer extends ConsumerWidget {
  const _AdminDrawer();

  void _performLogout(BuildContext context, WidgetRef ref) {
    debugPrint("🔴 LOGOUT BUTONU TIKLANDI!");

    // Drawer'ı hemen kapat
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Color(0xFF2563EB)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(Icons.admin_panel_settings, color: Colors.white, size: 48),
                SizedBox(height: 8),
                Text(
                  "Admin Paneli",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.people),
            title: const Text("Personeller"),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const PersonnelView()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.inventory_2),
            title: const Text("Stok Durumu"),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const InventoryView()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text("Geçmiş"),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const PastJobsView()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.map),
            title: const Text("Harita"),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const JobMapView()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.notifications),
            title: const Text("Bildirim"),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NotificationsView()),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text("Profil"),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AdminProfilePage()),
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              color: Colors.red.withOpacity(0.1),
              child: Row(
                children: [
                  const Icon(Icons.logout, color: Colors.red, size: 24),
                  const SizedBox(width: 16),
                  const Text(
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
        ],
      ),
    );
  }
}
