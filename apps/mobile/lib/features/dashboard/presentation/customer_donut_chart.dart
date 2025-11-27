import "dart:math" as math;

import "package:flutter/material.dart";
import "package:fl_chart/fl_chart.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";

import "../../admin/presentation/views/admin_profile_page.dart";
import "home_page_provider.dart";

class CustomerDonutChart extends ConsumerStatefulWidget {
  const CustomerDonutChart({super.key});

  @override
  ConsumerState<CustomerDonutChart> createState() => _CustomerDonutChartState();
}

class _CustomerDonutChartState extends ConsumerState<CustomerDonutChart>
    with TickerProviderStateMixin {
  AnimationController? _animationController;
  AnimationController? _rotationController;
  AnimationController? _gradientController;
  AnimationController? _fadeInController;
  Animation<double>? _gradientAnimation;
  Animation<double>? _fadeInAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();

    _rotationController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();

    _gradientController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    // Smooth animasyon için CurvedAnimation ekle
    _gradientAnimation = CurvedAnimation(
      parent: _gradientController!,
      curve: Curves.easeInOut,
    );
    _gradientController!.repeat();

    // Fade-in animasyonu - sadece bir kez çalışacak
    _fadeInController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeInAnimation = CurvedAnimation(
      parent: _fadeInController!,
      curve: Curves.easeIn,
    );
    _fadeInController!.forward(); // Fade-in'i başlat
  }

  @override
  void dispose() {
    _animationController?.dispose();
    _rotationController?.dispose();
    _gradientController?.dispose();
    _fadeInController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Widget mount kontrolü - controller'ların initialize edildiğinden emin ol
    if (!mounted) {
      return const SizedBox.shrink();
    }

    final categoryDataAsync = ref.watch(customerCategoryDataProvider);
    final statsAsync = ref.watch(dashboardStatsProvider);
    final profileAsync = ref.watch(adminProfileProvider);

    return categoryDataAsync.when(
      data: (data) {
        // Değerleri güvenli bir şekilde al
        final overduePayments = data.overduePayments;
        final upcomingMaintenance = data.upcomingMaintenance;
        final maintenanceApproaching = data.maintenanceApproaching;
        final completedLastWeek = data.completedLastWeek;

        // Total hesaplaması - tüm kategorileri içermeli
        final total =
            overduePayments +
            upcomingMaintenance +
            maintenanceApproaching +
            completedLastWeek;

        // Toplam müşteri sayısını al
        final totalCustomers = statsAsync.valueOrNull?.totalCustomers ?? total;

        // Firma adını al
        final companyName = profileAsync.valueOrNull?["companyName"] as String?;
        final displayTitle = (companyName != null && companyName.isNotEmpty)
            ? companyName
            : "Tüm Müşteriler";

        if (total == 0) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(
                    displayTitle,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Henüz veri yok",
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          );
        }

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.grey.shade200, width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: AnimatedBuilder(
                    animation: Listenable.merge(
                      [
                        _animationController,
                        _rotationController,
                        _gradientController,
                        _fadeInController,
                      ].whereType<Listenable>(),
                    ),
                    builder: (context, child) {
                      if (!mounted) {
                        return const SizedBox.shrink(); // Safety check
                      }

                      // Controller'lar initialize edilmediyse boş widget döndür
                      if (_gradientAnimation == null ||
                          _fadeInAnimation == null) {
                        return const SizedBox.shrink();
                      }

                      try {
                        // Smooth animasyon değeri kullan (CurvedAnimation)
                        final animationValue = _gradientAnimation!.value;

                        // Gradient'i soldan sağa kaydır - smooth geçiş için
                        // Daha smooth bir hareket için range'i daralt
                        final smoothOffset =
                            (animationValue * 2.0 - 1.0) *
                            0.9; // -0.9'den 0.9'a kadar

                        return Opacity(
                          opacity: _fadeInAnimation!.value,
                          child: ShaderMask(
                            shaderCallback: (bounds) => LinearGradient(
                              colors: const [
                                Color(0xFF6366F1), // İndigo
                                Color(0xFF818CF8), // Parlak mor-mavi
                                Color(0xFF60A5FA), // Açık mavi (parıltı)
                                Color(0xFF34D399), // Turkuaz (parıltı)
                                Color(0xFF22D3EE), // Cyan (parıltı)
                                Color(0xFF3B82F6), // Orta mavi
                                Color(0xFF6366F1), // İndigo'ya dönüş
                              ],
                              begin: Alignment(smoothOffset - 0.5, -1.0),
                              end: Alignment(smoothOffset + 0.5, 1.0),
                              stops: const [
                                0.0,
                                0.2,
                                0.35,
                                0.5,
                                0.65,
                                0.8,
                                1.0,
                              ],
                            ).createShader(bounds),
                            child: Text(
                              displayTitle,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                                shadows: [
                                  Shadow(
                                    color: const Color(
                                      0xFF2563EB,
                                    ).withOpacity(0.5),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        );
                      } catch (e) {
                        // Controller'lar henüz initialize edilmemişse boş widget döndür
                        return const SizedBox.shrink();
                      }
                    },
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  height: 180,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: Listenable.merge(
                          [
                            _animationController,
                            _rotationController,
                          ].whereType<Listenable>(),
                        ),
                        builder: (context, child) {
                          if (_rotationController == null ||
                              _animationController == null) {
                            return const SizedBox.shrink();
                          }
                          return Transform.rotate(
                            angle: _rotationController!.value * 2 * math.pi,
                            child: PieChart(
                              PieChartData(
                                sectionsSpace: 2,
                                centerSpaceRadius: 55,
                                sections: _buildSections(
                                  overduePayments,
                                  upcomingMaintenance,
                                  maintenanceApproaching,
                                  completedLastWeek,
                                  total,
                                  _animationController!.value,
                                ),
                                pieTouchData: PieTouchData(enabled: false),
                              ),
                            ),
                          );
                        },
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "$totalCustomers",
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade900,
                            ),
                          ),
                          Text(
                            "Müşteri",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                _buildLegend(
                  overduePayments,
                  upcomingMaintenance,
                  maintenanceApproaching,
                  completedLastWeek,
                ),
              ],
            ),
          ),
        );
      },
      loading: () => Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(
                width: 200,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(height: 24),
              ...List.generate(
                3,
                (index) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 120,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      error: (error, stack) => Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(
                Icons.error_outline,
                color: Color(0xFFEF4444),
                size: 48,
              ),
              const SizedBox(height: 8),
              Text(
                "Veri yüklenirken hata oluştu",
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<PieChartSectionData> _buildSections(
    int overduePayments,
    int upcomingMaintenance,
    int maintenanceApproaching,
    int completedLastWeek,
    int total,
    double animationValue,
  ) {
    final sections = <PieChartSectionData>[];
    final baseRadius = 65.0;
    final animationRange = 8.0;

    // Sinüs fonksiyonu kullanarak yumuşak animasyon
    double getAnimatedRadius(double phase) {
      final offset = (animationValue + phase) % 1.0;
      final sinValue = (math.sin(offset * 2 * math.pi) + 1) / 2; // 0-1 arası
      return baseRadius + (sinValue * animationRange);
    }

    // Ödemesi Gelenler - Kırmızı
    if (overduePayments > 0) {
      sections.add(
        PieChartSectionData(
          value: overduePayments.toDouble(),
          color: const Color(0xFFEF4444),
          radius: getAnimatedRadius(0.0),
          showTitle: false,
        ),
      );
    }

    // Bakımı Gelenler (30 gün içinde) - Turuncu
    if (upcomingMaintenance > 0) {
      sections.add(
        PieChartSectionData(
          value: upcomingMaintenance.toDouble(),
          color: const Color(0xFFF59E0B),
          radius: getAnimatedRadius(0.25),
          showTitle: false,
        ),
      );
    }

    // Bakımı Yaklaşanlar (7 gün içinde) - Açık Turuncu/Sarı
    if (maintenanceApproaching > 0) {
      sections.add(
        PieChartSectionData(
          value: maintenanceApproaching.toDouble(),
          color: const Color(0xFFFFC107),
          radius: getAnimatedRadius(0.5),
          showTitle: false,
        ),
      );
    }

    // Son 1 Haftada Tamamlanan İşler - Yeşil
    if (completedLastWeek > 0) {
      sections.add(
        PieChartSectionData(
          value: completedLastWeek.toDouble(),
          color: const Color(0xFF10B981),
          radius: getAnimatedRadius(0.75),
          showTitle: false,
        ),
      );
    }

    return sections;
  }

  Widget _buildLegend(
    int overduePayments,
    int upcomingMaintenance,
    int maintenanceApproaching,
    int completedLastWeek,
  ) {
    final items = <Widget>[];

    if (overduePayments > 0) {
      items.add(
        _LegendItem(
          color: const Color(0xFFEF4444),
          label: "Ödemesi Gelenler",
          count: overduePayments,
        ),
      );
    }

    if (upcomingMaintenance > 0) {
      if (items.isNotEmpty) {
        items.add(const SizedBox(height: 12));
      }
      items.add(
        _LegendItem(
          color: const Color(0xFFF59E0B),
          label: "Bakımı Gelenler",
          count: upcomingMaintenance,
        ),
      );
    }

    if (maintenanceApproaching > 0) {
      if (items.isNotEmpty) {
        items.add(const SizedBox(height: 12));
      }
      items.add(
        _LegendItem(
          color: const Color(0xFFFFC107),
          label: "Bakımı Yaklaşanlar",
          count: maintenanceApproaching,
        ),
      );
    }

    if (completedLastWeek > 0) {
      if (items.isNotEmpty) {
        items.add(const SizedBox(height: 12));
      }
      items.add(
        _LegendItem(
          color: const Color(0xFF10B981),
          label: "Bu Hafta Tamamlanan",
          count: completedLastWeek,
        ),
      );
    }

    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: items,
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
    required this.count,
  });

  final Color color;
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade800,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            "$count",
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
