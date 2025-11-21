import "package:flutter/material.dart";
import "package:flutter_hooks/flutter_hooks.dart";
import "package:go_router/go_router.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:mobile/widgets/empty_state.dart";

import "../../application/customer_list_notifier.dart";
import "../../data/models/customer.dart";
import "add_customer_sheet.dart";

class CustomersView extends HookConsumerWidget {
  const CustomersView({super.key, required this.filterType});

  final CustomerFilterType filterType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(customerListProvider.notifier);
    final previousFilterType = useRef<CustomerFilterType?>(null);
    final searchController = useTextEditingController();
    final searchQuery = useState<String>("");

    // Helper function to apply filters (for filterType changes and clear button)
    void applyFilters(String search) {
      notifier.filter(
        hasOverduePayment: filterType == CustomerFilterType.overduePayment
            ? true
            : null,
        hasUpcomingMaintenance:
            filterType == CustomerFilterType.upcomingMaintenance ? true : null,
        hasOverdueInstallment: null,
        search: search.isEmpty ? null : search,
      );
    }

    // Apply filter when filterType changes
    useEffect(() {
      if (previousFilterType.value != filterType) {
        previousFilterType.value = filterType;
        // Tüm Müşteriler: Filtre yok (tüm müşteriler gösterilir, renk kodlaması yapılır)
        // Ödemesi Gelen: Sadece borcu geçenler
        // Bakımı Gelen: Bakımı yaklaşan veya geçmiş olanlar
        // Taksit geçen müşteriler artık "Ödemesi Gelen" filtresinde gösteriliyor
        applyFilters(searchQuery.value);
      }
      return null;
    }, [filterType]);

    final state = ref.watch(customerListProvider);
    final padding = MediaQuery.of(context).padding.bottom;

