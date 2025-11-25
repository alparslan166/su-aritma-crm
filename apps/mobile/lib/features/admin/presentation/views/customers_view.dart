import "package:flutter/material.dart";
import "package:flutter_hooks/flutter_hooks.dart";
import "package:go_router/go_router.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:intl/intl.dart";
import "package:url_launcher/url_launcher.dart";
import "package:mobile/widgets/empty_state.dart";

import "../../application/customer_list_notifier.dart";
import "../../data/admin_repository.dart";
import "../../data/models/customer.dart";
import "add_customer_sheet.dart";
import "edit_customer_sheet.dart";
import "full_screen_map_page.dart";
import "package:latlong2/latlong.dart";

class CustomersView extends HookConsumerWidget {
  const CustomersView({super.key, required this.filterType});

  final CustomerFilterType filterType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Her filterType için ayrı provider instance'ı kullan
    final filterTypeKey = filterType.toString();
    final notifier = ref.read(
      customerListProviderForFilter(filterTypeKey).notifier,
    );
    final searchController = useTextEditingController();
    final phoneSearchController = useTextEditingController();
    final searchQuery = useState<String>("");
    final phoneSearchQuery = useState<String>("");
    final showFilters = useState<bool>(false);
    final dateFrom = useState<DateTime?>(null);
    final dateTo = useState<DateTime?>(null);

    // Helper function to apply filters (for filterType changes and clear button)
    void applyFilters({
      String? search,
      String? phoneSearch,
      DateTime? createdAtFrom,
      DateTime? createdAtTo,
    }) {
      // Tüm Müşteriler: Hiçbir filtre gönderme (null)
      // Ödemesi Gelen: hasOverduePayment=true
      // Bakımı Gelen: hasUpcomingMaintenance=true
      final bool? overduePaymentFilter;
      final bool? maintenanceFilter;

      switch (filterType) {
        case CustomerFilterType.all:
          overduePaymentFilter = null;
          maintenanceFilter = null;
          break;
        case CustomerFilterType.overduePayment:
          overduePaymentFilter = true;
          maintenanceFilter = null;
          break;
        case CustomerFilterType.upcomingMaintenance:
          overduePaymentFilter = null;
          maintenanceFilter = true;
          break;
        case CustomerFilterType.overdueInstallment:
          overduePaymentFilter = null;
          maintenanceFilter = null;
          break;
      }

      // Debug: Filtre değerlerini logla
      debugPrint(
        "🔍 applyFilters: filterType=$filterType, hasOverduePayment=$overduePaymentFilter, hasUpcomingMaintenance=$maintenanceFilter, search=$search, phoneSearch=$phoneSearch, dateFrom=$createdAtFrom, dateTo=$createdAtTo",
      );

      notifier.filter(
        hasOverduePayment: overduePaymentFilter,
        hasUpcomingMaintenance: maintenanceFilter,
        hasOverdueInstallment: null,
        search: search?.isEmpty ?? true ? null : search,
        phoneSearch: phoneSearch?.isEmpty ?? true ? null : phoneSearch,
        createdAtFrom: createdAtFrom,
        createdAtTo: createdAtTo,
      );
    }

    // Apply filter when filterType changes or on initial load
    useEffect(() {
      debugPrint(
        "🔄 useEffect: filterType=$filterType, filterTypeKey=$filterTypeKey, searchQuery=${searchQuery.value}",
      );
      // Widget tamamen oluştuktan sonra filtreleri uygula
      WidgetsBinding.instance.addPostFrameCallback((_) {
        debugPrint(
          "📞 PostFrameCallback: applyFilters çağrılıyor, filterType=$filterType",
        );
        applyFilters(
          search: searchQuery.value,
          phoneSearch: phoneSearchQuery.value,
          createdAtFrom: dateFrom.value,
          createdAtTo: dateTo.value,
        );
      });
      return null;
    }, [filterType, filterTypeKey]);

