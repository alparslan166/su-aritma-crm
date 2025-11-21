import "package:flutter/material.dart";
import "package:go_router/go_router.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:mobile/widgets/admin_app_bar.dart";
import "package:mobile/widgets/empty_state.dart";

import "../../application/job_list_notifier.dart";
import "../../data/models/job.dart";
import "../widgets/job_card.dart";

class PastJobsView extends ConsumerWidget {
  const PastJobsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(jobListProvider);
    final notifier = ref.read(jobListProvider.notifier);

    return Scaffold(
      appBar: const AdminAppBar(title: "Geçmiş"),
      body: state.when(
      data: (items) {
        final completedJobs = _pastOnly(items);
        if (completedJobs.isEmpty) {
          return RefreshIndicator(
            onRefresh: notifier.refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
              children: const [
                SizedBox(height: 120),
                EmptyState(
                  icon: Icons.history,
                  title: "Geçmiş iş bulunamadı",
                  subtitle:
                      "Personel teslim ettikten sonra işlemler burada listelenecek.",
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: notifier.refresh,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            itemCount: completedJobs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            cacheExtent: 500,
            addAutomaticKeepAlives: false,
            addRepaintBoundaries: true,
            itemBuilder: (context, index) {
              final job = completedJobs[index];
              return RepaintBoundary(
                child: JobCard(
                  job: job,
                  onTap: () => context.push(
                    "/admin/jobs/${job.id}",
                    extra: job,
                  ),
                ),
              );
            },
          ),
        );
      },
      error: (error, _) =>
          _JobsError(message: error.toString(), onRetry: notifier.refresh),
      loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _JobsError extends StatelessWidget {
  const _JobsError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.work_history, size: 40),
          const SizedBox(height: 8),
          Text(
            "Geçmiş iş listesi alınamadı",
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          ElevatedButton(onPressed: onRetry, child: const Text("Tekrar dene")),
        ],
      ),
    );
  }
}

List<Job> _pastOnly(List<Job> jobs) {
  return jobs
      .where((job) => job.status == "DELIVERED" || job.status == "ARCHIVED")
      .toList();
}
