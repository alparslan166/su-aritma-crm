import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:socket_io_client/socket_io_client.dart" as sio;

import "../../../core/realtime/socket_client.dart";
import "../data/admin_repository.dart";
import "../data/models/job.dart";

final jobListProvider =
    AutoDisposeAsyncNotifierProvider<JobListNotifier, List<Job>>(
      JobListNotifier.new,
    );

class JobListNotifier extends AutoDisposeAsyncNotifier<List<Job>> {
  @override
  Future<List<Job>> build() {
    _listenSocket();
    return _load();
  }

  Future<List<Job>> _load() async {
    final repository = ref.read(adminRepositoryProvider);
    return repository.fetchJobs();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }

  void _listenSocket() {
    ref.listen<sio.Socket?>(socketClientProvider, (previous, next) {
      previous?.off("job-status", _handleJobStatus);
      next?.on("job-status", _handleJobStatus);
    });
  }

  void _handleJobStatus(dynamic data) {
    // Refresh job list when job status changes
    refresh();
  }
}
