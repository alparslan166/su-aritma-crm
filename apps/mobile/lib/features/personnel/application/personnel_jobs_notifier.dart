import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:socket_io_client/socket_io_client.dart" as sio;

import "../../../core/realtime/socket_client.dart";
import "../data/models/personnel_job.dart";
import "../data/personnel_repository.dart";

final personnelJobsProvider =
    AutoDisposeAsyncNotifierProvider<PersonnelJobsNotifier, List<PersonnelJob>>(
      PersonnelJobsNotifier.new,
    );

class PersonnelJobsNotifier
    extends AutoDisposeAsyncNotifier<List<PersonnelJob>> {
  @override
  Future<List<PersonnelJob>> build() {
    _listenRealtime();
    return _load();
  }

  void _listenRealtime() {
    ref.listen<sio.Socket?>(socketClientProvider, (previous, next) {
      previous?.off("job-status", _handleStatus);
      next?.on("job-status", _handleStatus);
    });
  }

  void _handleStatus(dynamic _) {
    ref.invalidateSelf();
  }

  Future<List<PersonnelJob>> _load() async {
    final repository = ref.read(personnelRepositoryProvider);
    return repository.fetchAssignedJobs();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }
}
