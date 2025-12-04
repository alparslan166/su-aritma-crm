import "package:flutter/material.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";

import "core/notifications/push_notification_service.dart";
import "core/realtime/socket_client.dart";
import "core/session/session_provider.dart";
import "core/theme/app_theme.dart";
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

    // Initialize push notifications on app start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      pushService.initialize().catchError((error) {
        debugPrint("Push notification initialization error: $error");
      });
    });

    // Subscribe/unsubscribe to role-based topics when session changes
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
