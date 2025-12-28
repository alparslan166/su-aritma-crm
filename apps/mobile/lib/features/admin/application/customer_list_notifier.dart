import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:socket_io_client/socket_io_client.dart" as sio;

import "../../../core/realtime/socket_client.dart";
import "../data/admin_repository.dart";
import "../data/models/customer.dart";

final customerListProvider =
    StateNotifierProvider<CustomerListNotifier, AsyncValue<List<Customer>>>(
      (ref) => CustomerListNotifier(ref.watch(adminRepositoryProvider), ref),
    );

// Her filterType için ayrı provider instance'ı
final customerListProviderForFilter =
    StateNotifierProvider.family<
      CustomerListNotifier,
      AsyncValue<List<Customer>>,
      String
    >(
      (ref, filterTypeKey) =>
          CustomerListNotifier(ref.watch(adminRepositoryProvider), ref),
);

class CustomerListNotifier extends StateNotifier<AsyncValue<List<Customer>>> {
  CustomerListNotifier(this._repository, this._ref)
    : super(const AsyncValue.loading()) {
    _listenSocket();
  }

  final AdminRepository _repository;
  final Ref _ref;
  bool? _hasOverduePayment;
  bool? _hasUpcomingMaintenance;
  bool? _hasOverdueInstallment;
  String? _search;
  String? _phoneSearch;
  DateTime? _createdAtFrom;
  DateTime? _createdAtTo;
  bool _initialized = false;

  Future<void> refresh({bool showLoading = false}) async {
    // Eğer showLoading true ise loading göster, değilse mevcut data'yı koru
    // Arama sırasında sayfa yenilenmesin, sadece liste güncellensin
    if (showLoading) {
      state = const AsyncValue.loading();
    }
    // showLoading false ise state'i değiştirme, mevcut data korunur

    print("🔄 CustomerListNotifier.refresh: showLoading=$showLoading");
    print(
      "   Filters: search=$_search, phoneSearch=$_phoneSearch, createdAtFrom=$_createdAtFrom, createdAtTo=$_createdAtTo, hasOverduePayment=$_hasOverduePayment, hasUpcomingMaintenance=$_hasUpcomingMaintenance",
    );

    try {
      final customers = await _repository.fetchCustomers(
        search: _search,
        phoneSearch: _phoneSearch,
        createdAtFrom: _createdAtFrom,
        createdAtTo: _createdAtTo,
        hasOverduePayment: _hasOverduePayment,
        hasUpcomingMaintenance: _hasUpcomingMaintenance,
        hasOverdueInstallment: _hasOverdueInstallment,
      );
      
      // Remove duplicates by customer ID and by name+phone combination
      final seenIds = <String>{};
      final seenNamePhone = <String>{};
      final uniqueCustomers = customers.where((c) {
        // Check by ID
        if (seenIds.contains(c.id)) return false;
        // Check by name+phone combination (case-insensitive)
        final namePhoneKey = '${c.name.toLowerCase().trim()}_${c.phone.replaceAll(RegExp(r'\s+'), '')}';
        if (seenNamePhone.contains(namePhoneKey)) return false;
        seenIds.add(c.id);
        seenNamePhone.add(namePhoneKey);
        return true;
      }).toList();
      
      // print("✅ fetchCustomers başarılı, ${uniqueCustomers.length} müşteri döndü");
      state = AsyncValue.data(uniqueCustomers);
    } catch (error, stackTrace) {
      print("❌ fetchCustomers hatası: $error");
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> filter({
    bool? hasOverduePayment,
    bool? hasUpcomingMaintenance,
    bool? hasOverdueInstallment,
    String? search,
    String? phoneSearch,
    DateTime? createdAtFrom,
    DateTime? createdAtTo,
  }) async {
    // null değerler filtrenin kaldırılması anlamına gelir
    final newOverdue = hasOverduePayment;
    final newMaintenance = hasUpcomingMaintenance;
    final newInstallment = hasOverdueInstallment;
    // Search için: null gelirse temizle, boş string gelirse temizle, değer gelirse kullan
    final newSearch = search == null ? null : (search.isEmpty ? null : search);
    final newPhoneSearch = phoneSearch == null
        ? null
        : (phoneSearch.isEmpty ? null : phoneSearch);
    final newCreatedAtFrom = createdAtFrom;
    final newCreatedAtTo = createdAtTo;

    // Only refresh if filter actually changed or not initialized yet
    // String karşılaştırması için null-safe kontrol
    final searchChanged = (newSearch ?? "") != (_search ?? "");
    final phoneSearchChanged = (newPhoneSearch ?? "") != (_phoneSearch ?? "");
    final dateFromChanged = newCreatedAtFrom != _createdAtFrom;
    final dateToChanged = newCreatedAtTo != _createdAtTo;

    // Debug logları
    print("🔍 CustomerListNotifier.filter: _initialized=$_initialized");
    print("   newOverdue=$newOverdue, _hasOverduePayment=$_hasOverduePayment");
    print(
      "   newMaintenance=$newMaintenance, _hasUpcomingMaintenance=$_hasUpcomingMaintenance",
    );
    print("   newSearch=$newSearch, _search=$_search");
    print("   newPhoneSearch=$newPhoneSearch, _phoneSearch=$_phoneSearch");
    print(
      "   newCreatedAtFrom=$newCreatedAtFrom, _createdAtFrom=$_createdAtFrom",
    );
    print("   newCreatedAtTo=$newCreatedAtTo, _createdAtTo=$_createdAtTo");

    // İlk yüklemede veya filtre değiştiğinde refresh yap
    final shouldRefresh =
        !_initialized ||
        newOverdue != _hasOverduePayment ||
        newMaintenance != _hasUpcomingMaintenance ||
        newInstallment != _hasOverdueInstallment ||
        searchChanged ||
        phoneSearchChanged ||
        dateFromChanged ||
        dateToChanged;

    if (shouldRefresh) {
      final wasInitialized = _initialized;
      final hasExistingData = state.valueOrNull != null;

      // Filtreleri güncelle
      _hasOverduePayment = newOverdue;
      _hasUpcomingMaintenance = newMaintenance;
      _hasOverdueInstallment = newInstallment;
      _search = newSearch;
      _phoneSearch = newPhoneSearch;
      _createdAtFrom = newCreatedAtFrom;
      _createdAtTo = newCreatedAtTo;
      _initialized = true;

      print("✅ Filter değişti veya ilk yükleme, refresh çağrılıyor...");
      print("   showLoading=${!wasInitialized && !hasExistingData}");

      // Sadece ilk yüklemede veya manuel refresh'te loading göster
      // Arama değişikliklerinde mevcut data'yı koru, loading gösterme
      await refresh(showLoading: !wasInitialized && !hasExistingData);
      
      print(
        "✅ Refresh tamamlandı, müşteri sayısı: ${state.valueOrNull?.length ?? 0}",
      );
    } else {
      print("⏭️ Filter değişmedi, refresh atlandı");
    }
  }

  void _listenSocket() {
    _ref.listen<sio.Socket?>(socketClientProvider, (previous, next) {
      previous?.off("customer-update", _handleCustomerUpdate);
      previous?.off("job-status", _handleJobStatus);
      next?.on("customer-update", _handleCustomerUpdate);
      next?.on("job-status", _handleJobStatus);
    });
  }

  void _handleCustomerUpdate(dynamic data) {
    // Refresh customer list when customer is updated (e.g., payment status, maintenance)
    refresh(showLoading: false);
  }

  void _handleJobStatus(dynamic data) {
    // Refresh customer list when job status changes (affects customer filters)
    refresh(showLoading: false);
  }
}
