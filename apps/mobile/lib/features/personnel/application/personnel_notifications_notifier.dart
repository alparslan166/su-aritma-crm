import "package:flutter/foundation.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:socket_io_client/socket_io_client.dart" as sio;

import "../../../core/realtime/socket_client.dart";
import "../data/personnel_repository.dart";

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
    // Support both API format and Socket.IO format
    final id = json["id"] as String? ?? "";
    final title = json["title"] as String? ?? "Bildirim";
    final body = json["body"] as String? ?? "";
    final type = json["type"] as String? ?? "job";
    
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

    // jobId can be in meta/data or directly in json
    String? jobId = json["jobId"] as String?;
    if (jobId == null && json["meta"] is Map<String, dynamic>) {
      final meta = json["meta"] as Map<String, dynamic>;
      jobId = meta["jobId"] as String?;
    }
    if (jobId == null && json["data"] is Map<String, dynamic>) {
      final data = json["data"] as Map<String, dynamic>;
      jobId = data["jobId"] as String?;
    }

    return PersonnelNotification(
      id: id,
      title: title,
      body: body,
      type: type,
      receivedAt: receivedAt,
      jobId: jobId,
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
    debugPrint("📢 PersonnelNotificationsNotifier: initialized");
    _loadNotifications();
    _listenRealtime();
  }

  final Ref ref;

  Future<void> _loadNotifications() async {
    try {
      debugPrint("📢 Loading personnel notifications from API...");
      final repository = ref.read(personnelRepositoryProvider);
      final notifications = await repository.fetchNotifications();
      final formatted = notifications
          .map((n) => PersonnelNotification.fromJson(n))
          .toList();
      state = formatted;
      debugPrint("📢 Loaded ${formatted.length} personnel notifications from API");
    } catch (e) {
      debugPrint("❌ Failed to load personnel notifications: $e");
      // Don't set state on error - keep existing notifications
    }
  }

  Future<void> refresh() async {
    await _loadNotifications();
  }

  void _listenRealtime() {
    // Get current socket and setup listeners immediately
    final currentSocket = ref.read(socketClientProvider);
    if (currentSocket != null) {
      _setupSocketListeners(currentSocket);
    }
    
    // Watch socket provider and setup listener when socket is available
    ref.listen<sio.Socket?>(socketClientProvider, (previous, next) {
      debugPrint("📢 Socket changed: previous=${previous != null}, next=${next != null}");
      // Remove listener from previous socket
      if (previous != null) {
        previous.off("notification", _handleNotification);
        previous.off("connect", _onSocketConnect);
        previous.off("disconnect", _onSocketDisconnect);
        debugPrint("🔔 Removed notification listener from previous socket");
      }

      if (next != null) {
        _setupSocketListeners(next);
      } else {
        debugPrint("⚠️ Notification listener: Socket is null");
      }
    });
  }
  
  void _setupSocketListeners(sio.Socket socket) {
    debugPrint("🔔 Setting up notification listener for socket");
    // Setup listeners
    socket.on("notification", _handleNotification);
    socket.on("connect", _onSocketConnect);
    socket.on("disconnect", _onSocketDisconnect);

    // If socket is already connected, log it
    if (socket.connected) {
      debugPrint("✅ Notification listener: Socket already connected");
    }
  }

  void _onSocketConnect(_) {
    debugPrint("✅ Notification listener: Socket connected");
  }

  void _onSocketDisconnect(_) {
    debugPrint("❌ Notification listener: Socket disconnected");
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
      debugPrint(
        "✅ Added notification: ${notification.title} - ${notification.body}",
      );
      _addNotification(notification);
    } catch (error, stackTrace) {
      debugPrint("❌ Failed to handle notification: $error");
      debugPrint("Stack trace: $stackTrace");
      // Ignore invalid notifications
    }
  }

  void _addNotification(PersonnelNotification notification) {
    // Check if notification already exists (avoid duplicates)
    final exists = state.any((n) => n.id == notification.id);
    if (exists) {
      debugPrint("📢 Notification already exists, skipping: ${notification.id}");
      return;
    }
    final updated = [notification, ...state];
    // Keep last 200 notifications (increased for persistence)
    state = updated.take(200).toList();
  }

  /// Public method to add notification (for push notifications)
  void addNotification(PersonnelNotification notification) {
    _addNotification(notification);
  }

  void clear() {
    // Don't clear - notifications should persist
    // Instead, just refresh from API
    refresh();
  }

  void remove(String id) {
    state = state.where((n) => n.id != id).toList();
  }
}
