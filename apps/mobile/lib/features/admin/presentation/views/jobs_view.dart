import "package:flutter/material.dart";
import "package:geocoding/geocoding.dart";
import "package:go_router/go_router.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:intl/intl.dart";
import "package:mobile/widgets/empty_state.dart";

import "../../application/job_list_notifier.dart";
import "../../application/personnel_list_notifier.dart";
import "../../data/admin_repository.dart";
import "../../data/models/job.dart";
import "../widgets/job_card.dart";

class JobsView extends ConsumerWidget {
  const JobsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(jobListProvider);
    final notifier = ref.read(jobListProvider.notifier);
    final content = state.when(
      data: (items) {
        final activeJobs = _activeOnly(items);
        if (activeJobs.isEmpty) {
          return RefreshIndicator(
            onRefresh: notifier.refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
              children: const [
                SizedBox(height: 120),
                EmptyState(
                  icon: Icons.work_outline,
                  title: "Aktif iş bulunmuyor",
                  subtitle: "Yeni iş oluşturduğunuzda burada listelenecek.",
                ),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: notifier.refresh,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            itemCount: activeJobs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            cacheExtent: 500,
            addAutomaticKeepAlives: false,
            addRepaintBoundaries: true,
            itemBuilder: (context, index) {
              final job = activeJobs[index];
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
      error: (error, _) => _JobsError(
        message: error.toString(),
        onRetry: () => ref.read(jobListProvider.notifier).refresh(),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
    final padding = MediaQuery.paddingOf(context).bottom;
    return Stack(
      children: [
        Positioned.fill(child: content),
        Positioned(
          right: 16,
          bottom: 16 + padding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FloatingActionButton(
                heroTag: "assign",
                onPressed: () => _showAssignPersonnelDialog(context, ref),
                tooltip: "Personel Ata",
                child: const Icon(Icons.person_add),
              ),
              const SizedBox(height: 8),
              FloatingActionButton.extended(
                heroTag: "add",
                onPressed: () => _openAddJobSheet(context, ref),
                icon: const Icon(Icons.add),
                label: const Text("İş Ekle"),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showAssignPersonnelDialog(BuildContext context, WidgetRef ref) {
    final jobState = ref.read(jobListProvider);
    final jobs = jobState.value ?? [];
    if (jobs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Atanabilir iş bulunamadı")),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("İş Seç"),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: jobs.length,
            itemBuilder: (context, index) {
              final job = jobs[index];
              return ListTile(
                title: Text(job.title),
                subtitle: Text(job.customer.name),
                onTap: () {
                  Navigator.of(context).pop();
                  _openAssignPersonnelSheet(context, ref, job);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _openAssignPersonnelSheet(
    BuildContext context,
    WidgetRef ref,
    Job job,
  ) {
    final personnelState = ref.read(personnelListProvider);
    final personnelList = personnelState.value ?? [];
    if (personnelList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Personel bulunamadı")),
      );
      return;
    }
    final selectedIds = <String>{...job.assignments.map((a) => a.personnelId).whereType<String>()};
    showModalBottomSheet(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
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
                          setState(() {
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

  void _openAddJobSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: const _JobFormSheet(),
      ),
    );
  }
}

List<Job> _activeOnly(List<Job> jobs) {
  return jobs
      .where((job) => job.status == "PENDING" || job.status == "IN_PROGRESS")
      .toList();
}

class _JobsError extends StatelessWidget {
  const _JobsError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.work_off, size: 40),
          const SizedBox(height: 8),
          Text(
            "İş listesi alınamadı",
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

class _JobFormSheet extends ConsumerStatefulWidget {
  const _JobFormSheet();

  @override
  ConsumerState<_JobFormSheet> createState() => _JobFormSheetState();
}

class _JobFormSheetState extends ConsumerState<_JobFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _customerNameController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final _customerAddressController = TextEditingController();
  final _customerEmailController = TextEditingController();
  final _notesController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  DateTime? _scheduledAt;
  bool _submitting = false;
  final _selectedPersonnelIds = <String>{};

  @override
  void dispose() {
    _titleController.dispose();
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _customerAddressController.dispose();
    _customerEmailController.dispose();
    _notesController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduledAt ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _scheduledAt = picked;
      });
    }
  }

  double? _parseDouble(String value) {
    if (value.trim().isEmpty) return null;
    return double.tryParse(value.trim());
  }

  Future<void> _geocodeAddress() async {
    final address = _customerAddressController.text.trim();
    if (address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lütfen önce adres girin")),
      );
      return;
    }

    try {
      setState(() {
        _submitting = true;
      });

      final locations = await locationFromAddress(address);
      if (!mounted) return;
      if (locations.isNotEmpty) {
        final location = locations.first;
        setState(() {
          _latitudeController.text = location.latitude.toStringAsFixed(6);
          _longitudeController.text = location.longitude.toStringAsFixed(6);
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Konum bulundu: ${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}",
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Adres için konum bulunamadı")),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Konum bulunamadı: $e")),
      );
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
    });
    try {
      await ref
          .read(adminRepositoryProvider)
          .createJob(
            title: _titleController.text.trim(),
            customerName: _customerNameController.text.trim(),
            customerPhone: _customerPhoneController.text.trim(),
            customerAddress: _customerAddressController.text.trim(),
            customerEmail: _customerEmailController.text.trim().isEmpty
                ? null
                : _customerEmailController.text.trim(),
            scheduledAt: _scheduledAt,
            notes: _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
            latitude: _parseDouble(_latitudeController.text),
            longitude: _parseDouble(_longitudeController.text),
            locationDescription: _customerAddressController.text.trim(),
            personnelIds: _selectedPersonnelIds.isEmpty
                ? null
                : _selectedPersonnelIds.toList(),
          );
      await ref.read(jobListProvider.notifier).refresh();
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Yeni iş oluşturuldu")));
    } catch (error) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("İş eklenemedi: $error")));
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateText = _scheduledAt == null
        ? "Seçilmedi"
        : DateFormat("dd MMM yyyy").format(_scheduledAt!);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("İş Ekle", style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key("job-title-field"),
                controller: _titleController,
                decoration: const InputDecoration(labelText: "Başlık"),
                validator: (value) => value == null || value.trim().length < 2
                    ? "Başlık girin"
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key("customer-name-field"),
                controller: _customerNameController,
                decoration: const InputDecoration(labelText: "Müşteri adı"),
                validator: (value) => value == null || value.trim().length < 2
                    ? "Müşteri adı zorunlu"
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key("customer-phone-field"),
                controller: _customerPhoneController,
                decoration: const InputDecoration(labelText: "Müşteri telefon"),
                keyboardType: TextInputType.phone,
                validator: (value) => value == null || value.trim().length < 6
                    ? "Telefon girin"
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key("customer-email-field"),
                controller: _customerEmailController,
                decoration: const InputDecoration(
                  labelText: "Müşteri e-posta (opsiyonel)",
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          key: const Key("customer-address-field"),
                          controller: _customerAddressController,
                          decoration: const InputDecoration(
                            labelText: "Adres",
                            hintText: "örn: İstanbul, Kadıköy, Bağdat Caddesi",
                          ),
                          validator: (value) => value == null || value.trim().length < 5
                              ? "Adres girin"
                              : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.map),
                        tooltip: "Adresten konum bul",
                        onPressed: _submitting ? null : _geocodeAddress,
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.1),
                        ),
                      ),
                    ],
                  ),
                  if (_latitudeController.text.isNotEmpty ||
                      _longitudeController.text.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green.shade700, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "Konum bulundu: ${_latitudeController.text}, ${_longitudeController.text}",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: Text("Planlanan tarih: $dateText")),
                  TextButton(onPressed: _pickDate, child: const Text("Seç")),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key("job-notes-field"),
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: "Notlar (opsiyonel)",
                ),
                minLines: 2,
                maxLines: 4,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      key: const Key("job-latitude-field"),
                      controller: _latitudeController,
                      decoration: const InputDecoration(
                        labelText: "Latitude (opsiyonel)",
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        signed: true,
                        decimal: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      key: const Key("job-longitude-field"),
                      controller: _longitudeController,
                      decoration: const InputDecoration(
                        labelText: "Longitude (opsiyonel)",
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        signed: true,
                        decimal: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _selectPersonnel(context),
                icon: const Icon(Icons.person_add),
                label: Text(
                  _selectedPersonnelIds.isEmpty
                      ? "Personel Ata (Opsiyonel)"
                      : "${_selectedPersonnelIds.length} personel seçildi",
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text("Kaydet"),
                ),
              ),
              SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectPersonnel(BuildContext context) async {
    final personnelState = ref.read(personnelListProvider);
    final personnelList = personnelState.value ?? [];
    if (personnelList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Personel bulunamadı")),
      );
      return;
    }
    final tempSelectedIds = <String>{..._selectedPersonnelIds};
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 16,
              right: 16,
              top: 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Personel Seç (Opsiyonel)",
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.6,
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: personnelList.length,
                    itemBuilder: (context, index) {
                      final personnel = personnelList[index];
                      final isSelected = tempSelectedIds.contains(personnel.id);
                      return CheckboxListTile(
                        title: Text(personnel.name),
                        subtitle: Text(personnel.phone),
                        value: isSelected,
                        onChanged: (value) {
                          setModalState(() {
                            if (value == true) {
                              tempSelectedIds.add(personnel.id);
                            } else {
                              tempSelectedIds.remove(personnel.id);
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    setState(() {
                      _selectedPersonnelIds.clear();
                      _selectedPersonnelIds.addAll(tempSelectedIds);
                    });
                    Navigator.of(context).pop();
                  },
                  child: const Text("Tamam"),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
