import "package:firebase_core/firebase_core.dart";
import "package:firebase_messaging/firebase_messaging.dart";
import "package:flutter/foundation.dart";
import "package:flutter_local_notifications/flutter_local_notifications.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";

import "../network/api_client.dart";

// Background message handler (must be top-level function)
@pragma("vm:entry-point")
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("Background message received: ${message.messageId}");
}

final pushNotificationServiceProvider =
    Provider<PushNotificationService>((ref) {
  return PushNotificationService(ref.read(apiClientProvider));
});

class PushNotificationService {
  PushNotificationService(this._client);

  final dynamic _client;
  FirebaseMessaging? _messaging;
  FlutterLocalNotificationsPlugin? _localNotifications;

  Future<void> initialize() async {
    try {
      _messaging = FirebaseMessaging.instance;

      // Request permissions
      final settings = await _messaging!.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        debugPrint("User granted notification permission");

        // Setup local notifications for foreground messages
        _localNotifications = FlutterLocalNotificationsPlugin();
        const androidSettings = AndroidInitializationSettings("@mipmap/ic_launcher");
        const iosSettings = DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );
        const initSettings = InitializationSettings(
          android: androidSettings,
          iOS: iosSettings,
        );

        await _localNotifications!.initialize(
          initSettings,
          onDidReceiveNotificationResponse: (details) {
            debugPrint("Notification tapped: ${details.payload}");
            // Handle notification tap - navigate based on payload
            _handleNotificationTap(details.payload);
          },
        );

        // Setup foreground message handler
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          debugPrint("Foreground message received: ${message.messageId}");
          _showLocalNotification(message);
        });

        // Setup background message handler
        FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

        // Setup notification tap handler (app in background or terminated)
        FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
          debugPrint("Notification opened app: ${message.messageId}");
          _handleNotificationTap(message.data);
        });

        // Get FCM token and send to backend
        await _registerToken();

        // Subscribe to role-based topics
        await _subscribeToTopics();
      } else {
        debugPrint("User denied notification permission");
      }
    } catch (e) {
      debugPrint("Firebase initialization error: $e");
      // If Firebase is not configured, continue without push notifications
    }
  }

  Future<void> _registerToken() async {
    try {
      final token = await _messaging?.getToken();
      if (token != null) {
        debugPrint("FCM Token: $token");
        // Send token to backend
        try {
          await _client.post("/notifications/register-token", data: {
            "token": token,
          });
          debugPrint("FCM token registered with backend");
        } catch (e) {
          debugPrint("Failed to register token with backend: $e");
        }
      }

      // Listen for token refresh
      _messaging?.onTokenRefresh.listen((newToken) {
        debugPrint("FCM token refreshed: $newToken");
        _client.post("/notifications/register-token", data: {
          "token": newToken,
        }).catchError((e) {
          debugPrint("Failed to register refreshed token: $e");
        });
      });
    } catch (e) {
      debugPrint("Token registration error: $e");
    }
  }

  Future<void> _subscribeToTopics() async {
    try {
      // Subscribe to role-based topics (backend sends to these topics)
      // This will be set dynamically based on user role after login
      debugPrint("Subscribed to notification topics");
    } catch (e) {
      debugPrint("Topic subscription error: $e");
    }
  }

  Future<void> subscribeToRoleTopic(String role) async {
    try {
      final topic = "role-$role";
      await _messaging?.subscribeToTopic(topic);
      debugPrint("Subscribed to topic: $topic");
    } catch (e) {
      debugPrint("Topic subscription error: $e");
    }
  }

  Future<void> unsubscribeFromRoleTopic(String role) async {
    try {
      final topic = "role-$role";
      await _messaging?.unsubscribeFromTopic(topic);
      debugPrint("Unsubscribed from topic: $topic");
    } catch (e) {
      debugPrint("Topic unsubscription error: $e");
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    if (_localNotifications == null) return;

    final androidDetails = AndroidNotificationDetails(
      "job_notifications",
      "İş Bildirimleri",
      channelDescription: "Yeni iş emirleri ve güncellemeleri",
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications!.show(
      message.hashCode,
      message.notification?.title ?? "Yeni Bildirim",
      message.notification?.body ?? "",
      details,
      payload: message.data.toString(),
    );
  }

  void _handleNotificationTap(dynamic payload) {
    if (payload == null) return;
    debugPrint("Handling notification tap with payload: $payload");
    
    // Handle both String and Map payloads
    Map<String, dynamic>? data;
    if (payload is String) {
      // Try to parse JSON string
      try {
        // For now, just log - navigation will be implemented later
        debugPrint("String payload: $payload");
      } catch (e) {
        debugPrint("Failed to parse payload: $e");
      }
    } else if (payload is Map<String, dynamic>) {
      data = payload;
      debugPrint("Map payload: $data");
      // Example: Navigate to job detail page if jobId is in payload
      // final jobId = data['jobId'];
      // if (jobId != null) {
      //   // Navigate to job detail
      // }
    }
  }
}