    final state = ref.watch(customerListProviderForFilter(filterTypeKey));
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
                  child: Row(
                    children: [
                      Expanded(
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
                                      applyFilters(
                                        search: "",
                                        phoneSearch: phoneSearchQuery.value,
                                        createdAtFrom: dateFrom.value,
                                        createdAtTo: dateTo.value,
                                      );
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
                            searchQuery.value = value;
                            applyFilters(
                              search: value,
                              phoneSearch: phoneSearchQuery.value,
                              createdAtFrom: dateFrom.value,
                              createdAtTo: dateTo.value,
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(
                          showFilters.value
                              ? Icons.filter_alt
                              : Icons.filter_alt_outlined,
                        ),
                        onPressed: () {
                          showFilters.value = !showFilters.value;
                        },
                        tooltip: "Filtreler",
                      ),
                    ],
                  ),
                ),
                // Filtreler bölümü
                if (showFilters.value)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  "Filtreler",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Spacer(),
                                TextButton(
                                  onPressed: () {
                                    phoneSearchController.clear();
                                    phoneSearchQuery.value = "";
                                    dateFrom.value = null;
                                    dateTo.value = null;
                                    applyFilters(
                                      search: searchQuery.value,
                                      phoneSearch: "",
                                      createdAtFrom: null,
                                      createdAtTo: null,
                                    );
                                  },
                                  child: const Text("Temizle"),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Telefon numarası araması
                            TextField(
                              controller: phoneSearchController,
                              decoration: const InputDecoration(
                                labelText: "Telefon Numarası",
                                hintText: "Örn: 2324",
                                prefixIcon: Icon(Icons.phone),
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.phone,
                              onChanged: (value) {
                                phoneSearchQuery.value = value;
                                applyFilters(
                                  search: searchQuery.value,
                                  phoneSearch: value,
                                  createdAtFrom: dateFrom.value,
                                  createdAtTo: dateTo.value,
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                            // Tarih filtreleme
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate:
                                            dateFrom.value ?? DateTime.now(),
                                        firstDate: DateTime(2000),
                                        lastDate: DateTime.now(),
                                      );
                                      if (picked != null) {
                                        dateFrom.value = picked;
                                        applyFilters(
                                          search: searchQuery.value,
                                          phoneSearch: phoneSearchQuery.value,
                                          createdAtFrom: picked,
                                          createdAtTo: dateTo.value,
                                        );
                                      }
                                    },
                                    icon: const Icon(
                                      Icons.calendar_today,
                                      size: 18,
                                    ),
                                    label: Text(
                                      dateFrom.value != null
                                          ? DateFormat(
                                              "dd MMM yyyy",
                                            ).format(dateFrom.value!)
                                          : "Başlangıç Tarihi",
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate:
                                            dateTo.value ?? DateTime.now(),
                                        firstDate:
                                            dateFrom.value ?? DateTime(2000),
                                        lastDate: DateTime.now(),
                                      );
                                      if (picked != null) {
                                        dateTo.value = picked;
                                        applyFilters(
                                          search: searchQuery.value,
                                          phoneSearch: phoneSearchQuery.value,
                                          createdAtFrom: dateFrom.value,
                                          createdAtTo: picked,
                                        );
                                      }
                                    },
                                    icon: const Icon(
                                      Icons.calendar_today,
                                      size: 18,
                                    ),
                                    label: Text(
                                      dateTo.value != null
                                          ? DateFormat(
                                              "dd MMM yyyy",
                                            ).format(dateTo.value!)
                                          : "Bitiş Tarihi",
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                // Müşteri listesi
                Expanded(
                  child: customers.isEmpty
                      ? _buildEmptyState(context, notifier)
                      : _buildCustomerList(context, ref, customers, notifier),
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
    WidgetRef ref,
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
              onDelete: () => _deleteCustomer(context, ref, customer, notifier),
              onEdit: () => _showEditCustomerSheet(context, ref, customer),
              onLocation: () => _openLocationMap(context, customer),
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

  Future<void> _showEditCustomerSheet(
    BuildContext context,
    WidgetRef ref,
    Customer customer,
  ) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: true,
      enableDrag: true,
      builder: (_) => EditCustomerSheet(customer: customer),
    ).then((_) {
      // Refresh customer list after editing
      ref.read(customerListProvider.notifier).refresh(showLoading: false);
    });
  }

  void _openLocationMap(BuildContext context, Customer customer) {
    if (customer.location == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Bu müşterinin konum bilgisi bulunmuyor")),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FullScreenMapPage(
          location: LatLng(
            customer.location!.latitude,
            customer.location!.longitude,
          ),
          title: customer.name,
          address: customer.address,
        ),
      ),
    );
  }

