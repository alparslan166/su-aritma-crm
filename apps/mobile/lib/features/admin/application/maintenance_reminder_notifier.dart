import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:socket_io_client/socket_io_client.dart" as sio;

import "../../../core/realtime/socket_client.dart";
import "../data/admin_repository.dart";
import "../data/models/maintenance_reminder.dart";

final maintenanceRemindersProvider =
    AutoDisposeAsyncNotifierProvider<
      MaintenanceReminderNotifier,
      List<MaintenanceReminder>
    >(MaintenanceReminderNotifier.new);

class MaintenanceReminderNotifier
    extends AutoDisposeAsyncNotifier<List<MaintenanceReminder>> {
  @override
  Future<List<MaintenanceReminder>> build() {
    _listenRealtime();
    return _load();
  }

  void _listenRealtime() {
    ref.listen<sio.Socket?>(socketClientProvider, (previous, next) {
      previous?.off("maintenance-reminder", _onEvent);
      next?.on("maintenance-reminder", _onEvent);
    });
  }

  void _onEvent(dynamic _) {
    ref.invalidateSelf();
  }

  Future<List<MaintenanceReminder>> _load() async {
    final repo = ref.read(adminRepositoryProvider);
    return repo.fetchMaintenanceReminders();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }
}
