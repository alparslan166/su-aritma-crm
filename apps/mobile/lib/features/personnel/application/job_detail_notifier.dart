import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:socket_io_client/socket_io_client.dart" as sio;

import "../../../core/realtime/socket_client.dart";
import "../data/models/personnel_job.dart";
import "../data/personnel_repository.dart";

final personnelJobDetailProvider =
    AutoDisposeAsyncNotifierProviderFamily<
      PersonnelJobDetailNotifier,
      PersonnelJobDetail,
      String
    >(PersonnelJobDetailNotifier.new);

class PersonnelJobDetailNotifier
    extends AutoDisposeFamilyAsyncNotifier<PersonnelJobDetail, String> {
  @override
  Future<PersonnelJobDetail> build(String arg) {
    _listenRealtime();
    return _load(arg);
  }

  void _listenRealtime() {
    ref.listen<sio.Socket?>(socketClientProvider, (previous, next) {
      previous?.off("job-status", _handleStatus);
      next?.on("job-status", _handleStatus);
    });
  }

  void _handleStatus(dynamic data) {
    if (data is Map && data["id"] == arg) {
      ref.invalidateSelf();
    }
  }

  Future<PersonnelJobDetail> _load(String id) async {
    final repository = ref.read(personnelRepositoryProvider);
    return repository.fetchJobDetail(id);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _load(arg));
  }
}
