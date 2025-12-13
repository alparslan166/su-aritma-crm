import "package:flutter/material.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";

import "../../../core/subscription/subscription_lock_provider.dart";
import "../../admin/data/admin_repository.dart";

class SubscriptionLockPage extends ConsumerWidget {
  const SubscriptionLockPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subAsync = ref.watch(_subscriptionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Abonelik"),
        automaticallyImplyLeading: false,
      ),
      body: subAsync.when(
        data: (sub) {
          final daysRemaining = sub?["daysRemaining"] as int?;
          final status = sub?["status"] as String?;
          final planType = sub?["planType"] as String?;

          final statusText = switch (status) {
            "trial" => "Deneme süresi",
            "active" => "Aktif abonelik",
            "expired" => "Süre doldu",
            "cancelled" => "İptal edildi",
            _ => "Abonelik",
          };

          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                Icon(
                  Icons.lock_outline,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  "Abonelik gerekli",
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  "Deneme/abonelik süreniz bitti. Devam etmek için aboneliğinizi yenilemeniz gerekir.",
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Row(label: "Durum", value: statusText),
                        _Row(
                          label: "Plan",
                          value: planType == "monthly" ? "Aylık" : (planType ?? "-"),
                        ),
                        _Row(
                          label: "Kalan gün",
                          value: (daysRemaining ?? 0).toString(),
                          valueStyle: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () {
                    // Payment integration will be added later.
                    showDialog<void>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text("Yakında"),
                        content: const Text(
                          "Ödeme altyapısı eklendiğinde aboneliğinizi buradan yenileyebileceksiniz (Aylık).",
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text("Tamam"),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text("Abonelik Yenile"),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () {
                    // Allow user to go to dashboard; router redirect will still keep them here
                    // until lock is removed, but profile details can be accessed from within app
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Abonelik yenilenene kadar uygulama kilitli."),
                      ),
                    );
                  },
                  child: const Text("Profili görüntüle"),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    // Keep lock, but allow refresh subscription status
                    ref.invalidate(_subscriptionProvider);
                  },
                  child: const Text("Yenile"),
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 12),
                Text("Abonelik bilgisi alınamadı: $e"),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => ref.invalidate(_subscriptionProvider),
                  child: const Text("Tekrar dene"),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const SizedBox(height: 12),
    );
  }
}

final _subscriptionProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  // Ensure lock state remains true when visiting this page
  ref.read(subscriptionLockRequiredProvider.notifier).state = true;
  final repo = ref.read(adminRepositoryProvider);
  return repo.getSubscription();
});

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.valueStyle});

  final String label;
  final String value;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: valueStyle ??
                  Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}


