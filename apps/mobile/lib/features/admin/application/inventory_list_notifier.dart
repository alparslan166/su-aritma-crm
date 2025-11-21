import "package:hooks_riverpod/hooks_riverpod.dart";

import "../data/admin_repository.dart";
import "../data/models/inventory_item.dart";

final inventoryListProvider =
    AutoDisposeAsyncNotifierProvider<
      InventoryListNotifier,
      List<InventoryItem>
    >(InventoryListNotifier.new);

class InventoryListNotifier
    extends AutoDisposeAsyncNotifier<List<InventoryItem>> {
  @override
  Future<List<InventoryItem>> build() {
    return _load();
  }

  Future<List<InventoryItem>> _load() async {
    final repository = ref.read(adminRepositoryProvider);
    return repository.fetchInventory();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }
}
