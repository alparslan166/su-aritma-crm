import "dart:async";

import "package:dio/dio.dart";
import "package:flutter/foundation.dart" show debugPrint;
import "package:flutter/material.dart";
import "package:flutter_map/flutter_map.dart";
import "package:geocoding/geocoding.dart";
import "package:go_router/go_router.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:intl/intl.dart";
import "package:latlong2/latlong.dart";
import "package:url_launcher/url_launcher.dart";
import "package:mobile/widgets/admin_app_bar.dart";

import "../../../../core/error/error_handler.dart";
import "../../application/customer_list_notifier.dart";
import "../../application/job_list_notifier.dart";
import "../../data/admin_repository.dart";
import "../../data/models/customer.dart";
import "../../../dashboard/presentation/home_page_provider.dart";
import "edit_customer_sheet.dart";
import "job_map_view.dart";
import "customers_view.dart"; // CustomerFilterType enum'ı için
import "payment_invoice_create_page.dart";

final customerDetailProvider = FutureProvider.family<Customer, String>((
  ref,
  customerId,
) {
  final repository = ref.read(adminRepositoryProvider);
  return repository.fetchCustomerDetail(customerId);
});

class CustomerDetailPage extends ConsumerStatefulWidget {
  const CustomerDetailPage({
    super.key,
    required this.customerId,
    this.initialCustomer,
  });

  final String customerId;
  final Customer? initialCustomer;

  @override
  ConsumerState<CustomerDetailPage> createState() => _CustomerDetailPageState();
}

