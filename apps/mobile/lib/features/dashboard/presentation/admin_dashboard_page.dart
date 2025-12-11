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
import "../../admin/presentation/views/jobs_view.dart";
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
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _homeIconAnimationController;
  late Animation<double> _homeIconBounceAnimation;
  late List<AnimationController> _tabTextAnimationControllers;
  late List<Animation<double>> _tabTextScaleAnimations;
  int _previousTabIndex = -1; // Önceki tab index'ini takip et

  @override
  void initState() {
    super.initState();
    // Ana Sayfa tab'ı index 2'de, ilk girişte ana sayfadan başla
    _tabController = TabController(length: 5, vsync: this, initialIndex: 2);
    _previousTabIndex = 2; // İlk index'i kaydet

    // Home icon bounce animasyonu için controller
    _homeIconAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // Yukarı-aşağı hareket animasyonu (0 -> -8 -> 0)
    _homeIconBounceAnimation = Tween<double>(begin: 0.0, end: -8.0).animate(
      CurvedAnimation(
        parent: _homeIconAnimationController,
        curve: Curves.easeOut,
      ),
    );

    // Tab text scale animasyonları için controller'lar
    _tabTextAnimationControllers = List.generate(
      5,
      (index) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 200),
      ),
    );

    // Her tab için scale animasyonu (1.0 -> 1.2 -> 1.0)
    _tabTextScaleAnimations = _tabTextAnimationControllers.map((controller) {
      return Tween<double>(
        begin: 1.0,
        end: 1.2,
      ).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut));
    }).toList();

    // Tab değişikliğini dinle (tüm controller'lar initialize edildikten sonra)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _tabController.addListener(_onTabChanged);

        // İlk yüklemede animasyonu çalıştır (eğer ana sayfa seçiliyse)
        if (_tabController.index == 2) {
          _triggerHomeIconAnimation();
        }
      }
    });
  }

  void _onTabChanged() {
    // Widget dispose edilmişse işlem yapma
    if (!mounted) return;

    final currentIndex = _tabController.index;

    // Seçili tab'ın metnini büyüt-küçült animasyonu
    if (currentIndex != _previousTabIndex &&
        currentIndex < _tabTextAnimationControllers.length) {
      _tabTextAnimationControllers[currentIndex].forward().then((_) {
        if (mounted) {
          _tabTextAnimationControllers[currentIndex].reverse();
        }
      });
    }

    // Sadece farklı bir tab'dan Ana Sayfa'ya (index 2) geçildiğinde animasyonu tetikle
    // Aynı tab'a tekrar basıldığında animasyon çalışmasın
    if (currentIndex == 2 && _previousTabIndex != 2) {
      _triggerHomeIconAnimation();
    }

    // Önceki index'i güncelle
    _previousTabIndex = currentIndex;
  }

  void _triggerHomeIconAnimation() {
    // Widget dispose edilmişse işlem yapma
    if (!mounted) return;

    // Animasyonu sıfırla ve başlat
    _homeIconAnimationController.reset();
    _homeIconAnimationController.forward().then((_) {
      // Widget hala mounted ise reverse yap
      if (mounted) {
        _homeIconAnimationController.reverse();
      }
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _homeIconAnimationController.dispose();
    for (final controller in _tabTextAnimationControllers) {
      controller.dispose();
    }
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
            const Text(
              "Admin Paneli",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF2563EB),
          unselectedLabelColor: Colors.grey.shade600,
          indicatorColor: const Color(0xFF2563EB),
          indicatorWeight: 3,
          labelStyle: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: responsiveFontSize,
            letterSpacing: 0.3,
          ),
          unselectedLabelStyle: TextStyle(
            fontSize: responsiveFontSize,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.2,
          ),
          isScrollable: false,
          tabAlignment: TabAlignment.fill,
          dividerColor: Colors.transparent,
          labelPadding: EdgeInsets.symmetric(
            horizontal: 4,
            vertical: responsiveFontSize < 10 ? 8 : 4,
          ),
          tabs: [
            Tab(
              child: AnimatedBuilder(
                animation: _tabTextScaleAnimations[0],
                builder: (context, child) {
                  return Transform.scale(
                    scale: _tabTextScaleAnimations[0].value,
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
                  );
                },
              ),
            ),
            Tab(
              child: AnimatedBuilder(
                animation: _tabTextScaleAnimations[1],
                builder: (context, child) {
                  return Transform.scale(
                    scale: _tabTextScaleAnimations[1].value,
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
                  );
                },
              ),
            ),
            Tab(
              child: AnimatedBuilder(
                animation: Listenable.merge([
                  _tabController,
                  _homeIconBounceAnimation,
                ]),
                builder: (context, child) {
                  final isSelected = _tabController.index == 2;
                  return Transform.translate(
                    offset: Offset(
                      0,
                      isSelected ? _homeIconBounceAnimation.value : 0,
                    ),
                    child: Icon(
                      Icons.home,
                      color: isSelected
                          ? const Color(0xFF2563EB)
                          : Colors.grey.shade600,
                      size: 40,
                    ),
                  );
                },
              ),
            ),
            Tab(
              child: AnimatedBuilder(
                animation: _tabTextScaleAnimations[3],
                builder: (context, child) {
                  return Transform.scale(
                    scale: _tabTextScaleAnimations[3].value,
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
                  );
                },
              ),
            ),
            Tab(
              child: AnimatedBuilder(
                animation: _tabTextScaleAnimations[4],
                builder: (context, child) {
                  return Transform.scale(
                    scale: _tabTextScaleAnimations[4].value,
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
                  );
                },
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

  Future<void> _performLogout(BuildContext context, WidgetRef ref) async {
    debugPrint("🔴 LOGOUT BUTONU TIKLANDI!");

    // Önce dialog'u göster (drawer açıkken)
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

    // Dialog kapandıktan sonra drawer'ı kapat
    if (context.mounted) {
      Navigator.of(context).pop(); // Drawer'ı kapat
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
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.work, color: Color(0xFF2563EB), size: 24),
            ),
            title: const Text(
              "Aktif İşler",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const JobsView()));
            },
          ),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.people,
                color: Color(0xFF10B981),
                size: 24,
              ),
            ),
            title: const Text(
              "Personeller",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const PersonnelView()));
            },
          ),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.inventory_2,
                color: Color(0xFFF59E0B),
                size: 24,
              ),
            ),
            title: const Text(
              "Stok Durumu",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const InventoryView()));
            },
          ),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.history, color: Colors.grey.shade700, size: 24),
            ),
            title: const Text(
              "Geçmiş",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const PastJobsView()));
            },
          ),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.map, color: Color(0xFFEF4444), size: 24),
            ),
            title: const Text(
              "Harita",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const JobMapView()));
            },
          ),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFCD34D).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.notifications,
                color: Color(0xFFF59E0B),
                size: 24,
              ),
            ),
            title: const Text(
              "Bildirim",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NotificationsView()),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.person,
                color: Color(0xFF7C3AED),
                size: 24,
              ),
            ),
            title: const Text(
              "Profil",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
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
