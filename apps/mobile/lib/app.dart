import "package:flutter/material.dart";
import "package:flutter_hooks/flutter_hooks.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";

import "core/notifications/push_notification_service.dart";
import "core/realtime/socket_client.dart";
import "core/session/session_provider.dart";
import "core/theme/app_theme.dart";
import "features/admin/application/admin_notifications_notifier.dart";
import "features/personnel/application/personnel_notifications_notifier.dart";
import "routing/app_router.dart";

class SuAritmaApp extends HookConsumerWidget {
  const SuAritmaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final pushService = ref.watch(pushNotificationServiceProvider);
    final session = ref.watch(authSessionProvider);

    // Initialize WebSocket connection when user is logged in
    // This ensures socket is connected even if notifications page is not visited
    ref.watch(socketClientProvider);

    // Initialize notification listeners when user is logged in
    // This ensures notifications are received even if notifications page is not visited
    if (session != null && session.role.name == "personnel") {
      ref.watch(personnelNotificationsProvider);
    }

    // Initialize push notifications once on app start
    useEffect(() {
      // microtask to avoid calling initialize during build
      Future<void>(() async {
        try {
          await pushService.initialize();
        } catch (error) {
          debugPrint("Push notification initialization error: $error");
        }
      });
      return null;
    }, const []);

    // Keep in-app notification listeners alive (so panel gets updates even if never opened)
    if (session != null && session.role.name == "admin") {
      ref.watch(adminNotificationsProvider);
    }

    // Subscribe/unsubscribe to role-based topics and (re)register push token after login
    ref.listen<AuthSession?>(authSessionProvider, (previous, next) {
      if (previous != null && previous.role != next?.role) {
        // Unsubscribe from previous role
        pushService.unsubscribeFromRoleTopic(previous.role.name).catchError((
          error,
        ) {
          debugPrint("Failed to unsubscribe from topic: $error");
        });
      }
      if (next != null) {
        // Subscribe to new role
        pushService.subscribeToRoleTopic(next.role.name).catchError((error) {
          debugPrint("Failed to subscribe to topic: $error");
        });
        // After login: register token with backend (needs x-admin-id / x-personnel-id headers)
        pushService.registerTokenWithBackend().catchError((error) {
          debugPrint("Failed to register token after login: $error");
        });
      } else if (previous != null) {
        // Logged out - unsubscribe from previous role
        pushService.unsubscribeFromRoleTopic(previous.role.name).catchError((
          error,
        ) {
          debugPrint("Failed to unsubscribe from topic: $error");
        });
      }
    });

    return MaterialApp.router(
      title: "Su Arıtma",
      theme: buildAppTheme(),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
