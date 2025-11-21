import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:socket_io_client/socket_io_client.dart" as sio;

import "../../../core/realtime/socket_client.dart";

class PersonnelNotification {
  PersonnelNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.receivedAt,
    this.jobId,
  });

  final String id;
  final String title;
  final String body;
  final String type;
  final DateTime receivedAt;
  final String? jobId;

  factory PersonnelNotification.fromJson(Map<String, dynamic> json) {
    return PersonnelNotification(
      id: json["id"] as String? ?? "",
      title: json["title"] as String? ?? "",
      body: json["body"] as String? ?? "",
      type: json["type"] as String? ?? "job",
      receivedAt: json["receivedAt"] != null
          ? DateTime.parse(json["receivedAt"] as String)
          : DateTime.now(),
      jobId: json["jobId"] as String?,
    );
  }
}

final personnelNotificationsProvider =
    StateNotifierProvider<PersonnelNotificationsNotifier, List<PersonnelNotification>>(
  PersonnelNotificationsNotifier.new,
);

class PersonnelNotificationsNotifier extends StateNotifier<List<PersonnelNotification>> {
  PersonnelNotificationsNotifier(this.ref) : super([]) {
    _listenRealtime();
  }

  final Ref ref;

  void _listenRealtime() {
    ref.listen<sio.Socket?>(socketClientProvider, (previous, next) {
      previous?.off("notification", _handleNotification);
      next?.on("notification", _handleNotification);
    });
  }

  void _handleNotification(dynamic data) {
    try {
      final map = data as Map<String, dynamic>? ?? {};
      final notification = PersonnelNotification.fromJson(map);
      state = [notification, ...state];
    } catch (error) {
      // Ignore invalid notifications
    }
  }

  void clear() {
    state = [];
  }

  void remove(String id) {
    state = state.where((n) => n.id != id).toList();
  }
}

