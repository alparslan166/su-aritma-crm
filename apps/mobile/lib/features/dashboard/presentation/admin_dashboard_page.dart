import "package:flutter/material.dart";
import "package:go_router/go_router.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";

import "../../../core/session/session_provider.dart";
import "../../../routing/app_router.dart";
import "../../admin/presentation/views/customers_view.dart";
import "../../admin/presentation/views/inventory_view.dart";
import "../../admin/presentation/views/job_map_view.dart";
import "../../admin/presentation/views/notifications_view.dart";
import "../../admin/presentation/views/operations_view.dart";
import "../../admin/presentation/views/past_jobs_view.dart";
import "../../admin/presentation/views/personnel_view.dart";

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
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          isScrollable: false,
          tabAlignment: TabAlignment.fill,
          dividerColor: Colors.transparent,
          tabs: const [
            Tab(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [Text("Tüm"), Text("Müşteriler")],
              ),
            ),
            Tab(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [Text("Ödemesi"), Text("Gelen")],
              ),
            ),
            Tab(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [Text("Bakımı"), Text("Gelen")],
              ),
            ),
          ],
        ),
      ),
      drawer: _AdminDrawer(),
      body: TabBarView(
        controller: _tabController,
        children: const [
          CustomersView(filterType: CustomerFilterType.all),
          CustomersView(filterType: CustomerFilterType.overduePayment),
          CustomersView(filterType: CustomerFilterType.upcomingMaintenance),
        ],
      ),
    );
  }
}

class _AdminDrawer extends ConsumerWidget {
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
          ListTile(
            leading: const Icon(Icons.build),
            title: const Text("Operasyonlar"),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const OperationsView()));
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text("Çıkış Yap", style: TextStyle(color: Colors.red)),
            onTap: () async {
              // Drawer'ı kapat
              Navigator.pop(context);

              // Drawer kapandıktan sonra dialog'u aç
              await Future.microtask(() async {
                if (!context.mounted) return;

                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text("Çıkış Yap"),
                    content: const Text(
                      "Çıkış yapmak istediğinize emin misiniz?",
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                        child: const Text("İptal"),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
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
              });
            },
          ),
        ],
      ),
    );
  }
}
