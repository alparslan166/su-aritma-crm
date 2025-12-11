import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_hooks/flutter_hooks.dart";
import "package:go_router/go_router.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:intl/intl.dart";
import "package:url_launcher/url_launcher.dart";
import "package:geocoding/geocoding.dart";
import "package:mobile/widgets/empty_state.dart";

import "../../../../core/error/error_handler.dart";
import "../../application/customer_list_notifier.dart";
import "../../data/admin_repository.dart";
import "../../data/models/customer.dart";
import "../../../dashboard/presentation/home_page_provider.dart";
import "add_customer_sheet.dart";
import "edit_customer_sheet.dart";
import "job_map_view.dart";
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
    final isSelectionMode = useState<bool>(false);
    final selectedCustomers = useState<Set<String>>({});

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
      // Filter'ı hemen uygula, PostFrameCallback beklemeyelim
      applyFilters(
        search: searchQuery.value,
        phoneSearch: phoneSearchQuery.value,
        createdAtFrom: dateFrom.value,
        createdAtTo: dateTo.value,
      );
      // Widget tamamen oluştuktan sonra da filtreleri tekrar uygula (eğer değişmişse)
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
                // Seçim modu AppBar
                if (isSelectionMode.value)
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    color: Theme.of(
                      context,
                    ).primaryColor.withValues(alpha: 0.1),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            isSelectionMode.value = false;
                            selectedCustomers.value = {};
                          },
                          tooltip: "Seçim Modunu Kapat",
                        ),
                        Expanded(
                          child: Text(
                            "${selectedCustomers.value.length} müşteri seçildi",
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (selectedCustomers.value.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteSelectedCustomers(
                              context,
                              ref,
                              selectedCustomers.value,
                              customers,
                              notifier,
                              isSelectionMode,
                              selectedCustomers,
                            ),
                            tooltip: "Seçilenleri Sil",
                          ),
                      ],
                    ),
                  ),
                // Arama kutusu
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      if (isSelectionMode.value)
                        IconButton(
                          icon: const Icon(Icons.check_box_outline_blank),
                          onPressed: () {
                            // Tümünü seç/seçimi kaldır
                            if (selectedCustomers.value.length ==
                                customers.length) {
                              selectedCustomers.value = {};
                            } else {
                              selectedCustomers.value = customers
                                  .map((c) => c.id)
                                  .toSet();
                            }
                          },
                          tooltip:
                              selectedCustomers.value.length == customers.length
                              ? "Seçimi Kaldır"
                              : "Tümünü Seç",
                        ),
                      Expanded(
                        child: TextField(
                          controller: searchController,
                          autofocus: false,
                          textInputAction: TextInputAction.search,
                          enabled: !isSelectionMode.value,
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
                      if (!isSelectionMode.value) ...[
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
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () {
                            isSelectionMode.value = true;
                          },
                          tooltip: "Çoklu Seçim",
                        ),
                      ],
                    ],
                  ),
                ),
                // Filtreler bölümü
                if (showFilters.value && !isSelectionMode.value)
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
                      : _buildCustomerList(
                          context,
                          ref,
                          customers,
                          notifier,
                          isSelectionMode,
                          selectedCustomers,
                        ),
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
        if (!isSelectionMode.value && filterType == CustomerFilterType.all)
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
    ValueNotifier<bool> isSelectionMode,
    ValueNotifier<Set<String>> selectedCustomers,
  ) {
    final scrollController = useScrollController();
    final scrollOffset = useState<double>(0.0);
    final previousScrollOffset = useRef<double>(0.0);
    final scrollVelocity = useState<double>(0.0);
    final lastUpdateTime = useRef<DateTime>(DateTime.now());
    final velocityDecayTimer = useRef<Timer?>(null);

    useEffect(() {
      void listener() {
        final now = DateTime.now();
        final timeDelta = now.difference(lastUpdateTime.value).inMilliseconds;
        final offsetDelta =
            scrollController.offset - previousScrollOffset.value;

        if (timeDelta > 0 && timeDelta < 100) {
          // Scroll hızını hesapla (pixels per second)
          final velocity = (offsetDelta / timeDelta) * 1000;
          scrollVelocity.value = velocity.abs();

          // Scroll durduğunda hızı yavaşça azalt
          velocityDecayTimer.value?.cancel();
          velocityDecayTimer.value = Timer(
            const Duration(milliseconds: 100),
            () {
              scrollVelocity.value = scrollVelocity.value * 0.7;
              if (scrollVelocity.value < 10) {
                scrollVelocity.value = 0;
              }
            },
          );
        }

        scrollOffset.value = scrollController.offset;
        previousScrollOffset.value = scrollController.offset;
        lastUpdateTime.value = now;
      }

      scrollController.addListener(listener);
      return () {
        scrollController.removeListener(listener);
        velocityDecayTimer.value?.cancel();
      };
    }, [scrollController]);

    return RefreshIndicator(
      onRefresh: () => notifier.refresh(showLoading: true),
      child: ListView.separated(
        controller: scrollController,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        itemCount: customers.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        cacheExtent: 500,
        addAutomaticKeepAlives: false,
        addRepaintBoundaries: true,
        itemBuilder: (context, index) {
          final customer = customers[index];
          final isSelected = selectedCustomers.value.contains(customer.id);
          return RepaintBoundary(
            child: _AnimatedCustomerTile(
              customer: customer,
              isSelectionMode: isSelectionMode.value,
              isSelected: isSelected,
              scrollOffset: scrollOffset.value,
              scrollVelocity: scrollVelocity.value,
              index: index,
              onTap: isSelectionMode.value
                  ? () {
                      // Seçim modunda: seç/seçimi kaldır
                      final newSet = Set<String>.from(selectedCustomers.value);
                      if (isSelected) {
                        newSet.remove(customer.id);
                      } else {
                        newSet.add(customer.id);
                      }
                      selectedCustomers.value = newSet;
                    }
                  : () => context.push(
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

  Future<void> _openLocationMap(BuildContext context, Customer customer) async {
    LatLng? location;

    // Önce müşterinin location bilgisini kontrol et
    if (customer.location != null) {
      location = LatLng(
        customer.location!.latitude,
        customer.location!.longitude,
      );
    } else {
      // Location yoksa adresten geocoding yap
      if (customer.address.isEmpty) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Adres bilgisi bulunamadı")),
        );
        return;
      }

      // Loading göster
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Konum alınıyor..."),
          duration: Duration(seconds: 2),
        ),
      );

      try {
        // Timeout ile geocoding yap (10 saniye)
        final locations = await locationFromAddress(customer.address).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw TimeoutException("Geocoding timeout");
          },
        );
        if (!context.mounted) return;
        if (locations.isNotEmpty) {
          final loc = locations.first;
          location = LatLng(loc.latitude, loc.longitude);
        } else {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Adres için konum bulunamadı"),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }
      } catch (e) {
        if (!context.mounted) return;
        ErrorHandler.showWarning(
          context,
          "Konum yüklenemedi. ${ErrorHandler.getUserFriendlyMessage(e)}",
        );
        return;
      }
    }

    // Konum bulundu, seçenekleri göster
    if (!context.mounted) return;
    final choice = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Text(
                "Konum Seçenekleri",
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.map, color: Color(0xFF2563EB)),
              title: const Text("Haritada Aç"),
              subtitle: const Text("Uygulama içi harita görünümü"),
              onTap: () => Navigator.of(context).pop("map"),
            ),
            ListTile(
              leading: const Icon(Icons.place, color: Color(0xFF10B981)),
              title: const Text("Google Maps ile Aç"),
              subtitle: const Text("Google Maps uygulamasında aç"),
              onTap: () => Navigator.of(context).pop("google"),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (!context.mounted || choice == null) return;

    if (choice == "map") {
      // Haritada Aç
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => JobMapView(
            initialCustomerLocation: location!,
            initialCustomerId: customer.id,
          ),
        ),
      );
    } else if (choice == "google") {
      // Google Maps ile Aç
      final encodedAddress = Uri.encodeComponent(customer.address);
      final googleMapsUrl =
          "https://www.google.com/maps/search/?api=1&query=$encodedAddress";
      final uri = Uri.parse(googleMapsUrl);
      // ignore: unawaited_futures
      launchUrl(uri, mode: LaunchMode.externalApplication);
    }
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
      
      // Ana sayfa grafik ve istatistiklerini statik olarak yenile
      ref.invalidate(dashboardStatsProvider);
      ref.invalidate(customerCategoryDataProvider);
      ref.invalidate(overduePaymentsCustomersProvider);
      ref.invalidate(upcomingMaintenanceProvider);
      
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text("${customer.name} silindi")),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ErrorHandler.showError(context, error);
      }
    }
  }

  Future<void> _deleteSelectedCustomers(
    BuildContext context,
    WidgetRef ref,
    Set<String> selectedIds,
    List<Customer> customers,
    CustomerListNotifier notifier,
    ValueNotifier<bool> isSelectionMode,
    ValueNotifier<Set<String>> selectedCustomers,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final selectedCustomersList = customers
        .where((c) => selectedIds.contains(c.id))
        .toList();
    final count = selectedCustomersList.length;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Müşterileri Sil"),
        content: Text(
          "$count müşteriyi silmek istediğinize emin misiniz? Bu işlem geri alınamaz.",
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

    // Loading göster
    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
    }

    int successCount = 0;
    int failCount = 0;
    final repository = ref.read(adminRepositoryProvider);

    for (final customer in selectedCustomersList) {
      try {
        await repository.deleteCustomer(customer.id);
        successCount++;
      } catch (error) {
        failCount++;
        debugPrint("Müşteri silinemedi (${customer.name}): $error");
      }
    }

    // Loading'i kapat
    if (context.mounted) {
      Navigator.of(context).pop();
    }

    // Listeyi yenile
    await notifier.refresh(showLoading: false);

    // Ana sayfa grafik ve istatistiklerini statik olarak yenile
    ref.invalidate(dashboardStatsProvider);
    ref.invalidate(customerCategoryDataProvider);
    ref.invalidate(overduePaymentsCustomersProvider);
    ref.invalidate(upcomingMaintenanceProvider);

    // Seçim modunu kapat ve seçimleri temizle
    if (context.mounted) {
      isSelectionMode.value = false;
      selectedCustomers.value = {};
    }

    // Sonuç mesajı göster
    if (context.mounted) {
      if (failCount == 0) {
        messenger.showSnackBar(
          SnackBar(
            content: Text("$successCount müşteri başarıyla silindi"),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              "$successCount müşteri silindi, $failCount müşteri silinemedi",
            ),
            backgroundColor: Colors.orange,
          ),
        );
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

// Animasyonlu ikon widget'ı
class _AnimatedIconWidget extends StatefulWidget {
  const _AnimatedIconWidget({required this.assetPath});

  final String assetPath;

  @override
  State<_AnimatedIconWidget> createState() => _AnimatedIconWidgetState();
}

class _AnimatedIconWidgetState extends State<_AnimatedIconWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0.0,
      end: 8.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _animation.value),
          child: Image.asset(
            widget.assetPath,
            width: 48,
            height: 48,
            fit: BoxFit.contain,
          ),
        );
      },
    );
  }
}

