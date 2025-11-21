import "package:flutter/material.dart";
import "package:go_router/go_router.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:intl/intl.dart";
import "package:mobile/widgets/empty_state.dart";

import "../../application/personnel_notifications_notifier.dart";

class PersonnelNotificationsView extends ConsumerWidget {
  const PersonnelNotificationsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(personnelNotificationsProvider);
    final notifier = ref.read(personnelNotificationsProvider.notifier);

    if (notifications.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              EmptyState(
                icon: Icons.notifications_none,
                title: "Henüz bildirim yok",
                subtitle: "Yeni iş atandığında burada göreceksiniz.",
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: notifier.clear,
            icon: const Icon(Icons.delete_sweep),
            label: const Text("Tümünü temizle"),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return RepaintBoundary(
                child: _NotificationTile(notification: notification),
              );
            },
            separatorBuilder: (_, __) => const Divider(),
            itemCount: notifications.length,
            cacheExtent: 500,
            addAutomaticKeepAlives: false,
            addRepaintBoundaries: true,
          ),
        ),
      ],
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification});

  final PersonnelNotification notification;

  IconData get _icon {
    switch (notification.type) {
      case "job":
        return Icons.work_outline;
      case "maintenance":
        return Icons.build_circle;
      default:
        return Icons.notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat("dd MMM HH:mm");
    return ListTile(
      leading: Icon(_icon, color: Theme.of(context).colorScheme.primary),
      title: Text(notification.title),
      subtitle: Text(notification.body),
      trailing: Text(
        formatter.format(notification.receivedAt),
        style: Theme.of(context).textTheme.labelSmall,
      ),
      onTap: notification.jobId != null
          ? () => GoRouter.of(context).pushNamed(
                "personnel-job-detail",
                pathParameters: {"id": notification.jobId!},
              )
          : null,
    );
  }
}