class _CustomerDetailPageState extends ConsumerState<CustomerDetailPage> {
  @override
  Widget build(BuildContext context) {
    // Always watch the provider to get real-time updates
    final customerFuture = ref.watch(customerDetailProvider(widget.customerId));
    return customerFuture.when(
      data: (customer) => _buildContent(customer),
      loading: () {
        // Show initial customer if available while loading
        if (widget.initialCustomer != null) {
          return _buildContent(widget.initialCustomer!);
        }
        return Scaffold(
          appBar: const AdminAppBar(title: Text("Müşteri Detayı")),
          body: const Center(child: CircularProgressIndicator()),
        );
      },
      error: (error, _) {
        // Show initial customer if available on error
        if (widget.initialCustomer != null) {
          return _buildContent(widget.initialCustomer!);
        }
        return Scaffold(
          appBar: const AdminAppBar(title: Text("Müşteri Detayı")),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("Hata: $error"),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () =>
                      ref.invalidate(customerDetailProvider(widget.customerId)),
                  child: const Text("Tekrar Dene"),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent(Customer customer) {
    return Scaffold(
      appBar: AdminAppBar(
        title: Text(customer.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: "Müşteriyi Sil",
            onPressed: () => _deleteCustomer(customer),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditCustomerSheet(customer),
        tooltip: "Düzenle",
        child: const Icon(Icons.edit),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Harita bölümü - en üstte
          _CustomerMapSection(customer: customer),
          const SizedBox(height: 24),
          _CustomerInfoSection(
            customer: customer,
            onStatusChanged: (newStatus) =>
                _updateCustomerStatus(customer, newStatus),
          ),
          // Bakım Bilgileri - Her zaman göster
          const SizedBox(height: 24),
          _MaintenanceSection(customer: customer),
          if (customer.hasDebt) ...[
            const SizedBox(height: 24),
            _DebtSection(customer: customer),
          ],
          // Borç Ödeme Geçmişi - Borç Ödeme bölümünün üzerinde (her zaman göster)
          const SizedBox(height: 24),
          _DebtPaymentHistorySection(customer: customer),
          // Borç Ödeme formu - sadece borç varsa göster
          if (customer.hasDebt) ...[
            const SizedBox(height: 24),
            Card(
              color: const Color(0xFF10B981).withValues(alpha: 0.05),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Borç Ödeme",
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _PayDebtForm(customerId: customer.id),
                  ],
                ),
              ),
            ),
          ],
          if (customer.jobs != null && customer.jobs!.isNotEmpty) ...[
            const SizedBox(height: 24),
            _Section(
              title: "İşler (${customer.jobs!.length})",
              children: customer.jobs!
                  .map(
                    (job) => _JobCard(
                      job: job,
                      customerId: customer.id,
                      onDelete: job.status == "IN_PROGRESS"
                          ? () => _deleteJob(job, customer.id)
                          : null,
                      onTap: () => context.push("/admin/jobs/${job.id}"),
                    ),
                  )
                  .toList(),
            ),
          ],
          // Bottom padding for phones with navigation buttons
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  void _showEditCustomerSheet(Customer customer) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: EditCustomerSheet(customer: customer),
      ),
    );
  }

  Future<void> _updateCustomerStatus(
    Customer customer,
    String newStatus,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(adminRepositoryProvider)
          .updateCustomer(id: customer.id, status: newStatus);
      ref.invalidate(customerDetailProvider(customer.id));

      // Tüm filter type'lar için provider'ları refresh et
      ref.read(customerListProvider.notifier).refresh(showLoading: false);

      // Tüm filter type'lar için ayrı ayrı refresh et
      for (final filterType in [
        CustomerFilterType.all,
        CustomerFilterType.overduePayment,
        CustomerFilterType.upcomingMaintenance,
        CustomerFilterType.overdueInstallment,
      ]) {
        final filterTypeKey = filterType.toString();
        final notifier = ref.read(
          customerListProviderForFilter(filterTypeKey).notifier,
        );
        notifier.refresh(showLoading: false);
      }

      // Ana sayfa grafik ve istatistiklerini statik olarak yenile
      ref.invalidate(dashboardStatsProvider);
      ref.invalidate(customerCategoryDataProvider);
      ref.invalidate(overduePaymentsCustomersProvider);
      ref.invalidate(upcomingMaintenanceProvider);

      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              "Müşteri durumu ${newStatus == "ACTIVE" ? "Aktif" : "Pasif"} olarak güncellendi",
            ),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ErrorHandler.showError(context, error);
      }
    }
  }

  Future<void> _deleteCustomer(Customer customer) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Müşteriyi Sil"),
        content: Text(
          "${customer.name} müşterisini silmek istediğinize emin misiniz? Bu işlem geri alınamaz.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("İptal"),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Sil"),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ref.read(adminRepositoryProvider).deleteCustomer(customer.id);

      // Tüm filter type'lar için provider'ları refresh et
      ref.read(customerListProvider.notifier).refresh(showLoading: false);
      for (final filterType in [
        CustomerFilterType.all,
        CustomerFilterType.overduePayment,
        CustomerFilterType.upcomingMaintenance,
        CustomerFilterType.overdueInstallment,
      ]) {
        final filterTypeKey = filterType.toString();
        final notifier = ref.read(
          customerListProviderForFilter(filterTypeKey).notifier,
        );
        notifier.refresh(showLoading: false);
      }

      // Ana sayfa grafik ve istatistiklerini statik olarak yenile
      ref.invalidate(dashboardStatsProvider);
      ref.invalidate(customerCategoryDataProvider);
      ref.invalidate(overduePaymentsCustomersProvider);
      ref.invalidate(upcomingMaintenanceProvider);

      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text("${customer.name} silindi")),
      );
    } catch (error) {
      String errorMessage = "Müşteri silinemedi";

      // Parse DioException to get backend error message
      if (error is DioException) {
        final message = error.response?.data?["message"]?.toString() ?? "";
        if (message.contains("active jobs") ||
            message.contains("Cannot delete customer with active jobs")) {
          errorMessage =
              "Aktif işleri olan müşteri silinemez. Önce müşterinin tüm aktif işlerini arşivleyin veya silin.";
        } else if (message.isNotEmpty) {
          errorMessage = message;
        }
      }

      messenger.showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _deleteJob(CustomerJob job, String customerId) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("İşi Sil"),
        content: Text(
          "${job.title} işini silmek istediğinize emin misiniz? Bu işlem geri alınamaz.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("İptal"),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Sil"),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ref.read(adminRepositoryProvider).deleteJob(job.id);
      ref.invalidate(customerDetailProvider(customerId));

      // Tüm filter type'lar için provider'ları refresh et
      ref.read(customerListProvider.notifier).refresh(showLoading: false);
      for (final filterType in [
        CustomerFilterType.all,
        CustomerFilterType.overduePayment,
        CustomerFilterType.upcomingMaintenance,
        CustomerFilterType.overdueInstallment,
      ]) {
        final filterTypeKey = filterType.toString();
        final notifier = ref.read(
          customerListProviderForFilter(filterTypeKey).notifier,
        );
        notifier.refresh(showLoading: false);
      }

      ref.invalidate(jobListProvider);

      // Ana sayfa grafik ve istatistiklerini statik olarak yenile
      ref.invalidate(dashboardStatsProvider);
      ref.invalidate(customerCategoryDataProvider);
      ref.invalidate(overduePaymentsCustomersProvider);
      ref.invalidate(upcomingMaintenanceProvider);

      if (context.mounted) {
        messenger.showSnackBar(SnackBar(content: Text("${job.title} silindi")));
      }
    } catch (error) {
      if (context.mounted) {
        messenger.showSnackBar(SnackBar(content: Text("Silinemedi: $error")));
      }
    }
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow(this.label, this.status, {required this.onChanged});

  final String label;
  final String status;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            flex: 3,
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: "ACTIVE",
                  label: Text("Aktif"),
                  icon: Icon(Icons.check_circle, size: 16),
                ),
                ButtonSegment(
                  value: "INACTIVE",
                  label: Text("Pasif"),
                  icon: Icon(Icons.cancel, size: 16),
                ),
              ],
              selected: {status},
              onSelectionChanged: (Set<String> newSelection) {
                if (newSelection.isNotEmpty) {
                  onChanged(newSelection.first);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: children),
          ),
        ),
      ],
    );
  }
}

class _ThemedSection extends StatelessWidget {
  const _ThemedSection({
    required this.title,
    required this.icon,
    required this.gradientColors,
    required this.borderColor,
    required this.children,
  });

  final String title;
  final Widget icon;
  final List<Color> gradientColors;
  final Color borderColor;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: borderColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: icon,
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1F2937),
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradientColors,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: borderColor.withOpacity(0.1),
                blurRadius: 12,
                spreadRadius: 0,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: children),
          ),
        ),
      ],
    );
  }
}

class _MaintenanceSection extends StatelessWidget {
  const _MaintenanceSection({required this.customer});

  final Customer customer;