class _CustomerTile extends StatelessWidget {
  const _CustomerTile({
    required this.customer,
    required this.onTap,
    required this.onDelete,
    required this.onEdit,
    required this.onLocation,
    this.isSelectionMode = false,
    this.isSelected = false,
  });

  final Customer customer;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback onLocation;
  final bool isSelectionMode;
  final bool isSelected;

  Color _getStatusColor() {
    // Öncelik sırası: Borç/Taksit/Bakım (kırmızı/turuncu) > Aktif/Pasif (yeşil/gri)
    // 1. Öncelik: Ödemesi geçen veya taksit geçen (kırmızı)
    if (customer.hasOverduePayment || customer.hasOverdueInstallment) {
      return const Color(0xFFEF4444);
    }
    // 2. Öncelik: Bakım geçmiş/yaklaşan (turuncu)
    if (customer.hasUpcomingMaintenance) {
      return const Color(0xFFF59E0B);
    }
    // 3. Öncelik: Aktif/Pasif durumu
    if (customer.status == "ACTIVE") {
      return const Color(0xFF10B981); // Yeşil - Aktif
    }
    if (customer.status == "INACTIVE") {
      return Colors.grey; // Gri - Pasif
    }
    return Colors.transparent;
  }

  // Animasyonlu ikon widget'ı
  Widget _buildAnimatedIcon(String assetPath) {
    return _AnimatedIconWidget(assetPath: assetPath);
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
    // Çerçeve rengi: Öncelik sırasına göre (borç/taksit/bakım > aktif/pasif)
    final borderColor = statusColor;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: hasStatus
          ? statusColor.withValues(alpha: 0.05)
          : isSelected
          ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
          : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: isSelected
                    ? Theme.of(context).primaryColor
                    : borderColor,
                width: 4,
              ),
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Stack(
              children: [
                // Animasyonlu ikonlar - sağ üst köşe
                if (customer.hasOverduePayment ||
                    customer.hasOverdueInstallment)
                  Positioned(
                    top: 0,
                    right: isSelectionMode ? 48 : 8,
                    child: _buildAnimatedIcon("assets/images/clock.png"),
                  )
                else if (customer.hasUpcomingMaintenance)
                  Positioned(
                    top: 0,
                    right: isSelectionMode ? 48 : 8,
                    child: _buildAnimatedIcon("assets/images/wrench.png"),
                  ),
                if (isSelectionMode)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Checkbox(
                      value: isSelected,
                      onChanged: (value) => onTap(),
                    ),
                  ),
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
                        // İkonlar için sabit boşluk (responsivity için)
                        SizedBox(
                          width:
                              (customer.hasOverduePayment ||
                                  customer.hasOverdueInstallment ||
                                  customer.hasUpcomingMaintenance)
                              ? 52
                              : (isSelectionMode ? 24 : 0),
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
                    if (!isSelectionMode) ...[
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

class _AnimatedCustomerTile extends StatelessWidget {
  const _AnimatedCustomerTile({
    required this.customer,
    required this.isSelectionMode,
    required this.isSelected,
    required this.scrollOffset,
    required this.scrollVelocity,
    required this.index,
    required this.onTap,
    required this.onDelete,
    required this.onEdit,
    required this.onLocation,
  });

  final Customer customer;
  final bool isSelectionMode;
  final bool isSelected;
  final double scrollOffset;
  final double scrollVelocity;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback onLocation;

  @override
  Widget build(BuildContext context) {
    // iOS bildirim animasyonu: scroll sırasında kartlar birbirine yaklaşır
    // Kart yüksekliği + separator = yaklaşık 212px
    final cardHeight = 212.0;
    final cardPosition = index * cardHeight;

    // Viewport içindeki kartlar için animasyon uygula
    final viewportHeight = MediaQuery.of(context).size.height;
    final cardTop = cardPosition - scrollOffset;
    final cardBottom = cardTop + cardHeight;
    final cardCenter = cardTop + cardHeight / 2;
    final viewportCenter = viewportHeight / 2;

    // Viewport dışındaki kartlar için animasyon uygulama
    if (cardBottom < -50 || cardTop > viewportHeight + 50) {
      return _CustomerTile(
        customer: customer,
        isSelectionMode: isSelectionMode,
        isSelected: isSelected,
        onTap: onTap,
        onDelete: onDelete,
        onEdit: onEdit,
        onLocation: onLocation,
      );
    }

    // Scroll hızına göre scale hesapla (birbirine yaklaşma efekti)
    // Maksimum scroll hızı: 2000 pixels/second
    final maxVelocity = 2000.0;
    final normalizedVelocity = (scrollVelocity / maxVelocity).clamp(0.0, 1.0);

    // Scroll hızına göre scale: hızlı scroll'da kartlar küçülür (birbirine yaklaşır)
    // Minimum scale: 0.98 (kartlar %2 küçülür)
    final scale = 1.0 - (normalizedVelocity * 0.02);

    // Viewport merkezine göre hafif bir offset hesapla
    final distanceFromCenter = (cardCenter - viewportCenter).abs();
    final maxDistance = viewportHeight / 2;
    final normalizedDistance = (distanceFromCenter / maxDistance).clamp(
      0.0,
      1.0,
    );

    // Merkeze yakın kartlar daha az, uzak kartlar daha fazla hareket eder
    final offset =
        (1.0 - normalizedDistance) *
        1.5 *
        (cardCenter < viewportCenter ? -1 : 1);

    return Transform(
      transform: Matrix4.identity()
        ..translate(0.0, offset)
        ..scale(scale),
      alignment: Alignment.center,
      child: _CustomerTile(
        customer: customer,
        isSelectionMode: isSelectionMode,
        isSelected: isSelected,
        onTap: onTap,
        onDelete: onDelete,
        onEdit: onEdit,
        onLocation: onLocation,
      ),
    );
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
