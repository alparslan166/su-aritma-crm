import "package:flutter/material.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:intl/intl.dart";
import "package:mobile/widgets/empty_state.dart";

import "../../../../core/error/error_handler.dart";
import "../../application/maintenance_reminder_notifier.dart";
import "../../data/models/maintenance_reminder.dart";

class MaintenanceView extends ConsumerWidget {
  const MaintenanceView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reminders = ref.watch(maintenanceRemindersProvider);
    final notifier = ref.read(maintenanceRemindersProvider.notifier);
    return reminders.when(
      data: (items) {
        if (items.isEmpty) {
          return RefreshIndicator(
            onRefresh: notifier.refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
              children: const [
                SizedBox(height: 120),
                EmptyState(
                  icon: Icons.build_circle_outlined,
                  title: "Aktif bakım hatırlatması yok",
                  subtitle:
                      "Teslimlerde bakım tarihi seçtiğinizde liste oluşacak.",
                ),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: notifier.refresh,
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemCount: items.length,
            cacheExtent: 500,
            addAutomaticKeepAlives: false,
            addRepaintBoundaries: true,
            itemBuilder: (context, index) => RepaintBoundary(
              child: _ReminderCard(reminder: items[index]),
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _ErrorState(
        message: ErrorHandler.getUserFriendlyMessage(error),
        onRetry: () =>
            ref.read(maintenanceRemindersProvider.notifier).refresh(),
      ),
    );
  }
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({required this.reminder});

  final MaintenanceReminder reminder;

  Color _statusColor(BuildContext context) {
    if (reminder.daysUntilDue <= 0) {
      return const Color(0xFFEF4444).withValues(alpha: 0.1);
    }
    if (reminder.daysUntilDue <= 1) {
      return const Color(0xFFF59E0B).withValues(alpha: 0.1);
    }
    if (reminder.daysUntilDue <= 3) {
      return const Color(0xFFF59E0B).withValues(alpha: 0.05);
    }
    return const Color(0xFF2563EB).withValues(alpha: 0.1);
  }

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat("dd MMM yyyy", "tr_TR");
    final dueText = formatter.format(reminder.dueAt);
    final days = reminder.daysUntilDue;
    final status = days <= 0 ? "Bakım kaçırıldı" : "$days gün kaldı";

    return Card(
      color: _statusColor(context),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              reminder.jobTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text("Bakım tarihi: $dueText"),
            Text(status, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Tekrar atama akışı Faz4'e taşındı."),
                  ),
                );
              },
              icon: const Icon(Icons.repeat),
              label: const Text("Tekrar Atama"),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.warning_amber_rounded, size: 40),
          const SizedBox(height: 8),
          Text("Bakım hatırlatmaları alınamadı"),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          ElevatedButton(onPressed: onRetry, child: const Text("Tekrar dene")),
        ],
      ),
    );
  }
}
