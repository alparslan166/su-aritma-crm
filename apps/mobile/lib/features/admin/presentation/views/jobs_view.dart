import "package:flutter/material.dart";
import "package:go_router/go_router.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:intl/intl.dart";
import "package:mobile/widgets/admin_app_bar.dart";
import "package:mobile/widgets/empty_state.dart";

import "../../../../core/error/error_handler.dart";
import "../../application/job_list_notifier.dart";
import "../../application/personnel_list_notifier.dart";
import "../../data/admin_repository.dart";
import "../../data/models/job.dart";
import "../widgets/job_card.dart";

enum JobStatusFilter { all, pending, inProgress }

class JobsView extends ConsumerStatefulWidget {
  const JobsView({super.key});

  @override
  ConsumerState<JobsView> createState() => _JobsViewState();
}

class _JobsViewState extends ConsumerState<JobsView> {
  JobStatusFilter _filter = JobStatusFilter.all;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(jobListProvider);
    final notifier = ref.read(jobListProvider.notifier);
    final content = state.when(
      data: (items) {
        final activeJobs = _activeOnly(items);
        final pendingJobs = activeJobs
            .where((j) => j.status == "PENDING")
            .length;
        final inProgressJobs = activeJobs
            .where((j) => j.status == "IN_PROGRESS")
            .length;

        // Filtreleme uygula
        final filteredJobs = _filterJobs(activeJobs, _filter);

        return RefreshIndicator(
          onRefresh: notifier.refresh,
          child: CustomScrollView(
            slivers: [
              // İstatistik kartları
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          icon: Icons.pending_outlined,
                          iconColor: const Color(0xFF2563EB),
                          title: "Beklemede",
                          count: pendingJobs,
                          isSelected: _filter == JobStatusFilter.pending,
                          onTap: () {
                            setState(() {
                              _filter = _filter == JobStatusFilter.pending
                                  ? JobStatusFilter.all
                                  : JobStatusFilter.pending;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.work_outline,
                          iconColor: const Color(0xFFF59E0B),
                          title: "Devam Ediyor",
                          count: inProgressJobs,
                          isSelected: _filter == JobStatusFilter.inProgress,
                          onTap: () {
                            setState(() {
                              _filter = _filter == JobStatusFilter.inProgress
                                  ? JobStatusFilter.all
                                  : JobStatusFilter.inProgress;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // İş listesi
              if (filteredJobs.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 48,
                      horizontal: 24,
                    ),
                    child: EmptyState(
                      icon: Icons.work_outline,
                      title: _filter == JobStatusFilter.all
                          ? "Aktif iş bulunmuyor"
                          : _filter == JobStatusFilter.pending
                          ? "Beklemede iş bulunmuyor"
                          : "Devam eden iş bulunmuyor",
                      subtitle: _filter == JobStatusFilter.all
                          ? "Yeni iş oluşturduğunuzda burada listelenecek."
                          : "Bu durumda iş bulunmuyor.",
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final job = filteredJobs[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: RepaintBoundary(
                          child: JobCard(
                            job: job,
                            onTap: () => context.push(
                              "/admin/jobs/${job.id}",
                              extra: job,
                            ),
                          ),
                        ),
                      );
                    }, childCount: filteredJobs.length),
                  ),
                ),
            ],
          ),
        );
      },
      error: (error, _) => _JobsError(
        message: ErrorHandler.getUserFriendlyMessage(error),
        onRetry: () => ref.read(jobListProvider.notifier).refresh(),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
    return Scaffold(
      appBar: const AdminAppBar(title: Text("Aktif İşler")),
      body: content,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: "add",
        onPressed: () => _openAddJobSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text("Yeni İş Ata"),
        backgroundColor: const Color(0xFF2563EB),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  void _openAddJobSheet(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => const Dialog(
        insetPadding: EdgeInsets.all(16),
        child: _JobFormSheet(),
      ),
    );
  }
}

List<Job> _activeOnly(List<Job> jobs) {
  return jobs
      .where((job) => job.status == "PENDING" || job.status == "IN_PROGRESS")
      .toList();
}

List<Job> _filterJobs(List<Job> jobs, JobStatusFilter filter) {
  switch (filter) {
    case JobStatusFilter.pending:
      return jobs.where((job) => job.status == "PENDING").toList();
    case JobStatusFilter.inProgress:
      return jobs.where((job) => job.status == "IN_PROGRESS").toList();
    case JobStatusFilter.all:
      return jobs;
  }
}

// İstatistik kartı widget'ı
class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.count,
    this.isSelected = false,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final int count;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? iconColor.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? iconColor : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? iconColor.withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: 0.03),
              blurRadius: isSelected ? 8 : 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "$count",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: iconColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
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
      ErrorHandler.showError(context, error);
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
        : DateFormat("dd MMM yyyy", "tr_TR").format(_scheduledAt!);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("İş Ekle", style: Theme.of(context).textTheme.titleLarge),
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
                key: const Key("job-title-field"),
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: "Başlık",
                  labelStyle: TextStyle(color: Colors.black),
                  floatingLabelStyle: TextStyle(color: Colors.black),
                ),
                textCapitalization: TextCapitalization.sentences,
                validator: (value) => value == null || value.trim().length < 2
                    ? "Başlık girin"
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key("customer-name-field"),
                controller: _customerNameController,
                decoration: const InputDecoration(labelText: "Müşteri adı"),
                textCapitalization: TextCapitalization.words,
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
              TextFormField(
                key: const Key("customer-address-field"),
                controller: _customerAddressController,
                decoration: const InputDecoration(
                  labelText: "Adres",
                  hintText: "Şehir, ilçe, mahalle, sokak, bina no",
                ),
                maxLines: 2,
                validator: (value) => value == null || value.trim().length < 5
                    ? "Adres girin"
                    : null,
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
                      Icon(
                        Icons.check_circle,
                        color: Colors.green.shade700,
                        size: 20,
                      ),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Personel bulunamadı")));
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
