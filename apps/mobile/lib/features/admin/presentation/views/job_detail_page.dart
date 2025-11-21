import "package:flutter/material.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:intl/intl.dart";
import "package:mobile/widgets/admin_app_bar.dart";

import "../../application/job_list_notifier.dart";
import "../../application/personnel_list_notifier.dart";
import "../../data/admin_repository.dart";
import "../../data/models/job.dart";

final _jobDetailProvider = FutureProvider.family<Job, String>((ref, jobId) {
  final repository = ref.read(adminRepositoryProvider);
  return repository.fetchJobDetail(jobId);
});

class AdminJobDetailPage extends ConsumerStatefulWidget {
  const AdminJobDetailPage({
    super.key,
    required this.jobId,
    this.initialJob,
  });

  final String jobId;
  final Job? initialJob;

  @override
  ConsumerState<AdminJobDetailPage> createState() =>
      _AdminJobDetailPageState();
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
        appBar: const AdminAppBar(title: "İş Detayı"),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: const AdminAppBar(title: "İş Detayı"),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("Hata: $error"),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(_jobDetailProvider(widget.jobId)),
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
        title: job.title,
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
              _Row("Durum", job.status),
              _Row(
                "Planlanan Tarih",
                job.scheduledAt != null
                    ? DateFormat("dd MMM yyyy HH:mm").format(job.scheduledAt!.toLocal())
                    : "-",
              ),
              _Row("Öncelik", job.priority?.toString() ?? "-"),
              _Row("Adres", job.location?.address ?? job.customer.address),
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
          if (job.price != null || job.paymentStatus != null || job.collectedAmount != null)
            _Section(
              title: "Ödeme Bilgileri",
              children: [
                if (job.price != null)
                  _Row("Ücret", "${job.price!.toStringAsFixed(2)} ₺"),
                if (job.paymentStatus != null)
                  _Row("Ödeme Durumu", job.paymentStatus!),
                if (job.collectedAmount != null)
                  _Row("Tahsil Edilen", "${job.collectedAmount!.toStringAsFixed(2)} ₺"),
              ],
            ),
          if (job.notes != null && job.notes!.isNotEmpty)
            _Section(
              title: "Notlar",
              children: [
                Text(job.notes!),
              ],
            ),
          if (job.materials != null && job.materials!.isNotEmpty)
            _Section(
              title: "Kullanılan Malzemeler",
              children: job.materials!.map((m) {
                final total = m.quantity * m.unitPrice;
                return _Row(
                  "${m.inventoryItemName} (${m.quantity} adet)",
                  "${total.toStringAsFixed(2)} ₺",
                );
              }).toList(),
            ),
          if (job.maintenanceDueAt != null)
            _Section(
              title: "Bakım Bilgileri",
              children: [
                _Row(
                  "Bakım Tarihi",
                  DateFormat("dd MMM yyyy").format(job.maintenanceDueAt!.toLocal()),
                ),
                _Row(
                  "Kalan Süre",
                  _getMaintenanceDaysRemaining(job.maintenanceDueAt!),
                ),
              ],
            ),
          if (job.deliveryMediaUrls != null && job.deliveryMediaUrls!.isNotEmpty)
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
        ],
      ),
    );
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
    final personnelState = ref.read(personnelListProvider);
    final personnelList = personnelState.value ?? [];
    if (personnelList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Personel bulunamadı")),
      );
      return;
    }
    final selectedIds = <String>{
      ...job.assignments.map((a) => a.personnelId).whereType<String>()
    };
    await showModalBottomSheet(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Personel Seç",
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    itemCount: personnelList.length,
                    itemBuilder: (context, index) {
                      final personnel = personnelList[index];
                      final isSelected = selectedIds.contains(personnel.id);
                      return CheckboxListTile(
                        title: Text(personnel.name),
                        subtitle: Text(personnel.phone),
                        value: isSelected,
                        onChanged: (value) {
                          setModalState(() {
                            if (value == true) {
                              selectedIds.add(personnel.id);
                            } else {
                              selectedIds.remove(personnel.id);
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () async {
                    try {
                      await ref.read(adminRepositoryProvider).assignPersonnelToJob(
                            jobId: job.id,
                            personnelIds: selectedIds.toList(),
                          );
                      await ref.read(jobListProvider.notifier).refresh();
                      if (context.mounted) {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Personel atandı")),
                        );
                      }
                    } catch (error) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Atama başarısız: $error")),
                        );
                      }
                    }
                  },
                  child: const Text("Ata"),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _showEditSheet(Job job) async {
    final titleController = TextEditingController(text: job.title);
    final customerNameController = TextEditingController(text: job.customer.name);
    final customerPhoneController = TextEditingController(text: job.customer.phone);
    final customerAddressController = TextEditingController(text: job.customer.address);
    final notesController = TextEditingController();
    final priceController = TextEditingController();
    final priorityController = TextEditingController(text: job.priority?.toString() ?? "");
    DateTime? scheduledAt = job.scheduledAt;
    final formKey = GlobalKey<FormState>();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "İş Düzenle",
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: titleController,
                        decoration: const InputDecoration(labelText: "Başlık"),
                        validator: (value) =>
                            value == null || value.trim().length < 2
                                ? "Başlık girin"
                                : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: customerNameController,
                        decoration: const InputDecoration(labelText: "Müşteri Adı"),
                        validator: (value) =>
                            value == null || value.trim().length < 2
                                ? "Müşteri adı girin"
                                : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: customerPhoneController,
                        decoration: const InputDecoration(labelText: "Telefon"),
                        keyboardType: TextInputType.phone,
                        validator: (value) =>
                            value == null || value.trim().length < 6
                                ? "Telefon girin"
                                : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: customerAddressController,
                        decoration: const InputDecoration(labelText: "Adres"),
                        validator: (value) =>
                            value == null || value.trim().length < 5
                                ? "Adres girin"
                                : null,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              "Planlanan tarih: ${scheduledAt != null ? DateFormat("dd MMM yyyy").format(scheduledAt!) : "Seçilmedi"}",
                            ),
                          ),
                          TextButton(
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
                            child: const Text("Seç"),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: notesController,
                        decoration: const InputDecoration(labelText: "Notlar (opsiyonel)"),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: priceController,
                        decoration: const InputDecoration(labelText: "Ücret (₺) (opsiyonel)"),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: priorityController,
                        decoration: const InputDecoration(labelText: "Öncelik (opsiyonel)"),
                        keyboardType: TextInputType.number,
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
                                customerName: customerNameController.text.trim(),
                                customerPhone: customerPhoneController.text.trim(),
                                customerAddress: customerAddressController.text.trim(),
                                scheduledAt: scheduledAt,
                                notes: notesController.text.trim().isEmpty
                                    ? null
                                    : notesController.text.trim(),
                                price: priceController.text.trim().isEmpty
                                    ? null
                                    : double.tryParse(priceController.text.trim()),
                                priority: priorityController.text.trim().isEmpty
                                    ? null
                                    : int.tryParse(priorityController.text.trim()),
                              );
                              ref.invalidate(jobListProvider);
                              ref.invalidate(_jobDetailProvider(widget.jobId));
                              navigator.pop();
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text("İş güncellendi"),
                                ),
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
      messenger.showSnackBar(SnackBar(content: Text("Silinemedi: $error")));
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
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(flex: 3, child: Text(value)),
        ],
      ),
    );
  }
}