  @override
  Widget build(BuildContext context) {
    final isOverdue =
        customer.nextMaintenanceDate != null &&
        customer.nextMaintenanceDate!.isBefore(DateTime.now());
    final isUrgent =
        customer.nextMaintenanceDate != null &&
        !isOverdue &&
        customer.nextMaintenanceDate!.difference(DateTime.now()).inDays <= 7;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Image.asset(
                "assets/images/wrench.png",
                width: 24,
                height: 24,
                color: const Color(0xFFF59E0B),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              "Bakım Bilgileri",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: const Color(0xFFF59E0B),
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFFF59E0B).withValues(alpha: 0.08),
                const Color(0xFFFCD34D).withValues(alpha: 0.05),
                Colors.white,
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                blurRadius: 12,
                spreadRadius: 0,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                if (customer.nextMaintenanceDate != null) ...[
                  _MaintenanceRow(
                    icon: Icons.calendar_today,
                    label: "Sonraki Bakım Tarihi",
                    value: DateFormat(
                      "dd MMM yyyy",
                    ).format(customer.nextMaintenanceDate!),
                    valueColor: isOverdue
                        ? Colors.red.shade700
                        : isUrgent
                        ? Colors.orange.shade700
                        : const Color(0xFF1F2937),
                  ),
                  const SizedBox(height: 16),
                  if (customer.maintenanceTimeRemaining != null)
                    _MaintenanceRow(
                      icon: Icons.access_time,
                      label: "Kalan Süre",
                      value: customer.maintenanceTimeRemaining!,
                      valueColor: isOverdue
                          ? Colors.red.shade700
                          : isUrgent
                          ? Colors.orange.shade700
                          : const Color(0xFF10B981),
                      isBold: true,
                    ),
                ] else ...[
                  _MaintenanceRow(
                    icon: Icons.calendar_today,
                    label: "Sonraki Bakım Tarihi",
                    value: "Henüz belirlenmedi",
                    valueColor: Colors.grey.shade600,
                  ),
                  const SizedBox(height: 16),
                  _MaintenanceRow(
                    icon: Icons.access_time,
                    label: "Kalan Süre",
                    value: "-",
                    valueColor: Colors.grey.shade600,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MaintenanceRow extends StatelessWidget {
  const _MaintenanceRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.isBold = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final bool isBold;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: const Color(0xFFF59E0B)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                  color: valueColor ?? const Color(0xFF1F2937),
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DebtSection extends StatelessWidget {
  const _DebtSection({required this.customer});

  final Customer customer;

  @override
  Widget build(BuildContext context) {
    final isOverdue =
        customer.nextDebtDate != null &&
        customer.nextDebtDate!.isBefore(DateTime.now());
    final hasRemainingDebt =
        customer.remainingDebtAmount != null &&
        customer.remainingDebtAmount! > 0;
    // Son ödeme tarihini bul (en son ödenen)
    DateTime? latestPaymentDate;
    if (customer.debtPaymentHistory != null &&
        customer.debtPaymentHistory!.isNotEmpty) {
      latestPaymentDate = customer.debtPaymentHistory!
          .reduce((a, b) => a.paidAt.isAfter(b.paidAt) ? a : b)
          .paidAt;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.account_balance_wallet,
                size: 24,
                color: Color(0xFF2563EB),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              "Borç Bilgileri",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF2563EB),
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF2563EB).withValues(alpha: 0.08),
                const Color(0xFF60A5FA).withValues(alpha: 0.05),
                Colors.white,
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF2563EB).withValues(alpha: 0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                blurRadius: 12,
                spreadRadius: 0,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                if (customer.debtAmount != null)
                  _DebtRow(
                    icon: Icons.receipt_long,
                    label: "Toplam Borç",
                    value: "${customer.debtAmount!.toStringAsFixed(2)} TL",
                    valueColor: const Color(0xFF1F2937),
                    isBold: true,
                  ),
                if (customer.paidDebtAmount != null &&
                    customer.paidDebtAmount! > 0) ...[
                  const SizedBox(height: 16),
                  _DebtRow(
                    icon: Icons.check_circle_outline,
                    label: "Ödenen Borç",
                    value: "${customer.paidDebtAmount!.toStringAsFixed(2)} TL",
                    valueColor: const Color(0xFF10B981),
                    isBold: true,
                  ),
                ],
                if (customer.hasInstallment &&
                    customer.installmentCount != null) ...[
                  const SizedBox(height: 16),
                  _DebtRow(
                    icon: Icons.payment,
                    label: "Taksit Sayısı",
                    value: "${customer.installmentCount} taksit",
                    valueColor: const Color(0xFF1F2937),
                  ),
                ],
                if (customer.remainingDebtAmount != null) ...[
                  const SizedBox(height: 16),
                  _DebtRow(
                    icon: Icons.account_balance_wallet,
                    label: "Kalan Borç",
                    value:
                        "${customer.remainingDebtAmount!.toStringAsFixed(2)} TL",
                    valueColor: hasRemainingDebt
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF10B981),
                    isBold: true,
                  ),
                ],
                if (latestPaymentDate != null) ...[
                  const SizedBox(height: 16),
                  _DebtRow(
                    icon: Icons.event_available,
                    label: "Son Ödeme Tarihi",
                    value: DateFormat(
                      "dd MMM yyyy, HH:mm",
                    ).format(latestPaymentDate),
                    valueColor: const Color(0xFF10B981),
                    isBold: true,
                  ),
                ],
                if (customer.nextDebtDate != null) ...[
                  const SizedBox(height: 16),
                  _DebtRow(
                    icon: Icons.calendar_today,
                    label: "Borç Ödeme Tarihi",
                    value: DateFormat(
                      "dd MMM yyyy",
                    ).format(customer.nextDebtDate!),
                    valueColor: isOverdue
                        ? Colors.red.shade700
                        : const Color(0xFF1F2937),
                  ),
                  if (isOverdue) ...[
                    const SizedBox(height: 16),
                    _DebtRow(
                      icon: Icons.warning_amber_rounded,
                      label: "Geçen Süre",
                      value: _getOverdueDays(customer.nextDebtDate!),
                      valueColor: Colors.red.shade700,
                      isBold: true,
                    ),
                  ],
                ],
                // Borç durumu: Sadece müşteri seviyesinde borç varsa, kalan borç > 0 ise ve ödeme tarihi geçmişse göster
                if (customer.hasDebt &&
                    customer.remainingDebtAmount != null &&
                    customer.remainingDebtAmount! > 0 &&
                    customer.nextDebtDate != null &&
                    customer.nextDebtDate!.isBefore(DateTime.now())) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200, width: 1),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 20,
                          color: Colors.red.shade700,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Ödeme gecikmiş",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                // Taksit Kutucukları
                if (customer.hasInstallment &&
                    (customer.installmentCount ?? 0) > 0) ...[
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 12),
                  Text(
                    "Taksit Planı",
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: List.generate(
                        customer.installmentCount!,
                        (index) {
                          final installmentNo = index + 1;
                          final intervalDays = customer.installmentIntervalDays ?? 30;
                          final startDate = customer.installmentStartDate ?? DateTime.now();
                          final dueDate = startDate.add(
                            Duration(days: intervalDays * installmentNo),
                          );
                          final debtAmount = customer.debtAmount ?? 0;
                          final installmentAmount = debtAmount / customer.installmentCount!;
                          // Ödenen taksit sayısını hesapla
                          final paidAmount = customer.paidDebtAmount ?? 0;
                          final isPaid = (installmentAmount * installmentNo) <= paidAmount;

                          return Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isPaid
                                  ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                  : const Color(0xFF2563EB).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isPaid
                                    ? const Color(0xFF10B981).withValues(alpha: 0.4)
                                    : const Color(0xFF2563EB).withValues(alpha: 0.3),
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  "$installmentNo",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isPaid
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFF2563EB),
                                  ),
                                ),
                                Text(
                                  "${installmentAmount.toStringAsFixed(0)}₺",
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isPaid
                                        ? const Color(0xFF10B981)
                                        : Colors.grey.shade600,
                                    decoration: isPaid
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                                Text(
                                  DateFormat("dd/MM").format(dueDate),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                                if (isPaid)
                                  const Text(
                                    "✓",
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF10B981),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  static String _getOverdueDaysStatic(DateTime dueDate) {
    final now = DateTime.now();
    final difference = now.difference(dueDate);
    final days = difference.inDays;

    if (days == 0) {
      return "Bugün geçti";
    } else if (days == 1) {
      return "1 gün geçti";
    } else {
      return "$days gün geçti";
    }
  }

  String _getOverdueDays(DateTime dueDate) {
    return _getOverdueDaysStatic(dueDate);
  }
}

class _DebtRow extends StatelessWidget {
  const _DebtRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.isBold = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final bool isBold;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF2563EB).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: const Color(0xFF2563EB)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                  color: valueColor ?? const Color(0xFF1F2937),
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DebtPaymentHistorySection extends ConsumerWidget {
  const _DebtPaymentHistorySection({required this.customer});

  final Customer customer;

  /// Helper metod: Müşterinin en son DELIVERED işini bulur
  CustomerJob? _findLatestDeliveredJob(Customer customer) {
    if (customer.jobs == null || customer.jobs!.isEmpty) return null;

    final deliveredJobs = customer.jobs!
        .where((job) => job.status == "DELIVERED")
        .toList();

    if (deliveredJobs.isEmpty) return null;

    // maintenanceDueAt'e göre sırala (en son tarihli olanı al)
    // Eğer maintenanceDueAt yoksa, ilk DELIVERED işi al
    deliveredJobs.sort((a, b) {
      if (a.maintenanceDueAt == null && b.maintenanceDueAt == null) return 0;
      if (a.maintenanceDueAt == null) return 1;
      if (b.maintenanceDueAt == null) return -1;
      return b.maintenanceDueAt!.compareTo(a.maintenanceDueAt!);
    });

    return deliveredJobs.first;
  }

  /// Borç ödeme geçmişi için fatura oluştur (iş gerektirmez)
  Future<void> _createInvoiceForPayment(
    BuildContext context,
    WidgetRef ref,
    Customer customer,
    DebtPaymentHistory payment,
  ) async {
    // Navigate to payment invoice create page
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PaymentInvoiceCreatePage(
          customer: customer,
          paymentAmount: payment.amount,
          paymentDate: payment.paidAt,
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.history,
                size: 24,
                color: Color(0xFF10B981),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              "Borç Ödeme Geçmişi",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF10B981),
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Alınan Ücret geçmişi - tüm kayıtları göster
        if (customer.receivedAmountHistory != null &&
            customer.receivedAmountHistory!.isNotEmpty) ...[
          ...customer.receivedAmountHistory!.map((history) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF2563EB).withValues(alpha: 0.08),
                    const Color(0xFF3B82F6).withValues(alpha: 0.05),
                    Colors.white,
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.2),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                    blurRadius: 8,
                    spreadRadius: 0,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.attach_money,
                        color: Color(0xFF2563EB),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                "${history.amount.toStringAsFixed(2)} TL",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Color(0xFF2563EB),
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF2563EB,
                                  ).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  "Alınan Ücret",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF2563EB),
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 16,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                DateFormat(
                                  "dd MMM yyyy, HH:mm",
                                ).format(history.receivedAt),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.1,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ] else ...[
          // Eğer geçmiş yoksa, boş mesaj göster
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF2563EB).withValues(alpha: 0.05),
                  Colors.white,
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                width: 1,
              ),
            ),
            child: Center(
              child: Text(
                "Henüz alınan ücret kaydı bulunmuyor",
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
        if (customer.debtPaymentHistory != null &&
            customer.debtPaymentHistory!.isNotEmpty) ...[
          ...customer.debtPaymentHistory!.map((payment) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF10B981).withValues(alpha: 0.08),
                    const Color(0xFF34D399).withValues(alpha: 0.05),
                    Colors.white,
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: 0.2),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    blurRadius: 8,
                    spreadRadius: 0,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.check_circle,
                        color: Color(0xFF10B981),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                "${payment.amount.toStringAsFixed(2)} TL",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Color(0xFF10B981),
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF10B981,
                                  ).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  "ödedi",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF10B981),
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 16,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                DateFormat(
                                  "dd MMM yyyy, HH:mm",
                                ).format(payment.paidAt),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.1,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        onPressed: () =>
                            _createInvoiceForPayment(context, ref, customer, payment),
                        icon: const Icon(Icons.receipt),
                        color: const Color(0xFF2563EB),
                        tooltip: "Fatura Oluştur",
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF10B981).withValues(alpha: 0.05),
                  Colors.white,
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                width: 1,
              ),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.history_outlined,
                    size: 48,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Henüz ödeme yapılmadı",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Color(0xFF1F2937),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerInfoSection extends StatelessWidget {
  const _CustomerInfoSection({
    required this.customer,
    required this.onStatusChanged,
  });

  final Customer customer;
  final ValueChanged<String> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return _ThemedSection(
      title: "Müşteri Bilgileri",
      icon: const Icon(
        Icons.person_outline,
        size: 24,
        color: Color(0xFF7C3AED), // Purple
      ),
      gradientColors: [
        const Color(0xFF7C3AED).withOpacity(0.1), // Purple
        const Color(0xFFA78BFA).withOpacity(0.05), // Light Purple
        Colors.white.withOpacity(0.0),
      ],
      borderColor: const Color(0xFF7C3AED).withOpacity(0.3),
      children: [
        const SizedBox(height: 16),
        if (customer.createdAt != null)
          _InfoRowIcon(
            icon: Icons.event,
            label: "Kayıt Tarihi",
            value: DateFormat("dd MMM yyyy").format(customer.createdAt!),
          ),
        _InfoRowIcon(icon: Icons.badge, label: "İsim", value: customer.name),
        _InfoRowIcon(
          icon: Icons.phone,
          label: "Telefon",
          value: customer.phone,
        ),
        if (customer.email != null)
          _InfoRowIcon(
            icon: Icons.mail,
            label: "E-posta",
            value: customer.email!,
          ),
        _InfoRowIcon(
          icon: Icons.home,
          label: "Adres",
          value: customer.address,
          maxLines: 3,
        ),
        const SizedBox(height: 8),
        _StatusRow("Durum", customer.status, onChanged: onStatusChanged),
      ],
    );
  }
}