  Future<void> _deleteCustomer(
    BuildContext context,
    WidgetRef ref,
    Customer customer,
    CustomerListNotifier notifier,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Müşteriyi Sil"),
        content: Text(
          "${customer.name} müşterisini silmek istediğinize emin misiniz? Bu işlem geri alınamaz.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("İptal"),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Sil"),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ref.read(adminRepositoryProvider).deleteCustomer(customer.id);
      await notifier.refresh(showLoading: false);
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text("${customer.name} silindi")),
        );
      }
    } catch (error) {
      if (context.mounted) {
        messenger.showSnackBar(SnackBar(content: Text("Silinemedi: $error")));
      }
    }
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
  const _CustomerTile({
    required this.customer,
    required this.onTap,
    required this.onDelete,
    required this.onEdit,
    required this.onLocation,
  });

  final Customer customer;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback onLocation;

  Color _getStatusColor() {
    // Öncelik sırası: Ödemesi geçen (kırmızı) > Bakım geçmiş/yaklaşan (turuncu)
    // Taksit geçen müşteriler de "Ödemesi Geçti" olarak gösteriliyor
    if (customer.hasOverduePayment || customer.hasOverdueInstallment) {
      return const Color(0xFFEF4444);
    }
    // Bakım durumu kontrolü - turuncu renk
    if (customer.hasUpcomingMaintenance) {
      return const Color(0xFFF59E0B);
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
          color: const Color(0xFFEF4444).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFEF4444).withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.close, size: 12, color: Color(0xFFEF4444)),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                "Borcu Geçen",
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFEF4444),
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
          color: const Color(0xFFEF4444).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFEF4444).withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning, size: 12, color: Color(0xFFEF4444)),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                "Bakımı Geçti",
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFEF4444),
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
          color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.access_time, size: 12, color: Color(0xFFF59E0B)),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                "Bakımı Gelen",
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFF59E0B),
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
          color: const Color(0xFFEF4444).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFEF4444).withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.payment, size: 12, color: Color(0xFFEF4444)),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                "Taksidi Geçen",
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFEF4444),
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
                            if (_getStatusBadge() != null) ...[
                              const Spacer(),
                              _getStatusBadge()!,
                            ],
                          ],
                        ),
                      ),
                    ] else if (_getStatusBadge() != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [_getStatusBadge()!],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    // Butonlar - Sadece ikonlar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _ActionButton(
                          icon: Icons.message_rounded,
                          color: const Color(
                            0xFF10B981,
                          ), // Yeşil - WhatsApp/SMS
                          onPressed: () => _showMessageOptions(context),
                          tooltip: "Mesaj",
                        ),
                        _ActionButton(
                          icon: Icons.phone_rounded,
                          color: const Color(0xFF2563EB), // Mavi - Telefon
                          onPressed: () => _showCallOptions(context),
                          tooltip: "Ara",
                        ),
                        _ActionButton(
                          icon: Icons.location_on_rounded,
                          color: const Color(0xFF64748B), // Mavi gri - Konum
                          onPressed: onLocation,
                          tooltip: "Konum",
                        ),
                        _ActionButton(
                          icon: Icons.edit_rounded,
                          color: const Color(0xFF7C3AED), // Mor - Düzenleme
                          onPressed: onEdit,
                          tooltip: "Düzenle",
                        ),
                        _ActionButton(
                          icon: Icons.delete_outline_rounded,
                          color: const Color(0xFFEF4444), // Kırmızı - Silme
                          onPressed: onDelete,
                          tooltip: "Sil",
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Telefon numarasını formatlar (sadece rakamlar, Türkiye için +90 ekler)
  String _formatPhoneNumber(String phone) {
    // Sadece rakamları al
    final digits = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) return '';

    // Türkiye telefon numarası formatı: +90 ile başlamalı
    // Eğer 10 haneli ise (0 ile başlamıyorsa) +90 ekle
    // Eğer 11 haneli ise ve 0 ile başlıyorsa, 0'ı kaldır ve +90 ekle
    if (digits.length == 10) {
      // 10 haneli: 5321234567 -> +905321234567
      return '+90$digits';
    } else if (digits.length == 11 && digits.startsWith('0')) {
      // 11 haneli ve 0 ile başlıyor: 05321234567 -> +905321234567
      return '+90${digits.substring(1)}';
    } else if (digits.startsWith('90') && digits.length == 12) {
      // Zaten 90 ile başlıyor: 905321234567 -> +905321234567
      return '+$digits';
    } else if (digits.startsWith('+90')) {
      // Zaten +90 ile başlıyor: +905321234567
      return digits;
    }
    // Diğer durumlarda olduğu gibi döndür
    return digits;
  }

  Future<void> _showMessageOptions(BuildContext context) async {
    final option = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.chat, color: Color(0xFF10B981)),
              title: const Text("WhatsApp"),
              onTap: () => Navigator.of(context).pop("whatsapp"),
            ),
            ListTile(
              leading: const Icon(Icons.sms, color: Color(0xFF2563EB)),
              title: const Text("SMS"),
              onTap: () => Navigator.of(context).pop("sms"),
            ),
          ],
        ),
      ),
    );

    if (option == null || !context.mounted) return;

    final phone = _formatPhoneNumber(customer.phone);
    if (phone.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Geçerli bir telefon numarası bulunamadı"),
          ),
        );
      }
      return;
    }

    try {
      if (option == "whatsapp") {
        final url = Uri.parse("https://wa.me/$phone");
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text("WhatsApp açılamadı")));
          }
        }
      } else if (option == "sms") {
        // Android için sadece rakamlar, iOS için +90 ile başlayan format
        final smsPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
        final url = Uri.parse("sms:$smsPhone");
        try {
          if (await canLaunchUrl(url)) {
            await launchUrl(url, mode: LaunchMode.externalApplication);
          } else {
            // canLaunchUrl false dönerse de deneyelim
            await launchUrl(url, mode: LaunchMode.externalApplication);
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text("SMS açılamadı: $e")));
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Hata: $e")));
      }
    }
  }

  Future<void> _showCallOptions(BuildContext context) async {
    final option = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.chat, color: Color(0xFF10B981)),
              title: const Text("WhatsApp"),
              onTap: () => Navigator.of(context).pop("whatsapp"),
            ),
            ListTile(
              leading: const Icon(Icons.phone, color: Color(0xFF2563EB)),
              title: const Text("Telefon"),
              onTap: () => Navigator.of(context).pop("phone"),
            ),
          ],
        ),
      ),
    );

    if (option == null || !context.mounted) return;

    final phone = _formatPhoneNumber(customer.phone);
    if (phone.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Geçerli bir telefon numarası bulunamadı"),
          ),
        );
      }
      return;
    }

    try {
      if (option == "whatsapp") {
        final url = Uri.parse("https://wa.me/$phone");
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text("WhatsApp açılamadı")));
          }
        }
      } else if (option == "phone") {
        // Android için sadece rakamlar, iOS için +90 ile başlayan format
        final telPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
        final url = Uri.parse("tel:$telPhone");
        try {
          if (await canLaunchUrl(url)) {
            await launchUrl(url, mode: LaunchMode.externalApplication);
          } else {
            // canLaunchUrl false dönerse de deneyelim
            await launchUrl(url, mode: LaunchMode.externalApplication);
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text("Telefon açılamadı: $e")));
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Hata: $e")));
      }
    }
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.color,
    required this.onPressed,
    required this.tooltip,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: color.withValues(alpha: 0.2),
                width: 1.5,
              ),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
        ),
      ),
    );
  }
}
