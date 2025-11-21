import "package:hooks_riverpod/hooks_riverpod.dart";

import "../data/admin_repository.dart";
import "../data/models/personnel.dart";

final personnelListProvider =
    AutoDisposeAsyncNotifierProvider<PersonnelListNotifier, List<Personnel>>(
      PersonnelListNotifier.new,
    );

class PersonnelListNotifier extends AutoDisposeAsyncNotifier<List<Personnel>> {
  @override
  Future<List<Personnel>> build() {
    return _load();
  }

  Future<List<Personnel>> _load() async {
    final repository = ref.read(adminRepositoryProvider);
    return repository.fetchPersonnel();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }
}
