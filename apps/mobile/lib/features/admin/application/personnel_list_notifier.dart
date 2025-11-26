import "package:hooks_riverpod/hooks_riverpod.dart";

import "../data/admin_repository.dart";
import "../data/models/personnel.dart";

final personnelListProvider =
    AutoDisposeAsyncNotifierProvider<PersonnelListNotifier, List<Personnel>>(
      PersonnelListNotifier.new,
    );

class PersonnelListNotifier extends AutoDisposeAsyncNotifier<List<Personnel>> {
  String? _search;
  String? _phoneSearch;
  DateTime? _createdAtFrom;
  DateTime? _createdAtTo;

  @override
  Future<List<Personnel>> build() {
    return _load();
  }

  Future<List<Personnel>> _load() async {
    final repository = ref.read(adminRepositoryProvider);
    return repository.fetchPersonnel(
      search: _search,
      phoneSearch: _phoneSearch,
      createdAtFrom: _createdAtFrom,
      createdAtTo: _createdAtTo,
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }

  void filter({
    String? search,
    String? phoneSearch,
    DateTime? createdAtFrom,
    DateTime? createdAtTo,
  }) {
    _search = search;
    _phoneSearch = phoneSearch;
    _createdAtFrom = createdAtFrom;
    _createdAtTo = createdAtTo;
    refresh();
  }
}
