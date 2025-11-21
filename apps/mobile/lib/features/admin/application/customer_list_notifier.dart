import "package:hooks_riverpod/hooks_riverpod.dart";

import "../data/admin_repository.dart";
import "../data/models/customer.dart";

final customerListProvider =
    StateNotifierProvider<CustomerListNotifier, AsyncValue<List<Customer>>>(
      (ref) => CustomerListNotifier(ref.watch(adminRepositoryProvider)),
    );

class CustomerListNotifier extends StateNotifier<AsyncValue<List<Customer>>> {
  CustomerListNotifier(this._repository) : super(const AsyncValue.loading());

  final AdminRepository _repository;
  bool _hasOverduePayment = false;
  bool _hasUpcomingMaintenance = false;
  bool _hasOverdueInstallment = false;
  String? _search;
  bool _initialized = false;

  Future<void> refresh({bool showLoading = false}) async {
    // Eğer showLoading true ise loading göster, değilse mevcut data'yı koru
    // Arama sırasında sayfa yenilenmesin, sadece liste güncellensin
    if (showLoading) {
      state = const AsyncValue.loading();
    }
    // showLoading false ise state'i değiştirme, mevcut data korunur

    try {
      final customers = await _repository.fetchCustomers(
        search: _search,
        hasOverduePayment: _hasOverduePayment,
        hasUpcomingMaintenance: _hasUpcomingMaintenance,
        hasOverdueInstallment: _hasOverdueInstallment,
      );
      state = AsyncValue.data(customers);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> filter({
    bool? hasOverduePayment,
    bool? hasUpcomingMaintenance,
    bool? hasOverdueInstallment,
    String? search,
  }) async {
    // null değerler filtrenin kaldırılması anlamına gelir
    final newOverdue = hasOverduePayment;
    final newMaintenance = hasUpcomingMaintenance;
    final newInstallment = hasOverdueInstallment;
    // Search için: null gelirse temizle, boş string gelirse temizle, değer gelirse kullan
    final newSearch = search == null ? null : (search.isEmpty ? null : search);

    // Only refresh if filter actually changed or not initialized yet
    // String karşılaştırması için null-safe kontrol
    final searchChanged = (newSearch ?? "") != (_search ?? "");

    if (!_initialized ||
        newOverdue != _hasOverduePayment ||
        newMaintenance != _hasUpcomingMaintenance ||
        newInstallment != _hasOverdueInstallment ||
        searchChanged) {
      final wasInitialized = _initialized;
      final hasExistingData = state.valueOrNull != null;

      _hasOverduePayment = newOverdue ?? false;
      _hasUpcomingMaintenance = newMaintenance ?? false;
      _hasOverdueInstallment = newInstallment ?? false;
      _search = newSearch;
      _initialized = true;

      // Sadece ilk yüklemede veya manuel refresh'te loading göster
      // Arama değişikliklerinde mevcut data'yı koru, loading gösterme
      await refresh(showLoading: !wasInitialized && !hasExistingData);
    }
  }
}
