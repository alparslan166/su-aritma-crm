import "package:flutter/material.dart";
import "package:flutter_hooks/flutter_hooks.dart";
import "package:flutter_localizations/flutter_localizations.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";

import "core/notifications/push_notification_service.dart";
import "core/realtime/socket_client.dart";
import "core/session/session_provider.dart";
import "core/theme/app_theme.dart";
import "features/admin/application/admin_notifications_notifier.dart";
import "features/admin/data/admin_repository.dart";
import "features/personnel/application/personnel_notifications_notifier.dart";
import "routing/app_router.dart";
import "core/subscription/subscription_lock_provider.dart";

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
    // Also check subscription on admin login to show notices and enforce lock.
    useEffect(() {
      ref.listen<AuthSession?>(authSessionProvider, (previous, next) async {
        if (previous != null && previous.role != next?.role) {
          pushService.unsubscribeFromRoleTopic(previous.role.name).catchError((
            error,
          ) {
            debugPrint("Failed to unsubscribe from topic: $error");
          });
        }

        if (next != null) {
          pushService.subscribeToRoleTopic(next.role.name).catchError((error) {
            debugPrint("Failed to subscribe to topic: $error");
          });
          pushService.registerTokenWithBackend().catchError((error) {
            debugPrint("Failed to register token after login: $error");
          });

          // Admin subscription gating (trial notice, last 3 days warning, lock)
          if (next.role.name == "admin") {
            final repo = ref.read(adminRepositoryProvider);
            try {
              final subscription = await repo.getSubscription();
              final lockRequired =
                  subscription?["lockRequired"] as bool? ?? false;
              ref.read(subscriptionLockRequiredProvider.notifier).state =
                  lockRequired;

              final navContext = ref
                  .read(appRouterProvider)
                  .routerDelegate
                  .navigatorKey
                  .currentContext;
              if (navContext == null || !navContext.mounted) return;

              // One-time trial started notice
              final showTrialNotice =
                  subscription?["shouldShowTrialStartedNotice"] as bool? ??
                  false;
              if (showTrialNotice) {
                await showDialog<void>(
                  context: navContext,
                  builder: (ctx) => AlertDialog(
                    title: const Text("Deneme süresi başladı"),
                    content: const Text(
                      "30 günlük deneme süreniz başladı. Detayları profil sayfasında görebilirsiniz.",
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text("Tamam"),
                      ),
                    ],
                  ),
                );
                // Mark as seen in backend
                await repo.markTrialNoticeSeen().catchError((e) {
                  debugPrint("Failed to mark trial notice seen: $e");
                });
              }

              // Last 3 days warning (shown every login when <=3 days)
              final showExpiryWarning =
                  subscription?["shouldShowExpiryWarning"] as bool? ?? false;
              final daysRemaining = subscription?["daysRemaining"] as int?;
              if (showExpiryWarning && daysRemaining != null) {
                await showDialog<void>(
                  context: navContext,
                  builder: (ctx) => AlertDialog(
                    title: const Text("Abonelik uyarısı"),
                    content: Text(
                      "Aboneliğinizin bitmesine $daysRemaining gün kaldı.",
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text("Tamam"),
                      ),
                    ],
                  ),
                );
              }
            } catch (e) {
              // If subscription cannot be fetched, don't lock.
              debugPrint("Subscription check failed: $e");
              ref.read(subscriptionLockRequiredProvider.notifier).state = false;
            }
          } else {
            // Personnel doesn't use subscription lock
            ref.read(subscriptionLockRequiredProvider.notifier).state = false;
          }
        } else if (previous != null) {
          pushService.unsubscribeFromRoleTopic(previous.role.name).catchError((
            error,
          ) {
            debugPrint("Failed to unsubscribe from topic: $error");
          });
          ref.read(subscriptionLockRequiredProvider.notifier).state = false;
        }
      });
      return null;
    }, const []);

    return MaterialApp.router(
      title: "Su Arıtma",
      theme: buildAppTheme(),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      locale: const Locale("tr", "TR"),
      supportedLocales: const [
        Locale("tr", "TR"),
        Locale("en", "US"),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
