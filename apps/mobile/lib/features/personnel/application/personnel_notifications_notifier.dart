import "package:flutter/foundation.dart";
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
      // Generate unique ID if not provided
      if (map["id"] == null) {
        map["id"] = DateTime.now().millisecondsSinceEpoch.toString();
      }
      // Extract jobId from data if present
      if (map["data"] != null && map["data"] is Map) {
        final dataMap = map["data"] as Map<String, dynamic>;
        if (dataMap["jobId"] != null) {
          map["jobId"] = dataMap["jobId"];
        }
        if (dataMap["type"] != null) {
          map["type"] = dataMap["type"];
        }
      }
      final notification = PersonnelNotification.fromJson(map);
      state = [notification, ...state];
    } catch (error) {
      debugPrint("Failed to handle notification: $error");
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

