import "package:flutter/material.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:intl/intl.dart";
import "package:mobile/widgets/admin_app_bar.dart";

import "../../../../core/error/error_handler.dart";
import "../../../dashboard/presentation/home_page_provider.dart";
import "../../application/job_list_notifier.dart";
import "../../application/personnel_list_notifier.dart";
import "../../data/admin_repository.dart";
import "../../data/models/job.dart";

final _jobDetailProvider = FutureProvider.family<Job, String>((ref, jobId) {
  final repository = ref.read(adminRepositoryProvider);
  return repository.fetchJobDetail(jobId);
});

class AdminJobDetailPage extends ConsumerStatefulWidget {
  const AdminJobDetailPage({super.key, required this.jobId, this.initialJob});

  final String jobId;
  final Job? initialJob;

  @override
  ConsumerState<AdminJobDetailPage> createState() => _AdminJobDetailPageState();
}

class _AdminJobDetailPageState extends ConsumerState<AdminJobDetailPage> {
  @override
  Widget build(BuildContext context) {
    // Try to use initialJob, otherwise fetch from API
    final initialJob = widget.initialJob;
    if (initialJob != null) {
      return _buildContent(initialJob);
    }

    // Fetch job from API if not provided
    final jobFuture = ref.watch(_jobDetailProvider(widget.jobId));
    return jobFuture.when(
      data: (job) => _buildContent(job),
      loading: () => Scaffold(
        appBar: const AdminAppBar(title: Text("İş Detayı")),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: const AdminAppBar(title: Text("İş Detayı")),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("Hata: $error"),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () =>
                    ref.invalidate(_jobDetailProvider(widget.jobId)),
                child: const Text("Tekrar Dene"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(Job job) {
    return Scaffold(
      appBar: AdminAppBar(
        title: Text(job.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            tooltip: "Personel Ata",
            onPressed: () => _showAssignPersonnelSheet(job),
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: "Düzenle",
            onPressed: () => _showEditSheet(job),
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: "Sil",
            onPressed: () => _deleteJob(job),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Section(
            title: "Genel Bilgi",
            children: [
              _Row("Durum", _getStatusText(job.status)),
              _Row(
                "Planlanan Tarih",
                job.scheduledAt != null
                    ? DateFormat(
                        "dd MMM yyyy HH:mm",
                      ).format(job.scheduledAt!.toLocal())
                    : "-",
              ),
              if (job.deliveredAt != null)
                _Row(
                  "Teslim Tarihi",
                  DateFormat(
                    "dd MMM yyyy HH:mm",
                  ).format(job.deliveredAt!.toLocal()),
                ),
              _Row("Adres", job.location?.address ?? job.customer.address),
              _Row("Yapılan İşlem", job.title),
              if (job.materials != null && job.materials!.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  "Kullanılan Malzemeler",
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                ...job.materials!.map(
                  (m) => _Row(m.inventoryItemName, "${m.quantity} adet"),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          _Section(
            title: "Müşteri",
            children: [
              _Row("İsim", job.customer.name),
              _Row("Telefon", job.customer.phone),
              _Row("Adres", job.customer.address),
            ],
          ),
          const SizedBox(height: 16),
          if (job.assignments.isNotEmpty)
            _Section(
              title: "Atanan Personeller",
              children: job.assignments
                  .map((p) => _Row("Personel", p.personnelName))
                  .toList(),
            ),
          if (job.price != null ||
              job.paymentStatus != null ||
              job.collectedAmount != null)
            _Section(
              title: "Ödeme Bilgileri",
              children: [
                if (job.price != null)
                  _Row("Ücret", "${job.price!.toStringAsFixed(2)} ₺"),
                if (job.paymentStatus != null)
                  _Row(
                    "Ödeme Durumu",
                    _getPaymentStatusText(job.paymentStatus!),
                  ),
                if (job.collectedAmount != null)
                  _Row(
                    "Tahsil Edilen",
                    "${job.collectedAmount!.toStringAsFixed(2)} ₺",
                  ),
              ],
            ),
          if (job.notes != null && job.notes!.isNotEmpty)
            _Section(title: "Notlar", children: [Text(job.notes!)]),
          if (job.maintenanceDueAt != null)
            _Section(
              title: "Bakım Bilgileri",
              children: [
                _Row(
                  "Bakım Tarihi",
                  DateFormat(
                    "dd MMM yyyy",
                  ).format(job.maintenanceDueAt!.toLocal()),
                ),
                _Row(
                  "Kalan Süre",
                  _getMaintenanceDaysRemaining(job.maintenanceDueAt!),
                ),
              ],
            ),
          if (job.deliveryMediaUrls != null &&
              job.deliveryMediaUrls!.isNotEmpty)
            _Section(
              title: "Teslim Fotoğrafları",
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: job.deliveryMediaUrls!.map((url) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        url,
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 100,
                          height: 100,
                          color: Colors.grey.shade300,
                          child: const Icon(Icons.broken_image),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          // Fatura Oluştur butonu - sadece DELIVERED işler için
          if (job.status == "DELIVERED") ...[
            const SizedBox(height: 16),
            Card(
              color: const Color(0xFF10B981).withValues(alpha: 0.05),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      "Fatura",
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: FilledButton.icon(
                        onPressed: () => _createInvoice(context, job),
                        icon: const Icon(Icons.receipt),
                        label: const Text("Fatura Oluştur"),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 24,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          // Bottom padding for phones with navigation buttons
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Future<void> _createInvoice(BuildContext context, Job job) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Generate and open PDF (opens directly from URL, never saved to device)
      final repository = ref.read(adminRepositoryProvider);
      await repository.generateInvoicePdf(job.id);

      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // Refresh job detail and job list
      ref.invalidate(_jobDetailProvider(widget.jobId));
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

  String _getStatusText(String status) {
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

  String _getPaymentStatusText(String status) {
    switch (status.toUpperCase()) {
      case "PAID":
        return "Ödendi";
      case "PARTIAL":
        return "Kısmi Ödeme";
      case "NOT_PAID":
        return "Ödenmedi";
      default:
        return status;
    }
  }

  String _getMaintenanceDaysRemaining(DateTime dueDate) {
    final now = DateTime.now();
    final difference = dueDate.difference(now).inDays;
    if (difference < 0) {
      return "Bakım kaçırıldı (${difference.abs()} gün önce)";
    } else if (difference == 0) {
      return "Bugün";
    } else if (difference <= 1) {
      return "1 gün kaldı";
    } else if (difference <= 3) {
      return "$difference gün kaldı";
    } else if (difference <= 7) {
      return "$difference gün kaldı";
    } else {
      return "$difference gün kaldı";
    }
  }

  Future<void> _showAssignPersonnelSheet(Job job) async {
    await showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: _PersonnelAssignmentSheet(job: job),
      ),
    );
  }

  Future<void> _showEditSheet(Job job) async {
    final titleController = TextEditingController(text: job.title);
    final customerNameController = TextEditingController(
      text: job.customer.name,
    );
    final customerPhoneController = TextEditingController(
      text: job.customer.phone,
    );
    final customerAddressController = TextEditingController(
      text: job.customer.address,
    );
    final notesController = TextEditingController();
    final priceController = TextEditingController();
    DateTime? scheduledAt = job.scheduledAt;
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: StatefulBuilder(
              builder: (context, setModalState) {
                return Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "İş Düzenle",
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.close),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: titleController,
                          decoration: const InputDecoration(
                              labelText: "Başlık",
                              labelStyle: TextStyle(color: Colors.black),
                              floatingLabelStyle: TextStyle(color: Colors.black)),
                          validator: (value) =>
                              value == null || value.trim().length < 2
                                  ? "Başlık girin"
                                  : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: customerNameController,
                          decoration: const InputDecoration(
                            labelText: "Müşteri Adı",
                            labelStyle: TextStyle(color: Colors.black),
                            floatingLabelStyle: TextStyle(color: Colors.black),
                          ),
                          validator: (value) =>
                              value == null || value.trim().length < 2
                                  ? "Müşteri adı girin"
                                  : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: customerPhoneController,
                          decoration: const InputDecoration(
                              labelText: "Telefon",
                              labelStyle: TextStyle(color: Colors.black),
                              floatingLabelStyle: TextStyle(color: Colors.black)),
                          keyboardType: TextInputType.phone,
                          validator: (value) =>
                              value == null || value.trim().length < 6
                                  ? "Telefon girin"
                                  : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: customerAddressController,
                          decoration: const InputDecoration(
                              labelText: "Adres",
                              labelStyle: TextStyle(color: Colors.black),
                              floatingLabelStyle: TextStyle(color: Colors.black)),
                          validator: (value) =>
                              value == null || value.trim().length < 5
                                  ? "Adres girin"
                                  : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          readOnly: true,
                          controller: TextEditingController(
                            text: scheduledAt != null
                                ? DateFormat("dd.MM.yyyy").format(scheduledAt!)
                                : "",
                          ),
                          decoration: InputDecoration(
                            labelText: "Planlanan Tarih",
                            hintText: "Tarih seçin",
                            labelStyle: const TextStyle(color: Colors.black),
                            floatingLabelStyle: const TextStyle(color: Colors.black),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.calendar_today),
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: scheduledAt ?? DateTime.now(),
                                  firstDate: DateTime.now().subtract(
                                    const Duration(days: 365),
                                  ),
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 365),
                                  ),
                                );
                                if (picked != null) {
                                  setModalState(() {
                                    scheduledAt = picked;
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: notesController,
                          decoration: const InputDecoration(
                            labelText: "Notlar (opsiyonel)",
                            labelStyle: TextStyle(color: Colors.black),
                            floatingLabelStyle: TextStyle(color: Colors.black),
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: priceController,
                          decoration: const InputDecoration(
                            labelText: "Ücret (₺) (opsiyonel)",
                            labelStyle: TextStyle(color: Colors.black),
                            floatingLabelStyle: TextStyle(color: Colors.black),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: () async {
                              if (!formKey.currentState!.validate()) return;
                              final repo = ref.read(adminRepositoryProvider);
                              final messenger = ScaffoldMessenger.of(context);
                              final navigator = Navigator.of(context);
                              try {
                                await repo.updateJob(
                                  id: job.id,
                                  title: titleController.text.trim(),
                                  customerName: customerNameController.text
                                      .trim(),
                                  customerPhone: customerPhoneController.text
                                      .trim(),
                                  customerAddress: customerAddressController.text
                                      .trim(),
                                  scheduledAt: scheduledAt,
                                  notes: notesController.text.trim().isEmpty
                                      ? null
                                      : notesController.text.trim(),
                                  price: priceController.text.trim().isEmpty
                                      ? null
                                      : double.tryParse(
                                          priceController.text.trim(),
                                        ),
                                );
                                ref.invalidate(jobListProvider);
                                ref.invalidate(_jobDetailProvider(widget.jobId));
                                navigator.pop();
                                messenger.showSnackBar(
                                  const SnackBar(content: Text("İş güncellendi")),
                                );
                              } catch (error) {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text("Güncelleme başarısız: $error"),
                                  ),
                                );
                              }
                            },
                            child: const Text("Kaydet"),
                          ),
                        ),
                        SizedBox(
                          height: MediaQuery.of(context).viewInsets.bottom,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _deleteJob(Job job) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("İşi Sil"),
        content: Text("${job.title} işini silmek istediğinize emin misiniz?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Vazgeç"),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Sil"),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ref.read(adminRepositoryProvider).deleteJob(job.id);
      ref.invalidate(jobListProvider);
      navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text("${job.title} silindi")));
    } catch (error) {
      ErrorHandler.showError(context, error);
    }
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
          Expanded(flex: 3, child: Text(value)),
        ],
      ),
    );
  }
}

class _PersonnelAssignmentSheet extends ConsumerWidget {
  const _PersonnelAssignmentSheet({required this.job});

  final Job job;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final personnelState = ref.watch(personnelListProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle removed as it's a dialog now
          Row(
           mainAxisAlignment: MainAxisAlignment.spaceBetween,
           children: [
             Text(
              "Personel Seç",
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
             ),
             IconButton(
               onPressed: () => Navigator.of(context).pop(),
               icon: const Icon(Icons.close),
               padding: EdgeInsets.zero,
               constraints: const BoxConstraints(),
             ),
           ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: personnelState.when(
              data: (personnelList) {
                if (personnelList.isEmpty) {
                  return const Center(child: Text("Personel bulunamadı"));
                }
                final assignedPersonnelIds = job.assignments
                    .map((a) => a.personnelId)
                    .whereType<String>()
                    .toSet();
                return ListView.builder(
                  itemCount: personnelList.length,
                  itemBuilder: (context, index) {
                    final personnel = personnelList[index];
                    final isAssigned = assignedPersonnelIds.contains(
                      personnel.id,
                    );
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(
                            personnel.name.isNotEmpty
                                ? personnel.name[0].toUpperCase()
                                : "P",
                          ),
                        ),
                        title: Text(personnel.name),
                        subtitle: Text(personnel.phone),
                        trailing: isAssigned
                            ? const Chip(
                                label: Text("Atandı"),
                                backgroundColor: Color(0xFF10B981),
                              )
                            : FilledButton(
                                onPressed: () => _assignPersonnel(
                                  context,
                                  ref,
                                  personnel.id,
                                ),
                                child: const Text("İş Ata"),
                              ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (error, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("Hata: $error"),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => ref.refresh(personnelListProvider),
                      child: const Text("Tekrar Dene"),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _assignPersonnel(
    BuildContext context,
    WidgetRef ref,
    String personnelId,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Personel Ata"),
        content: const Text(
          "Bu personele iş atamak istediğinize emin misiniz?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("İptal"),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Onayla"),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      // Mevcut atanan personelleri al
      final currentPersonnelIds = job.assignments
          .map((a) => a.personnelId)
          .whereType<String>()
          .toList();

      // Yeni personeli ekle (zaten varsa ekleme)
      if (!currentPersonnelIds.contains(personnelId)) {
        currentPersonnelIds.add(personnelId);
      }

      await ref
          .read(adminRepositoryProvider)
          .assignPersonnelToJob(
            jobId: job.id,
            personnelIds: currentPersonnelIds,
          );
      await ref.read(jobListProvider.notifier).refresh();
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Personel atandı")));
      }
    } catch (error) {
      if (context.mounted) {
        ErrorHandler.showError(context, error);
      }
    }
  }
}
