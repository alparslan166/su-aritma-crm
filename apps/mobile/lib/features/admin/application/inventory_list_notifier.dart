import "package:dio/dio.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";

import "../../../core/network/api_client.dart";
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
    // Use apiClientProvider directly - it sends correct headers for both admin and personnel
    final client = ref.read(apiClientProvider);
    try {
      final response = await client.get("/inventory");
      final items = response.data["data"] as List<dynamic>? ?? [];
      return items
          .map((e) => InventoryItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      // If unauthorized or forbidden, return empty list (personnel might not have access)
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        return [];
      }
      rethrow;
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }
}