    return Stack(
      children: [
        state.when(
          data: (customers) {
            return Column(
              children: [
                // Arama kutusu
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: TextField(
                    controller: searchController,
                    autofocus: false,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: "Müşteri ara...",
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: searchQuery.value.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                searchController.clear();
                                searchQuery.value = "";
                                // Arama temizlendiğinde filtreyi de temizle
                                applyFilters("");
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    onChanged: (value) {
                      // State'i güncelle (UI için - suffixIcon güncellemesi için)
                      searchQuery.value = value;
                      // Anında filtreleme - her karakter yazıldığında çalışır, tıklamaya gerek yok
                      // Direkt notifier'ı çağır, gecikme olmasın
                      notifier.filter(
                        hasOverduePayment:
                            filterType == CustomerFilterType.overduePayment
                            ? true
                            : null,
                        hasUpcomingMaintenance:
                            filterType == CustomerFilterType.upcomingMaintenance
                            ? true
                            : null,
                        hasOverdueInstallment: null,
                        search: value.isEmpty ? null : value,
                      );
                    },
                  ),
                ),
                // Müşteri listesi
                Expanded(
                  child: customers.isEmpty
                      ? _buildEmptyState(context, notifier)
                      : _buildCustomerList(context, customers, notifier),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("Hata: $error"),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => notifier.refresh(showLoading: true),
                  child: const Text("Tekrar Dene"),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          right: 16,
          bottom: 16 + padding,
          child: FloatingActionButton.extended(
            onPressed: () => _openAddCustomerSheet(context, ref),
            icon: const Icon(Icons.person_add),
            label: const Text("Müşteri Ekle"),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, CustomerListNotifier notifier) {
    String title;
    IconData icon;

    switch (filterType) {
      case CustomerFilterType.overduePayment:
        title = "Ödemesi Geçen Müşteri bulunmuyor";
        icon = Icons.payment_outlined;
        break;
      case CustomerFilterType.upcomingMaintenance:
        title = "Bakımı Gelen Müşteri bulunmuyor";
        icon = Icons.build_circle_outlined;
        break;
      case CustomerFilterType.overdueInstallment:
        // Artık kullanılmıyor, tüm ödemesi geçen müşteriler "Ödemesi Gelen" filtresinde
        title = "Müşteri bulunmuyor";
        icon = Icons.people_outline;
        break;
      case CustomerFilterType.all:
        title = "Müşteri bulunmuyor";
        icon = Icons.people_outline;
        break;
    }

    return RefreshIndicator(
      onRefresh: () => notifier.refresh(showLoading: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        children: [
          const SizedBox(height: 120),
          EmptyState(icon: icon, title: title, subtitle: null),
        ],
      ),
    );
  }

  Widget _buildCustomerList(
    BuildContext context,
    List<Customer> customers,
    CustomerListNotifier notifier,
  ) {
    return RefreshIndicator(
      onRefresh: () => notifier.refresh(showLoading: true),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        itemCount: customers.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        cacheExtent: 500,
        addAutomaticKeepAlives: false,
        addRepaintBoundaries: true,
        itemBuilder: (context, index) {
          final customer = customers[index];
          return RepaintBoundary(
            child: _CustomerTile(
              customer: customer,
              onTap: () => context.push(
                "/admin/customers/${customer.id}",
                extra: customer,
              ),
            ),
          );
        },
      ),
    );
  }

  void _openAddCustomerSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: true,
      enableDrag: true,
      builder: (_) => const AddCustomerSheet(),
    );
  }
}

enum CustomerFilterType {
  all,
  overduePayment,
  upcomingMaintenance,
  overdueInstallment,
}

enum _MaintenanceStatus {
  overdue, // Geçmiş
  upcoming, // Yaklaşıyor
}

class _CustomerTile extends StatelessWidget {
  const _CustomerTile({required this.customer, required this.onTap});

  final Customer customer;
  final VoidCallback onTap;

  Color _getStatusColor() {
    // Öncelik sırası: Ödemesi geçen (kırmızı) > Bakım geçmiş/yaklaşan (mor)
    // Taksit geçen müşteriler de "Ödemesi Geçti" olarak gösteriliyor
    if (customer.hasOverduePayment || customer.hasOverdueInstallment) {
      return Colors.red;
    }
    // Bakım durumu kontrolü - mor renk
    if (customer.hasUpcomingMaintenance) {
      return Colors.purple;
    }
    return Colors.transparent;
  }

  // Bakım durumunu kontrol et (geçmiş mi, yaklaşıyor mu)
  _MaintenanceStatus? _getMaintenanceStatus() {
    if (customer.jobs == null || customer.jobs!.isEmpty) return null;
    _MaintenanceStatus? earliestStatus;
    int? earliestDays;

    for (final job in customer.jobs!) {
      if (job.maintenanceDueAt != null) {
        final daysUntilDue = job.maintenanceDueAt!
            .difference(DateTime.now())
            .inDays;
        // Öncelik: Geçmiş > Yaklaşıyor
        if (daysUntilDue < 0) {
          // Geçmiş durum her zaman öncelikli
          return _MaintenanceStatus.overdue;
        }
        if (daysUntilDue <= 30 && daysUntilDue >= 0) {
          // En yakın bakımı bul
          if (earliestDays == null || daysUntilDue < earliestDays) {
            earliestDays = daysUntilDue;
            earliestStatus = _MaintenanceStatus.upcoming;
          }
        }
      }
    }
    return earliestStatus;
  }

  Widget? _getStatusBadge() {
    // Öncelik sırası: Ödemesi geçen > Bakım geçmiş > Bakım yaklaşan
    // Taksit geçen müşteriler de "Ödemesi Geçti" olarak gösteriliyor
    if (customer.hasOverduePayment) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.close, size: 12, color: Colors.red.shade700),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                "Borcu Geçen",
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.red.shade700,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    // Bakım durumu kontrolü
    final maintenanceStatus = _getMaintenanceStatus();
    if (maintenanceStatus == _MaintenanceStatus.overdue) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.purple.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning, size: 12, color: Colors.purple.shade700),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                "Bakımı Geçti",
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.purple.shade700,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }
    if (maintenanceStatus == _MaintenanceStatus.upcoming ||
        customer.hasUpcomingMaintenance) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.purple.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.access_time, size: 12, color: Colors.purple.shade700),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                "Bakımı Gelen",
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.purple.shade700,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }
    if (customer.hasOverdueInstallment) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.payment, size: 12, color: Colors.red.shade700),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                "Ödemesi Geçti",
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.red.shade700,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor();
    final hasStatus = statusColor != Colors.transparent;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: hasStatus ? statusColor.withValues(alpha: 0.05) : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: hasStatus
              ? BoxDecoration(
                  border: Border(
                    left: BorderSide(color: statusColor, width: 4),
                  ),
                  borderRadius: BorderRadius.circular(16),
                )
              : null,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF2563EB).withValues(alpha: 0.1),
                                const Color(0xFF10B981).withValues(alpha: 0.1),
                              ],
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              customer.name.isNotEmpty
                                  ? customer.name[0].toUpperCase()
                                  : "M",
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                customer.name,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: _getStatusColor() != Colors.transparent
                                      ? _getStatusColor()
                                      : const Color(0xFF1F2937),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.phone,
                                    size: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      customer.phone,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 16,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            customer.address,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (customer.jobs != null && customer.jobs!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.work_outline,
                              size: 16,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "${customer.jobs!.length} iş",
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                // Uyarı badge'i sağ alt köşede
                if (_getStatusBadge() != null)
                  Positioned(bottom: 0, right: 0, child: _getStatusBadge()!),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
