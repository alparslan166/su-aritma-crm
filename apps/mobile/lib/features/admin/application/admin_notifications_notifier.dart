import "package:flutter/foundation.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:socket_io_client/socket_io_client.dart" as sio;

import "../../../core/realtime/socket_client.dart";

final adminNotificationsProvider =
    AutoDisposeNotifierProvider<
      AdminNotificationsNotifier,
      List<AdminNotification>
    >(AdminNotificationsNotifier.new);

class AdminNotificationsNotifier
    extends AutoDisposeNotifier<List<AdminNotification>> {
  @override
  List<AdminNotification> build() {
    debugPrint("📢 AdminNotificationsNotifier: build() called");
    _listenSocket();
    return const [];
  }

  void _listenSocket() {
    // Get current socket and setup listeners immediately
    final currentSocket = ref.read(socketClientProvider);
    if (currentSocket != null) {
      _setupSocketListeners(currentSocket);
    }
    
    // Listen for socket changes
    ref.listen<sio.Socket?>(socketClientProvider, (previous, next) {
      debugPrint("📢 Socket changed: previous=${previous != null}, next=${next != null}");
      if (previous != null) {
        previous.off("notification", _handleNotification);
        previous.off("maintenance-reminder", _handleMaintenanceReminder);
      }
      if (next != null) {
        _setupSocketListeners(next);
      }
    });
  }
  
  void _setupSocketListeners(sio.Socket socket) {
    debugPrint("📢 Setting up socket listeners for notifications");
    socket.on("notification", _handleNotification);
    socket.on("maintenance-reminder", _handleMaintenanceReminder);
  }

  void _handleNotification(dynamic data) {
    if (data is! Map) return;
    final notification = AdminNotification.fromJson(
      Map<String, dynamic>.from(data),
    );
    _prepend(notification);
  }

  void _handleMaintenanceReminder(dynamic data) {
    if (data is! Map) return;
    final map = Map<String, dynamic>.from(data);
    final title = map["jobTitle"] as String? ?? "Bakım hatırlatması";
    final days = map["daysUntilDue"] as int?;
    final statusText = days == null
        ? "Bakım planı güncellendi"
        : days <= 0
        ? "Bakım süresi aşıldı"
        : "$days gün kaldı";
    final notification = AdminNotification(
      title: title,
      body: statusText,
      type: "maintenance",
      receivedAt: DateTime.now(),
      meta: map,
    );
    _prepend(notification);
  }

  void _prepend(AdminNotification notification) {
    final updated = [notification, ...state];
    state = updated.take(50).toList();
  }

  void clear() {
    state = const [];
  }
}

class AdminNotification {
  AdminNotification({
    required this.title,
    required this.body,
    required this.receivedAt,
    required this.type,
    this.meta,
  });

  final String title;
  final String body;
  final DateTime receivedAt;
  final String type;
  final Map<String, dynamic>? meta;

  factory AdminNotification.fromJson(Map<String, dynamic> json) {
    final data = json["data"];
    final meta = data is Map<String, dynamic> ? data : null;
    return AdminNotification(
      title: json["title"] as String? ?? "Bildirim",
      body: json["body"] as String? ?? "",
      type: meta?["type"] as String? ?? "general",
      receivedAt: DateTime.now(),
      meta: meta,
    );
  }
}
