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
    StateNotifierProvider<
      PersonnelNotificationsNotifier,
      List<PersonnelNotification>
    >(PersonnelNotificationsNotifier.new);

class PersonnelNotificationsNotifier
    extends StateNotifier<List<PersonnelNotification>> {
  PersonnelNotificationsNotifier(this.ref) : super([]) {
    _listenRealtime();
  }

  final Ref ref;

  void _listenRealtime() {
    ref.listen<sio.Socket?>(socketClientProvider, (previous, next) {
      previous?.off("notification", _handleNotification);
      if (next != null) {
        debugPrint("🔔 Setting up notification listener for socket");
        next.on("notification", _handleNotification);
        // Also listen for connection events
        next.on("connect", (_) {
          debugPrint("✅ Notification listener: Socket connected");
        });
        next.on("disconnect", (_) {
          debugPrint("❌ Notification listener: Socket disconnected");
        });
      } else {
        debugPrint("⚠️ Notification listener: Socket is null");
      }
    });
  }

  void _handleNotification(dynamic data) {
    try {
      debugPrint("📬 Received notification: $data");
      final map = data as Map<String, dynamic>? ?? {};
      
      // Generate unique ID if not provided
      if (map["id"] == null) {
        map["id"] = DateTime.now().millisecondsSinceEpoch.toString();
      }
      
      // Extract data from nested data field if present
      if (map["data"] != null && map["data"] is Map) {
        final dataMap = map["data"] as Map<String, dynamic>;
        if (dataMap["jobId"] != null) {
          map["jobId"] = dataMap["jobId"];
        }
        // Map notification type from data.type to notification type
        if (dataMap["type"] != null) {
          final dataType = dataMap["type"] as String;
          // Convert "job_assigned" -> "job", "job_started" -> "job", etc.
          if (dataType.startsWith("job_")) {
            map["type"] = "job";
          } else {
            map["type"] = dataType;
          }
        }
      }
      
      // Ensure receivedAt is set
      if (map["receivedAt"] == null) {
        map["receivedAt"] = DateTime.now().toIso8601String();
      }
      
      // Ensure title and body are present
      if (map["title"] == null) {
        map["title"] = "Yeni Bildirim";
      }
      if (map["body"] == null) {
        map["body"] = "";
      }
      
      debugPrint("📬 Processed notification map: $map");
      final notification = PersonnelNotification.fromJson(map);
      debugPrint("✅ Added notification: ${notification.title} - ${notification.body}");
      state = [notification, ...state];
    } catch (error, stackTrace) {
      debugPrint("❌ Failed to handle notification: $error");
      debugPrint("Stack trace: $stackTrace");
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
