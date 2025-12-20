import "package:flutter/material.dart";
import "package:go_router/go_router.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:intl/intl.dart";
import "package:mobile/widgets/admin_app_bar.dart";
import "package:mobile/widgets/empty_state.dart";

import "../../application/admin_notifications_notifier.dart";

class NotificationsView extends ConsumerWidget {
  const NotificationsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(adminNotificationsProvider);
    final notifier = ref.read(adminNotificationsProvider.notifier);

    return Scaffold(
      appBar: const AdminAppBar(title: Text("Bildirimler")),
      body: notifications.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    EmptyState(
                      icon: Icons.notifications_none,
                      title: "Henüz bildirim yok",
                      subtitle:
                          "İş ve bakım olayları gerçekleştiğinde burada göreceksiniz.",
                    ),
                  ],
                ),
              ),
            )
          : Column(
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
    ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification});

  final AdminNotification notification;

  IconData get _icon {
    switch (notification.type) {
      case "maintenance":
        return Icons.build_circle;
      case "maintenance-reminder":
        return Icons.warning;
      case "job":
      case "job_started":
      case "job_completed":
      case "job_status_updated":
        return Icons.work_outline;
      case "customer_created":
        return Icons.person_add;
      default:
        return Icons.notifications;
    }
  }

  String? get _jobId {
    return notification.meta?["jobId"] as String?;
  }

  String? get _customerId {
    return notification.meta?["customerId"] as String?;
  }

  void _handleTap(BuildContext context) {
    final jobId = _jobId;
    final customerId = _customerId;
    final type = notification.type;

    if (jobId != null && jobId.isNotEmpty) {
      // Navigate to job detail
      context.push("/admin/jobs/$jobId");
    } else if (customerId != null && customerId.isNotEmpty) {
      // Navigate to customer detail
      context.push("/admin/customers/$customerId");
    } else if (type == "maintenance" || type == "maintenance-reminder") {
      // Navigate to maintenance view
      context.go("/admin/maintenance");
    }
  }

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat("dd MMM HH:mm");
    final isClickable = _jobId != null || _customerId != null || 
        notification.type == "maintenance" || notification.type == "maintenance-reminder";
    
    return ListTile(
      leading: Icon(_icon, color: Theme.of(context).colorScheme.primary),
      title: Text(notification.title),
      subtitle: Text(notification.body),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formatter.format(notification.receivedAt),
            style: Theme.of(context).textTheme.labelSmall,
          ),
          if (isClickable) ...[
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right,
              size: 16,
              color: Colors.grey.shade400,
            ),
          ],
        ],
      ),
      onTap: isClickable ? () => _handleTap(context) : null,
    );
  }
}