class _InfoRowIcon extends StatelessWidget {
  const _InfoRowIcon({
    required this.icon,
    required this.label,
    required this.value,
    this.maxLines = 1,
  });

  final IconData icon;
  final String label;
  final String value;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFA78BFA).withOpacity(0.2), // Light purple
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 18,
              color: const Color(0xFF7C3AED), // Purple
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: maxLines,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                    letterSpacing: -0.2,
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

class _PayDebtForm extends ConsumerStatefulWidget {
  const _PayDebtForm({required this.customerId});

  final String customerId;

  @override
  ConsumerState<_PayDebtForm> createState() => _PayDebtFormState();
}

class _PayDebtFormState extends ConsumerState<_PayDebtForm> {
  final _amountController = TextEditingController();
  final _installmentCountController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _installmentCountController.dispose();
    super.dispose();
  }

  Future<void> _submitPayment(double amount) async {
    setState(() {
      _submitting = true;
    });

    try {
      // Get current customer data
      final customerAsync = ref.read(customerDetailProvider(widget.customerId));
      final customer = customerAsync.value;
      if (customer == null) {
        throw Exception("Müşteri bilgisi alınamadı");
      }

      final installmentCount =
          customer.hasInstallment && _installmentCountController.text.isNotEmpty
          ? int.tryParse(_installmentCountController.text)
          : null;

      // Ödeme yap (backend'den dönen customer'da debtPaymentHistory dahil)
      final updatedCustomer = await ref
          .read(adminRepositoryProvider)
          .payCustomerDebt(
            id: widget.customerId,
            amount: amount,
            installmentCount: installmentCount,
          );

      // Debug: Dönen customer'da debtPaymentHistory var mı kontrol et
      debugPrint("🔵 Ödeme sonrası dönen customer:");
      debugPrint(
        "   - debtPaymentHistory: ${updatedCustomer.debtPaymentHistory?.length ?? 0} adet",
      );
      if (updatedCustomer.debtPaymentHistory != null) {
        for (final payment in updatedCustomer.debtPaymentHistory!) {
          debugPrint("   - ${payment.amount} TL - ${payment.paidAt}");
        }
      }

      // Customer detail provider'ı invalidate et ve güncel veriyi yükle
      // Bu sayede ödeme geçmişi bölümü otomatik olarak güncellenir
      ref.invalidate(customerDetailProvider(widget.customerId));
      // Provider'ın yeniden yüklenmesini bekle - ödeme geçmişi dahil tüm veriler güncellenir
      final refreshedCustomer = await ref.read(
        customerDetailProvider(widget.customerId).future,
      );

      // Debug: Refresh sonrası customer'da debtPaymentHistory var mı kontrol et
      debugPrint("🟢 Refresh sonrası customer:");
      debugPrint(
        "   - debtPaymentHistory: ${refreshedCustomer.debtPaymentHistory?.length ?? 0} adet",
      );
      if (refreshedCustomer.debtPaymentHistory != null) {
        for (final payment in refreshedCustomer.debtPaymentHistory!) {
          debugPrint("   - ${payment.amount} TL - ${payment.paidAt}");
        }
      }

      // Also refresh customer list to update filters (invalidate yerine refresh kullan)
      // Bu sayede loading state'ine düşmez, sadece liste güncellenir
      // Eğer customer list sayfası açıksa, orada loading görünmez
      ref.read(customerListProvider.notifier).refresh(showLoading: false);

      // Ana sayfa grafik ve istatistiklerini statik olarak yenile
      ref.invalidate(dashboardStatsProvider);
      ref.invalidate(customerCategoryDataProvider);
      ref.invalidate(overduePaymentsCustomersProvider);
      ref.invalidate(upcomingMaintenanceProvider);

      if (!mounted) return;
      _amountController.clear();
      setState(() {
        _submitting = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Borç ödemesi kaydedildi")));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
      });
      ErrorHandler.showError(context, error);
    }
  }

  Future<void> _payPartial() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Geçerli bir miktar girin")));
      return;
    }

    // Get current customer data
    final customerAsync = ref.read(customerDetailProvider(widget.customerId));
    final customer = customerAsync.value;
    if (customer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Müşteri bilgisi alınamadı")),
      );
      return;
    }
    final remaining = customer.remainingDebtAmount ?? 0.0;

    if (amount > remaining) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Ödeme miktarı kalan borçtan (${remaining.toStringAsFixed(2)} TL) fazla olamaz",
          ),
        ),
      );
      return;
    }

    await _submitPayment(amount);
  }

  Future<void> _payFull() async {
    // Get current customer data
    final customerAsync = ref.read(customerDetailProvider(widget.customerId));
    final customer = customerAsync.value;
    if (customer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Müşteri bilgisi alınamadı")),
      );
      return;
    }
    final remaining = customer.remainingDebtAmount ?? 0.0;

    if (remaining <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Ödenecek borç bulunmuyor")));
      return;
    }

    await _submitPayment(remaining);
  }

  @override
  Widget build(BuildContext context) {
    final customerAsync = ref.watch(customerDetailProvider(widget.customerId));

    return customerAsync.when(
      data: (customer) {
        // Update installment count when customer data changes
        if (customer.hasInstallment && customer.installmentCount != null) {
          final newCount = customer.installmentCount.toString();
          if (_installmentCountController.text != newCount) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _installmentCountController.text = newCount;
              }
            });
          }
        }

        final remaining = customer.remainingDebtAmount ?? 0.0;

        return Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (remaining > 0)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 20,
                        color: Colors.blue.shade700,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Kalan Borç: ${remaining.toStringAsFixed(2)} TL",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (remaining > 0) const SizedBox(height: 12),
              TextFormField(
                controller: _amountController,
                decoration: InputDecoration(
                  labelText: "Ödenen Borç Miktarı (TL)",
                  prefixIcon: const Icon(Icons.attach_money),
                  helperText: remaining > 0
                      ? "Maksimum: ${remaining.toStringAsFixed(2)} TL"
                      : "Ödeme yapıldıktan sonra borçtan düşülecek",
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return "Miktar girin";
                  }
                  final amount = double.tryParse(value);
                  if (amount == null || amount <= 0) {
                    return "Geçerli bir miktar girin";
                  }
                  if (amount > remaining) {
                    return "Ödeme miktarı kalan borçtan fazla olamaz";
                  }
                  return null;
                },
              ),
              if (customer.hasInstallment) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _installmentCountController,
                  decoration: const InputDecoration(
                    labelText: "Yeni Taksit Sayısı (Manuel)",
                    prefixIcon: Icon(Icons.numbers),
                    helperText: "Kalan taksit sayısını manuel olarak girin",
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (customer.hasInstallment &&
                        value != null &&
                        value.trim().isNotEmpty) {
                      final count = int.tryParse(value);
                      if (count == null || count < 0) {
                        return "Geçerli bir sayı girin";
                      }
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _submitting ? null : _payPartial,
                  icon: _submitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.payment),
                  label: Text(
                    _submitting ? "Kaydediliyor..." : "Borç Ödemesi Yap",
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                  ),
                ),
              ),
              if (remaining > 0) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _submitting ? null : _payFull,
                    icon: const Icon(Icons.check_circle),
                    label: const Text("Tüm Borcu Öde"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF10B981),
                      side: const BorderSide(color: Color(0xFF10B981)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text("Hata: $error")),
    );
  }
}

