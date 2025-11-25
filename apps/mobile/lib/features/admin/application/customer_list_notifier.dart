import "package:hooks_riverpod/hooks_riverpod.dart";

import "../data/admin_repository.dart";
import "../data/models/customer.dart";

final customerListProvider =
    StateNotifierProvider<CustomerListNotifier, AsyncValue<List<Customer>>>(
      (ref) => CustomerListNotifier(ref.watch(adminRepositoryProvider)),
    );

// Her filterType için ayrı provider instance'ı
final customerListProviderForFilter = StateNotifierProvider.family<
    CustomerListNotifier, AsyncValue<List<Customer>>, String>(
  (ref, filterTypeKey) => CustomerListNotifier(ref.watch(adminRepositoryProvider)),
);

class CustomerListNotifier extends StateNotifier<AsyncValue<List<Customer>>> {
  CustomerListNotifier(this._repository) : super(const AsyncValue.loading());

  final AdminRepository _repository;
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
    print("   Filters: search=$_search, phoneSearch=$_phoneSearch, createdAtFrom=$_createdAtFrom, createdAtTo=$_createdAtTo, hasOverduePayment=$_hasOverduePayment, hasUpcomingMaintenance=$_hasUpcomingMaintenance");

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
      print("✅ fetchCustomers başarılı, ${customers.length} müşteri döndü");
      state = AsyncValue.data(customers);
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
    final newPhoneSearch = phoneSearch == null ? null : (phoneSearch.isEmpty ? null : phoneSearch);
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
    print("   newMaintenance=$newMaintenance, _hasUpcomingMaintenance=$_hasUpcomingMaintenance");
    print("   newSearch=$newSearch, _search=$_search");
    print("   newPhoneSearch=$newPhoneSearch, _phoneSearch=$_phoneSearch");
    print("   newCreatedAtFrom=$newCreatedAtFrom, _createdAtFrom=$_createdAtFrom");
    print("   newCreatedAtTo=$newCreatedAtTo, _createdAtTo=$_createdAtTo");

    // İlk yüklemede veya filtre değiştiğinde refresh yap
    final shouldRefresh = !_initialized ||
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
      
      print("✅ Refresh tamamlandı, müşteri sayısı: ${state.valueOrNull?.length ?? 0}");
    } else {
      print("⏭️ Filter değişmedi, refresh atlandı");
    }
  }
}
