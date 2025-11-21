import "package:hooks_riverpod/hooks_riverpod.dart";

import "../data/admin_repository.dart";
import "../data/models/operation.dart";

final operationListProvider = StateNotifierProvider<OperationListNotifier, AsyncValue<List<Operation>>>(
  (ref) => OperationListNotifier(ref.watch(adminRepositoryProvider)),
);

class OperationListNotifier extends StateNotifier<AsyncValue<List<Operation>>> {
  OperationListNotifier(this._repository) : super(const AsyncValue.loading()) {
    refresh();
  }

  final AdminRepository _repository;
  bool _activeOnly = true;

  Future<void> refresh({bool? activeOnly}) async {
    _activeOnly = activeOnly ?? _activeOnly;
    state = const AsyncValue.loading();
    try {
      final operations = await _repository.fetchOperations(activeOnly: _activeOnly);
      state = AsyncValue.data(operations);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
}

