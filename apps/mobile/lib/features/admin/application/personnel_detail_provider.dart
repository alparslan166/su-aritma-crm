import "package:hooks_riverpod/hooks_riverpod.dart";

import "../data/admin_repository.dart";
import "../data/models/personnel.dart";

final personnelDetailProvider =
    AutoDisposeFutureProviderFamily<Personnel, String>((ref, id) async {
      final repo = ref.read(adminRepositoryProvider);
      return repo.fetchPersonnelDetail(id);
    });