class _JobCard extends ConsumerWidget {
  const _JobCard({
    required this.job,
    required this.customerId,
    this.onDelete,
    this.onTap,
  });

  final CustomerJob job;
  final String customerId;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDelivered = job.status == "DELIVERED";
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      job.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (onDelete != null)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      tooltip: "İşi Sil",
                      onPressed: onDelete,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              _Row("Durum", _getJobStatusText(job.status)),
              if (job.price != null)
                _Row("Fiyat", "${job.price!.toStringAsFixed(2)} TL"),
              if (job.collectedAmount != null)
                _Row(
                  "Tahsilat",
                  "${job.collectedAmount!.toStringAsFixed(2)} TL",
                ),
              if (job.maintenanceDueAt != null)
                _Row(
                  "Bakım Tarihi",
                  DateFormat("dd MMM yyyy").format(job.maintenanceDueAt!),
                ),
              // Fatura Oluştur butonu - sadece DELIVERED işler için
              if (isDelivered) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _createInvoice(context, ref, job.id),
                    icon: const Icon(Icons.receipt, size: 18),
                    label: const Text("Fatura Oluştur"),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createInvoice(
    BuildContext context,
    WidgetRef ref,
    String jobId,
  ) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Generate and open PDF (opens directly from URL, never saved to device)
      final repository = ref.read(adminRepositoryProvider);
      await repository.generateInvoicePdf(jobId);

      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // Refresh customer detail and job list
      ref.invalidate(customerDetailProvider(customerId));
      ref.invalidate(jobListProvider);

