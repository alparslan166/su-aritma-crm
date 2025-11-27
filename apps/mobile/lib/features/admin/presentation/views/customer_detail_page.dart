import "dart:async";

import "package:dio/dio.dart";
import "package:flutter/material.dart";
import "package:flutter_map/flutter_map.dart";
import "package:geocoding/geocoding.dart";
import "package:go_router/go_router.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:intl/intl.dart";
import "package:latlong2/latlong.dart";
import "package:open_file/open_file.dart";
import "package:url_launcher/url_launcher.dart";
import "package:mobile/widgets/admin_app_bar.dart";

import "../../application/customer_list_notifier.dart";
import "../../application/job_list_notifier.dart";
import "../../data/admin_repository.dart";
import "../../data/models/customer.dart";
import "edit_customer_sheet.dart";
import "job_map_view.dart";

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
          _Section(
            title: "Müşteri Bilgileri",
            children: [
              if (customer.createdAt != null)
                _Row(
                  "Kayıt Tarihi",
                  DateFormat("dd MMM yyyy").format(customer.createdAt!),
                ),
              _Row("İsim", customer.name),
              _Row("Telefon", customer.phone),
              if (customer.email != null) _Row("E-posta", customer.email!),
              _Row("Adres", customer.address),
              _StatusRow(
                "Durum",
                customer.status,
                onChanged: (newStatus) =>
                    _updateCustomerStatus(customer, newStatus),
              ),
            ],
          ),
          if (customer.nextMaintenanceDate != null) ...[
            const SizedBox(height: 24),
            _Section(
              title: "Bakım Bilgileri",
              children: [
                _Row(
                  "Sonraki Bakım Tarihi",
                  DateFormat(
                    "dd MMM yyyy",
                  ).format(customer.nextMaintenanceDate!),
                ),
                if (customer.maintenanceTimeRemaining != null)
                  _Row(
                    "Kalan Süre",
                    customer.maintenanceTimeRemaining!,
                    valueColor:
                        customer.nextMaintenanceDate!.isBefore(DateTime.now())
                        ? Colors.red
                        : customer.nextMaintenanceDate!
                                  .difference(DateTime.now())
                                  .inDays <=
                              7
                        ? Colors.orange
                        : null,
                  ),
              ],
            ),
          ],
          if (customer.hasDebt) ...[
            const SizedBox(height: 24),
            _Section(
              title: "Borç Bilgileri",
              children: [
                if (customer.debtAmount != null)
                  _Row(
                    "Toplam Borç",
                    "${customer.debtAmount!.toStringAsFixed(2)} TL",
                  ),
                if (customer.paidDebtAmount != null &&
                    customer.paidDebtAmount! > 0)
                  _Row(
                    "Ödenen Borç",
                    "${customer.paidDebtAmount!.toStringAsFixed(2)} TL",
                  ),
                if (customer.hasInstallment &&
                    customer.installmentCount != null)
                  _Row("Taksit Sayısı", "${customer.installmentCount} taksit"),
                if (customer.remainingDebtAmount != null)
                  _Row(
                    "Kalan Borç",
                    "${customer.remainingDebtAmount!.toStringAsFixed(2)} TL",
                  ),
                if (customer.nextDebtDate != null) ...[
                  _Row(
                    "Sonraki Borç Tarihi",
                    DateFormat("dd MMM yyyy").format(customer.nextDebtDate!),
                  ),
                  if (customer.nextDebtDate!.isBefore(DateTime.now())) ...[
                    _Row(
                      "Geçen Süre",
                      _getOverdueDays(customer.nextDebtDate!),
                      valueColor: Colors.red,
                    ),
                  ],
                ],
                // Borç durumu: Sadece müşteri seviyesinde borç varsa, kalan borç > 0 ise ve ödeme tarihi geçmişse göster
                if (customer.hasDebt &&
                    customer.remainingDebtAmount != null &&
                    customer.remainingDebtAmount! > 0 &&
                    customer.nextDebtDate != null &&
                    customer.nextDebtDate!.isBefore(DateTime.now())) ...[
                  _Row("Borç Durumu", "Ödeme gecikmiş", valueColor: Colors.red),
                ],
              ],
            ),
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
      ref.invalidate(customerListProvider);
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
        messenger.showSnackBar(
          SnackBar(content: Text("Durum güncellenemedi: $error")),
        );
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
      ref.invalidate(customerListProvider);
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
      ref.invalidate(customerListProvider);
      ref.invalidate(jobListProvider);
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

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

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
              style: TextStyle(fontWeight: FontWeight.w500, color: valueColor),
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

      await ref
          .read(adminRepositoryProvider)
          .payCustomerDebt(
            id: widget.customerId,
            amount: amount,
            installmentCount: installmentCount,
          );

      // Refresh customer detail and wait for it to complete
      // Invalidate to trigger rebuild, then wait for data to load
      ref.invalidate(customerDetailProvider(widget.customerId));
      // Wait for the provider to reload so UI updates immediately
      await ref.read(customerDetailProvider(widget.customerId).future);

      // Also refresh customer list to update filters (invalidate yerine refresh kullan)
      // Bu sayede loading state'ine düşmez, sadece liste güncellenir
      // Eğer customer list sayfası açıksa, orada loading görünmez
      ref.read(customerListProvider.notifier).refresh(showLoading: false);

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Hata: $error")));
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
      // Generate PDF
      final repository = ref.read(adminRepositoryProvider);
      final pdfPath = await repository.generateInvoicePdf(jobId);

      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // Open PDF
      await OpenFile.open(pdfPath);

      // Refresh customer detail and job list
      ref.invalidate(customerDetailProvider(customerId));
      ref.invalidate(jobListProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Fatura oluşturuldu ve açıldı")),
        );
      }
    } catch (error) {
      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Fatura oluşturulamadı: $error")),
        );
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

String _getOverdueDays(DateTime dueDate) {
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
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.map, color: Color(0xFF2563EB)),
                const SizedBox(width: 8),
                Text(
                  "Konum",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (_error != null || _isLoading)
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _isLoading ? null : _loadLocation,
                    tooltip: "Yeniden Yükle",
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
            child: SizedBox(
              height: 250,
              child: _isLoading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : _error != null
                  ? SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Colors.red,
                              size: 48,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: _loadLocation,
                              icon: const Icon(Icons.refresh),
                              label: const Text("Tekrar Dene"),
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
                                    width: 40,
                                    height: 40,
                                    child: const Icon(
                                      Icons.location_on,
                                      color: Color(0xFF2563EB),
                                      size: 40,
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
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                ElevatedButton.icon(
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
                  icon: const Icon(Icons.place, size: 18),
                  label: const Text("Google Maps ile Aç"),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
                if (_customerLocation != null) ...[
                  const Spacer(),
                  ElevatedButton.icon(
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
                    icon: const Icon(Icons.map, size: 18),
                    label: const Text("Haritada Aç"),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
