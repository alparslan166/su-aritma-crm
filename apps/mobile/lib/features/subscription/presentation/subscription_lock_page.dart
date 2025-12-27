import "package:flutter/material.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:intl/intl.dart";

import "../../../core/session/session_provider.dart";
import "../../../core/subscription/subscription_lock_provider.dart";
import "../../../routing/app_router.dart";
import "../../admin/data/admin_repository.dart";

class SubscriptionLockPage extends ConsumerWidget {
  const SubscriptionLockPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subAsync = ref.watch(_subscriptionProvider);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade900,
              Colors.blue.shade600,
              Colors.blue.shade400,
            ],
          ),
        ),
        child: SafeArea(
          child: subAsync.when(
            data: (sub) {
              final daysRemaining = sub?["daysRemaining"] as int?;
              final status = sub?["status"] as String?;
              final trialEnds = sub?["trialEnds"] as String?;
              final endDate = sub?["endDate"] as String?;

              String formatDate(String? dateStr) {
                if (dateStr == null) return "Bilinmiyor";
                try {
                  final date = DateTime.parse(dateStr);
                  return DateFormat("dd MMMM yyyy", "tr_TR").format(date);
                } catch (e) {
                  return dateStr;
                }
              }

              final expiryDate = status == "trial" ? trialEnds : endDate;

              return Column(
                children: [
                  // Header with logout
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () async {
                            await ref.read(authSessionProvider.notifier).clearSession();
                            ref.read(subscriptionLockRequiredProvider.notifier).state = false;
                            ref.read(appRouterProvider).go("/");
                          },
                          icon: const Icon(Icons.logout, color: Colors.white70),
                          label: const Text(
                            "Çıkış",
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Lock icon
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.lock_clock,
                              size: 64,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Title
                          const Text(
                            "Abonelik Süreniz Doldu",
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "Uygulamayı kullanmaya devam etmek için\naboneliğinizi yenilemeniz gerekmektedir.",
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          // Status Card
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.warning_amber_rounded,
                                      color: Colors.red.shade600,
                                      size: 28,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      status == "trial"
                                          ? "Deneme Süresi Sona Erdi"
                                          : "Abonelik Sona Erdi",
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                const Divider(),
                                const SizedBox(height: 16),
                                _StatusRow(
                                  label: "Bitiş Tarihi",
                                  value: formatDate(expiryDate),
                                  icon: Icons.calendar_today,
                                ),
                                const SizedBox(height: 12),
                                _StatusRow(
                                  label: "Durum",
                                  value: status == "trial"
                                      ? "Deneme Süresi Dolmuş"
                                      : status == "expired"
                                          ? "Süresi Dolmuş"
                                          : "İptal Edilmiş",
                                  icon: Icons.info_outline,
                                  valueColor: Colors.red.shade600,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),
                          // Pricing Cards
                          const Text(
                            "Plan Seçin",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          // Monthly Plan
                          _PricingCard(
                            title: "Aylık Plan",
                            price: "₺299",
                            period: "/ay",
                            features: const [
                              "Sınırsız müşteri",
                              "Sınırsız personel",
                              "Sınırsız iş takibi",
                              "Fatura oluşturma",
                              "Bakım hatırlatması",
                            ],
                            isPopular: false,
                            onTap: () => _showPaymentDialog(context, "Aylık", "₺299"),
                          ),
                          const SizedBox(height: 16),
                          // Yearly Plan
                          _PricingCard(
                            title: "Yıllık Plan",
                            price: "₺2.499",
                            period: "/yıl",
                            features: const [
                              "Aylık plana göre %30 tasarruf",
                              "Sınırsız müşteri",
                              "Sınırsız personel",
                              "Sınırsız iş takibi",
                              "Öncelikli destek",
                            ],
                            isPopular: true,
                            onTap: () => _showPaymentDialog(context, "Yıllık", "₺2.499"),
                          ),
                          const SizedBox(height: 24),
                          // Refresh button
                          TextButton.icon(
                            onPressed: () => ref.invalidate(_subscriptionProvider),
                            icon: const Icon(Icons.refresh, color: Colors.white70),
                            label: const Text(
                              "Abonelik durumunu yenile",
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
            loading: () => const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.white),
                    const SizedBox(height: 12),
                    Text(
                      "Abonelik bilgisi alınamadı",
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => ref.invalidate(_subscriptionProvider),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.blue.shade900,
                      ),
                      child: const Text("Tekrar dene"),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showPaymentDialog(BuildContext context, String planType, String price) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.payment, color: Colors.blue.shade700),
            const SizedBox(width: 8),
            const Text("Ödeme"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Seçilen plan: $planType ($price)",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.construction, color: Colors.orange.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Ödeme altyapısı yakında eklenecektir. Şimdilik iletişime geçerek manuel ödeme yapabilirsiniz.",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.orange.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "İletişim: info@suaritmacrm.com",
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
          ],
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
}

final _subscriptionProvider = FutureProvider<Map<String, dynamic>?>((
  ref,
) async {
  // Ensure lock state remains true when visiting this page
  ref.read(subscriptionLockRequiredProvider.notifier).state = true;
  final repo = ref.read(adminRepositoryProvider);
  return repo.getSubscription();
});

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: valueColor ?? Colors.grey.shade800,
          ),
        ),
      ],
    );
  }
}

class _PricingCard extends StatelessWidget {
  const _PricingCard({
    required this.title,
    required this.price,
    required this.period,
    required this.features,
    required this.isPopular,
    required this.onTap,
  });

  final String title;
  final String price;
  final String period;
  final List<String> features;
  final bool isPopular;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isPopular
            ? Border.all(color: Colors.orange.shade400, width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          if (isPopular)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange.shade400,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  topRight: Radius.circular(14),
                ),
              ),
              child: const Text(
                "EN POPÜLER",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      price,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        period,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...features.map((f) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 18,
                            color: Colors.green.shade600,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              f,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: onTap,
                    style: FilledButton.styleFrom(
                      backgroundColor:
                          isPopular ? Colors.orange.shade500 : Colors.blue.shade600,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      "Satın Al",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