      // Ana sayfa grafik ve istatistiklerini statik olarak yenile
      ref.invalidate(dashboardStatsProvider);
      ref.invalidate(customerCategoryDataProvider);
      ref.invalidate(overduePaymentsCustomersProvider);
      ref.invalidate(upcomingMaintenanceProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Fatura oluşturuldu ve açıldı")),
        );
      }
    } catch (error) {
      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
        ErrorHandler.showError(context, error);
      }
    }
  }
}

String _getJobStatusText(String status) {
  switch (status) {
    case "PENDING":
      return "Beklemede";
    case "IN_PROGRESS":
      return "Devam Ediyor";
    case "DELIVERED":
      return "Teslim Edildi";
    case "ARCHIVED":
      return "Arşivlendi";
    default:
      return status;
  }
}

class _CustomerMapSection extends StatefulWidget {
  const _CustomerMapSection({required this.customer});

  final Customer customer;

  @override
  State<_CustomerMapSection> createState() => _CustomerMapSectionState();
}

class _CustomerMapSectionState extends State<_CustomerMapSection> {
  LatLng? _customerLocation;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  Future<void> _loadLocation() async {
    // Önce müşterinin location bilgisini kontrol et
    debugPrint(
      "🗺️ Customer location check: ${widget.customer.location != null}",
    );
    if (widget.customer.location != null) {
      debugPrint(
        "🗺️ Customer has location: ${widget.customer.location!.latitude}, ${widget.customer.location!.longitude}",
      );
      setState(() {
        _customerLocation = LatLng(
          widget.customer.location!.latitude,
          widget.customer.location!.longitude,
        );
      });
      return;
    }

    debugPrint(
      "🗺️ Customer location is null, trying geocoding for: ${widget.customer.address}",
    );

    // Location yoksa adresten geocoding yap
    if (widget.customer.address.isEmpty) {
      setState(() {
        _error = "Adres bilgisi bulunamadı";
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Timeout ile geocoding yap (10 saniye)
      final locations = await locationFromAddress(widget.customer.address)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw TimeoutException("Geocoding timeout");
            },
          );
      if (!mounted) return;
      if (locations.isNotEmpty) {
        final location = locations.first;
        setState(() {
          _customerLocation = LatLng(location.latitude, location.longitude);
          _isLoading = false;
          _error = null;
        });
      } else {
        setState(() {
          _error =
              "Adres için konum bulunamadı. Google Maps'te açmak için adrese tıklayın.";
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error =
            "Konum yüklenemedi. Google Maps'te açmak için adrese tıklayın.";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _ThemedSection(
      title: "Konum",
      icon: const Icon(
        Icons.location_on_outlined,
        size: 24,
        color: Color(0xFF60A5FA), // Light Blue
      ),
      gradientColors: [
        const Color(0xFF60A5FA).withOpacity(0.1), // Light Blue
        const Color(0xFF93C5FD).withOpacity(0.05), // Lighter Blue
        Colors.white.withOpacity(0.0),
      ],
      borderColor: const Color(0xFF60A5FA).withOpacity(0.3),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (_error != null || _isLoading)
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _isLoading ? null : _loadLocation,
                  tooltip: "Yeniden Yükle",
                  color: const Color(0xFF60A5FA), // Light Blue
                ),
            ],
          ),
        ),
        InkWell(
          onTap: _customerLocation != null
              ? () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => JobMapView(
                        initialCustomerLocation: _customerLocation!,
                        initialCustomerId: widget.customer.id,
                      ),
                    ),
                  );
                }
              : null,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final mapHeight = MediaQuery.of(context).size.height * 0.25;
              final minHeight = 200.0;
              final maxHeight = 300.0;
              final calculatedHeight = mapHeight.clamp(minHeight, maxHeight);

