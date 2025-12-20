import "package:flutter/foundation.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:socket_io_client/socket_io_client.dart" as sio;

import "../../../core/realtime/socket_client.dart";
import "../data/admin_repository.dart";

final adminNotificationsProvider =
    StateNotifierProvider<AdminNotificationsNotifier, List<AdminNotification>>(
      AdminNotificationsNotifier.new,
    );

class AdminNotificationsNotifier extends StateNotifier<List<AdminNotification>> {
  AdminNotificationsNotifier(this.ref) : super([]) {
    debugPrint("📢 AdminNotificationsNotifier: initialized");
    _loadNotifications();
    _listenSocket();
  }

  final Ref ref;

  Future<void> _loadNotifications() async {
    try {
      debugPrint("📢 Loading notifications from API...");
      final repository = ref.read(adminRepositoryProvider);
      final notifications = await repository.fetchNotifications();
      final formatted = notifications
          .map((n) => AdminNotification.fromJson(n))
          .toList();
      state = formatted;
      debugPrint("📢 Loaded ${formatted.length} notifications from API");
    } catch (e) {
      debugPrint("❌ Failed to load notifications: $e");
      // Don't set state on error - keep existing notifications
    }
  }

  Future<void> refresh() async {
    await _loadNotifications();
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
    try {
      final notification = AdminNotification.fromJson(
        Map<String, dynamic>.from(data),
      );
      _prepend(notification);
    } catch (e) {
      debugPrint("❌ Failed to parse notification: $e");
    }
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
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      body: statusText,
      type: "maintenance",
      receivedAt: DateTime.now(),
      meta: map,
    );
    _prepend(notification);
  }

  void _prepend(AdminNotification notification) {
    // Check if notification already exists (avoid duplicates)
    final exists = state.any((n) => n.id == notification.id);
    if (exists) {
      debugPrint("📢 Notification already exists, skipping: ${notification.id}");
      return;
    }
    final updated = [notification, ...state];
    // Keep last 200 notifications (increased from 50 for persistence)
    state = updated.take(200).toList();
  }

  /// Public method to add notification (for push notifications)
  void addNotification(AdminNotification notification) {
    _prepend(notification);
  }

  void clear() {
    // Don't clear - notifications should persist
    // Instead, just refresh from API
    refresh();
  }
}

class AdminNotification {
  AdminNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.receivedAt,
    required this.type,
    this.meta,
  });

  final String id;
  final String title;
  final String body;
  final DateTime receivedAt;
  final String type;
  final Map<String, dynamic>? meta;

  factory AdminNotification.fromJson(Map<String, dynamic> json) {
    // Support both API format and Socket.IO format
    final id = json["id"] as String? ?? "";
    final title = json["title"] as String? ?? "Bildirim";
    final body = json["body"] as String? ?? "";
    final type = json["type"] as String? ?? "general";
    
    // receivedAt can come from API or Socket.IO
    DateTime receivedAt;
    if (json["receivedAt"] != null) {
      try {
        receivedAt = DateTime.parse(json["receivedAt"] as String);
      } catch (_) {
        receivedAt = DateTime.now();
      }
    } else {
      receivedAt = DateTime.now();
    }

    // Meta can be in data field (Socket.IO) or directly in json (API)
    Map<String, dynamic>? meta;
    if (json["data"] is Map<String, dynamic>) {
      meta = json["data"] as Map<String, dynamic>;
    } else if (json["meta"] is Map<String, dynamic>) {
      meta = json["meta"] as Map<String, dynamic>;
    } else {
      // Extract meta from json, excluding known fields
      meta = <String, dynamic>{};
      json.forEach((key, value) {
        if (!["id", "title", "body", "type", "receivedAt", "readAt"].contains(key)) {
          meta![key] = value;
        }
      });
      if (meta.isEmpty) meta = null;
    }

    return AdminNotification(
      id: id,
      title: title,
      body: body,
      type: type,
      receivedAt: receivedAt,
      meta: meta,
    );
  }
}
