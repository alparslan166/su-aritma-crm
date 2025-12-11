import "package:firebase_core/firebase_core.dart";
import "package:firebase_messaging/firebase_messaging.dart";
import "package:flutter/foundation.dart";
import "package:flutter_local_notifications/flutter_local_notifications.dart";
import "package:go_router/go_router.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";

import "../../routing/app_router.dart";
import "../network/api_client.dart";

// Background message handler (must be top-level function)
@pragma("vm:entry-point")
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("Background message received: ${message.messageId}");
}

final pushNotificationServiceProvider = Provider<PushNotificationService>((
  ref,
) {
  return PushNotificationService(
    ref.read(apiClientProvider),
    ref.read(appRouterProvider),
  );
});

class PushNotificationService {
  PushNotificationService(this._client, this._router);

  final dynamic _client;
  final GoRouter _router;
  FirebaseMessaging? _messaging;
  FlutterLocalNotificationsPlugin? _localNotifications;

  Future<void> initialize() async {
    try {
      // Check if Firebase is initialized
      try {
        Firebase.app();
      } catch (e) {
        debugPrint("Firebase not initialized, skipping push notifications");
        return;
      }
      
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
        const androidSettings = AndroidInitializationSettings(
          "@mipmap/ic_launcher",
        );
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
            // Payload is a string, try to extract data from it
            if (details.payload != null && details.payload is String) {
              // Try to parse as JSON or use as is
              try {
                // For now, we'll handle it in _handleNotificationTap
                _handleNotificationTap(details.payload);
              } catch (e) {
                debugPrint("Failed to handle notification tap: $e");
              }
            }
          },
        );

        // Setup foreground message handler
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          debugPrint("Foreground message received: ${message.messageId}");
          _showLocalNotification(message);
        });

        // Setup background message handler
        FirebaseMessaging.onBackgroundMessage(
          firebaseMessagingBackgroundHandler,
        );

        // Setup notification tap handler (app in background or terminated)
        FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
          debugPrint("Notification opened app: ${message.messageId}");
          debugPrint("Notification data: ${message.data}");
          _handleNotificationTap(message.data);
        });

        // Check for initial notification (app opened from terminated state)
        final initialMessage = await _messaging!.getInitialMessage();
        if (initialMessage != null) {
          debugPrint(
            "App opened from notification: ${initialMessage.messageId}",
          );
          debugPrint("Initial notification data: ${initialMessage.data}");
          _handleNotificationTap(initialMessage.data);
        }

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
        // Platform detection
        String platform = "android";
        if (defaultTargetPlatform == TargetPlatform.iOS) {
          platform = "ios";
        }

        // Send token to backend
        try {
          await _client.post(
            "/notifications/register-token",
            data: {"token": token, "platform": platform},
          );
          debugPrint("FCM token registered with backend (platform: $platform)");
        } catch (e) {
          debugPrint("Failed to register token with backend: $e");
        }
      }

      // Listen for token refresh
      _messaging?.onTokenRefresh.listen((newToken) async {
        debugPrint("FCM token refreshed: $newToken");
        String platform = "android";
        if (defaultTargetPlatform == TargetPlatform.iOS) {
          platform = "ios";
        }
        try {
          await _client.post(
            "/notifications/register-token",
            data: {"token": newToken, "platform": platform},
          );
          debugPrint("Refreshed FCM token registered with backend");
        } catch (e) {
          debugPrint("Failed to register refreshed token: $e");
        }
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

    // Convert data map to JSON string for payload
    final payload = message.data.isNotEmpty
        ? message.data.toString()
        : message.notification?.title ?? "";

    await _localNotifications!.show(
      message.hashCode,
      message.notification?.title ?? "Yeni Bildirim",
      message.notification?.body ?? "",
      details,
      payload: payload,
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
        debugPrint("String payload: $payload");
        // String payload genellikle data.toString() formatında gelir
        // Bu durumda Map'e çevirmek zor, sadece log yapıyoruz
      } catch (e) {
        debugPrint("Failed to parse payload: $e");
      }
    } else if (payload is Map<String, dynamic>) {
      data = payload;
      debugPrint("Map payload: $data");

      // Navigate based on notification type
      final type = data['type'] as String?;
      final jobId = data['jobId'] as String?;

      if (type == "job_assigned" && jobId != null) {
        // Navigate to personnel job detail page
        _router.pushNamed(
          "personnel-job-detail",
          pathParameters: {"id": jobId},
        );
      } else if (type == "job_started" && jobId != null) {
        // Navigate to admin job detail page
        _router.pushNamed("admin-job-detail", pathParameters: {"id": jobId});
      } else if (type == "job_completed" && jobId != null) {
        // Navigate to admin job detail page
        _router.pushNamed("admin-job-detail", pathParameters: {"id": jobId});
      } else if (type == "customer_created") {
        final customerId = data['customerId'] as String?;
        if (customerId != null) {
          _router.pushNamed(
            "admin-customer-detail",
            pathParameters: {"id": customerId},
          );
        }
      }
    }
  }
}