              return SizedBox(
                height: calculatedHeight,
                child: _isLoading
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(
                                    0xFF60A5FA,
                                  ).withOpacity(0.1),
                                ),
                                child: const Icon(
                                  Icons.location_searching,
                                  color: Color(0xFF60A5FA), // Light Blue
                                  size: 56,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                "Konum Bulunamadı",
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade700,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _error!.contains("Adres bilgisi")
                                    ? "Müşterinin adres bilgisi bulunmuyor. Adres bilgisi ekleyerek konumu görüntüleyebilirsiniz."
                                    : "Müşterinin konum bilgisi yüklenemedi. Adres bilgisi doğru mu kontrol edin veya Google Maps'te açmak için adrese tıklayın.",
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Colors.grey.shade600,
                                      height: 1.4,
                                    ),
                              ),
                              const SizedBox(height: 16),
                              OutlinedButton.icon(
                                onPressed: _loadLocation,
                                icon: const Icon(Icons.refresh, size: 18),
                                label: const Text("Tekrar Dene"),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _customerLocation != null
                    ? Builder(
                        builder: (context) {
                          debugPrint(
                            "🗺️ Rendering customer map at: ${_customerLocation!.latitude}, ${_customerLocation!.longitude}",
                          );
                          return ClipRect(
                            child: FlutterMap(
                              key: ValueKey(
                                "${_customerLocation!.latitude}_${_customerLocation!.longitude}",
                              ),
                              options: MapOptions(
                                initialCenter: _customerLocation!,
                                initialZoom: 15.0,
                                interactionOptions: const InteractionOptions(
                                  flags: InteractiveFlag.none,
                                ),
                              ),
                              children: [
                                TileLayer(
                                  urlTemplate:
                                      "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                                  userAgentPackageName: "com.suaritma.app",
                                  maxZoom: 19,
                                  minZoom: 3,
                                ),
                                MarkerLayer(
                                  markers: [
                                    Marker(
                                      point: _customerLocation!,
                                      width: 50,
                                      height: 50,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: const Color(
                                            0xFF60A5FA,
                                          ), // Light Blue
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 3,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(
                                                0xFF60A5FA,
                                              ).withOpacity(0.4),
                                              blurRadius: 8,
                                              spreadRadius: 2,
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons.location_on,
                                          color: Colors.white,
                                          size: 28,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      )
                    : Builder(
                        builder: (context) {
                          debugPrint(
                            "🗺️ Customer location is null, showing error message",
                          );
                          return const Center(
                            child: Text("Konum bilgisi bulunamadı"),
                          );
                        },
                      ),
              );
            },
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 0, vertical: 8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final screenWidth = MediaQuery.of(context).size.width;
              final isSmallScreen = screenWidth < 400;
              final buttonHeight = isSmallScreen ? 44.0 : 48.0;
              final iconSize = isSmallScreen ? 16.0 : 18.0;
              final fontSize = isSmallScreen ? 12.0 : 13.0;
              final horizontalPadding = isSmallScreen ? 8.0 : 12.0;

              return Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: buttonHeight,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // Google Maps'te adresi aç
                          final encodedAddress = Uri.encodeComponent(
                            widget.customer.address,
                          );
                          final googleMapsUrl =
                              "https://www.google.com/maps/search/?api=1&query=$encodedAddress";
                          final uri = Uri.parse(googleMapsUrl);
                          // ignore: unawaited_futures
                          launchUrl(uri, mode: LaunchMode.externalApplication);
                        },
                        icon: Icon(Icons.place, size: iconSize),
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            "Google Maps ile Aç",
                            style: TextStyle(
                              fontSize: fontSize,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(
                            0xFF60A5FA,
                          ), // Light Blue
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            horizontal: horizontalPadding,
                            vertical: 0,
                          ),
                          minimumSize: Size(0, buttonHeight),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_customerLocation != null) ...[
                    SizedBox(width: isSmallScreen ? 6 : 8),
                    Expanded(
                      child: SizedBox(
                        height: buttonHeight,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => JobMapView(
                                  initialCustomerLocation: _customerLocation!,
                                  initialCustomerId: widget.customer.id,
                                ),
                              ),
                            );
                          },
                          icon: Icon(Icons.map, size: iconSize),
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              "Haritada Aç",
                              style: TextStyle(
                                fontSize: fontSize,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(
                              0xFF60A5FA,
                            ), // Light Blue
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                              horizontal: horizontalPadding,
                              vertical: 0,
                            ),
                            minimumSize: Size(0, buttonHeight),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Taksit Ödemeleri Bölümü

