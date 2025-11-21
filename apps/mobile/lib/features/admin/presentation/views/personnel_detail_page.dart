import "package:flutter/material.dart";
import "package:flutter_map/flutter_map.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:intl/intl.dart";
import "package:latlong2/latlong.dart";
import "package:mobile/widgets/admin_app_bar.dart";

import "../../application/job_list_notifier.dart";
import "../../application/personnel_detail_provider.dart";
import "../../application/personnel_list_notifier.dart";
import "../../data/admin_repository.dart";
import "../../data/models/job.dart";
import "../../data/models/personnel.dart";
import "job_map_view.dart";

class AdminPersonnelDetailPage extends ConsumerStatefulWidget {
  const AdminPersonnelDetailPage({
    super.key,
    required this.personnelId,
    this.initialPersonnel,
  });

  final String personnelId;
  final Personnel? initialPersonnel;

  @override
  ConsumerState<AdminPersonnelDetailPage> createState() =>
      _AdminPersonnelDetailPageState();
}

class _AdminPersonnelDetailPageState
    extends ConsumerState<AdminPersonnelDetailPage> {
  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(personnelDetailProvider(widget.personnelId));
    return detail.when(
      data: (personnel) => _DetailContent(
        personnel: personnel,
        onEdit: () => _showEditSheet(personnel),
        onResetCode: () => _resetCode(personnel.id, personnel.name),
        onDelete: () => _deletePersonnel(personnel.id, personnel.name),
        onAssignJob: () => _openAssignJobSheet(personnel.id),
        onManageLeaves: () => _showLeavesSheet(personnel),
      ),
      loading: () => Scaffold(
        appBar: AdminAppBar(title: widget.initialPersonnel?.name ?? "Personel"),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: const AdminAppBar(title: "Personel Detayı"),
        body: Center(child: Text(error.toString())),
      ),
    );
  }

  Future<void> _showEditSheet(Personnel personnel) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: _EditPersonnelSheet(
          personnel: personnel,
          personnelId: widget.personnelId,
        ),
      ),
    );
  }

  Future<void> _resetCode(String id, String name) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Giriş Kodunu Sıfırla"),
        content: Text(
          "$name için yeni bir giriş kodu oluşturmak istediğinize emin misiniz? Eski kod geçersiz olacaktır.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("İptal"),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text("Kodu Sıfırla"),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final repo = ref.read(adminRepositoryProvider);
    try {
      final newCode = await repo.resetPersonnelCode(id);
      ref.invalidate(personnelDetailProvider(widget.personnelId));
      ref.invalidate(personnelListProvider);
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text("Yeni giriş kodu: $newCode")),
        );
      }
    } catch (error) {
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text("Kod sıfırlanamadı: $error")),
        );
      }
    }
  }

  Future<void> _deletePersonnel(String id, String name) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Personeli Sil"),
        content: Text("$name kaydını silmek istediğinize emin misiniz?"),
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
      await ref.read(adminRepositoryProvider).deletePersonnel(id);
      ref.invalidate(personnelListProvider);
      navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text("$name silindi")));
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text("Silinemedi: $error")));
    }
  }

  Future<void> _openAssignJobSheet(String personnelId) async {
    final jobState = ref.read(jobListProvider);
    final jobs = jobState.value ?? [];
    // Sadece yapılmamış ve personel atanmamış işleri filtrele
    final availableJobs = jobs.where((job) {
      // Durum kontrolü: PENDING veya IN_PROGRESS olmalı
      final isActive = job.status == "PENDING" || job.status == "IN_PROGRESS";
      if (!isActive) return false;

      // Personel atanmamış işler: assignments boş veya tüm assignments'ların personnelId'si null/boş
      final hasNoPersonnel =
          job.assignments.isEmpty ||
          job.assignments.every(
            (assignment) =>
                assignment.personnelId == null ||
                assignment.personnelId!.trim().isEmpty,
          );

      return hasNoPersonnel;
    }).toList();
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        if (availableJobs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Text("Atanabilir iş bulunamadı."),
          );
        }
        return ListView(
          children: availableJobs
              .map(
                (job) => ListTile(
                  title: Text("${job.customer.name} - ${job.title}"),
                  subtitle: Text("Durum: ${job.status}"),
                  onTap: () async {
                    Navigator.of(context).pop();
                    await _assignPersonnelToJob(job, personnelId);
                  },
                ),
              )
              .toList(),
        );
      },
    );
  }

  Future<void> _assignPersonnelToJob(Job job, String personnelId) async {
    final repo = ref.read(adminRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final jobDetail = await repo.fetchJobDetail(job.id);
      final ids = jobDetail.assignments
          .map((assignment) => assignment.personnelId)
          .whereType<String>()
          .toSet();
      ids.add(personnelId);
      await repo.assignPersonnelToJob(
        jobId: job.id,
        personnelIds: ids.toList(),
      );
      ref.invalidate(jobListProvider);
      messenger.showSnackBar(
        SnackBar(content: Text("${job.title} işine atandı")),
      );
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text("İş atanamadı: $error")));
    }
  }

  Future<void> _showLeavesSheet(Personnel personnel) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: _LeavesManagementSheet(
          personnelId: personnel.id,
          personnelName: personnel.name,
        ),
      ),
    );
  }
}

class _DetailContent extends StatelessWidget {
  const _DetailContent({
    required this.personnel,
    required this.onEdit,
    required this.onResetCode,
    required this.onDelete,
    required this.onAssignJob,
    required this.onManageLeaves,
  });

  final Personnel personnel;
  final VoidCallback onEdit;
  final VoidCallback onResetCode;
  final VoidCallback onDelete;
  final VoidCallback onAssignJob;
  final VoidCallback onManageLeaves;

  void _openMapView(BuildContext context) {
    if (personnel.lastKnownLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Personelin konum bilgisi bulunmuyor")),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => JobMapView(
          initialPersonnelLocation: LatLng(
            personnel.lastKnownLocation!.lat,
            personnel.lastKnownLocation!.lng,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasLocation = personnel.lastKnownLocation != null;
    return Scaffold(
      appBar: AdminAppBar(title: personnel.name),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              // Harita bölümü
              if (hasLocation)
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => _openMapView(context),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: 200,
                          child: Stack(
                            children: [
                              FlutterMap(
                                options: MapOptions(
                                  initialCenter: LatLng(
                                    personnel.lastKnownLocation!.lat,
                                    personnel.lastKnownLocation!.lng,
                                  ),
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
                                        point: LatLng(
                                          personnel.lastKnownLocation!.lat,
                                          personnel.lastKnownLocation!.lng,
                                        ),
                                        width: 40,
                                        height: 40,
                                        child: const Icon(
                                          Icons.person_pin_circle,
                                          color: Color(0xFF2563EB),
                                          size: 40,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.open_in_full,
                                    size: 20,
                                    color: Color(0xFF2563EB),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              const Icon(Icons.location_on, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "Son Bilinen Konum",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "${personnel.lastKnownLocation!.lat.toStringAsFixed(6)}, "
                                      "${personnel.lastKnownLocation!.lng.toStringAsFixed(6)}",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    if (personnel
                                            .lastKnownLocation!
                                            .timestamp !=
                                        null)
                                      Text(
                                        "Son güncelleme: ${DateFormat("dd MMM yyyy HH:mm").format(personnel.lastKnownLocation!.timestamp!.toLocal())}",
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.location_off, color: Colors.grey.shade400),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "Konum bilgisi bulunmuyor",
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              // Bilgiler kartı
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Row(label: "Telefon", value: personnel.phone),
                      _Row(label: "E-posta", value: personnel.email ?? "-"),
                      _Row(label: "Durum", value: personnel.status),
                      _Row(
                        label: "İşe giriş",
                        value: DateFormat(
                          "dd MMM yyyy",
                        ).format(personnel.hireDate.toLocal()),
                      ),
                      _Row(
                        label: "Konum paylaşımı",
                        value: personnel.canShareLocation ? "Açık" : "Kapalı",
                      ),
                      _Row(label: "Giriş kodu", value: personnel.loginCode),
                      if (personnel.isOnLeave) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF2563EB,
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(
                                0xFF2563EB,
                              ).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.beach_access,
                                color: const Color(0xFF2563EB),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                "Şu anda izinli",
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2563EB),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Sağ alt köşede sabit butonlar
          Positioned(
            right: 16,
            bottom: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FloatingActionButton(
                  heroTag: "delete",
                  backgroundColor: Colors.red,
                  onPressed: onDelete,
                  tooltip: "Personeli Sil",
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                const SizedBox(height: 12),
                FloatingActionButton(
                  heroTag: "assign_job",
                  backgroundColor: const Color(0xFF10B981),
                  onPressed: onAssignJob,
                  tooltip: "İş Ata",
                  child: const Icon(Icons.work, color: Colors.white),
                ),
                const SizedBox(height: 12),
                FloatingActionButton(
                  heroTag: "reset_code",
                  backgroundColor: Colors.orange,
                  onPressed: onResetCode,
                  tooltip: "Giriş Kodunu Sıfırla",
                  child: const Icon(Icons.key, color: Colors.white),
                ),
                const SizedBox(height: 12),
                FloatingActionButton(
                  heroTag: "edit",
                  backgroundColor: const Color(0xFF2563EB),
                  onPressed: onEdit,
                  tooltip: "Düzenle",
                  child: const Icon(Icons.edit, color: Colors.white),
                ),
                const SizedBox(height: 12),
                FloatingActionButton(
                  heroTag: "leaves",
                  backgroundColor: personnel.isOnLeave
                      ? const Color(0xFF2563EB)
                      : Colors.grey.shade600,
                  onPressed: onManageLeaves,
                  tooltip: "İzin Yönetimi",
                  child: Icon(Icons.beach_access, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

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
          Expanded(flex: 3, child: Text(value)),
        ],
      ),
    );
  }
}

class _EditPersonnelSheet extends ConsumerStatefulWidget {
  const _EditPersonnelSheet({
    required this.personnel,
    required this.personnelId,
  });

  final Personnel personnel;
  final String personnelId;

  @override
  ConsumerState<_EditPersonnelSheet> createState() =>
      _EditPersonnelSheetState();
}

class _EditPersonnelSheetState extends ConsumerState<_EditPersonnelSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late DateTime _hireDate;
  late String _status;
  late bool _canShareLocation;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.personnel.name);
    _phoneController = TextEditingController(text: widget.personnel.phone);
    _emailController = TextEditingController(
      text: widget.personnel.email ?? "",
    );
    _hireDate = widget.personnel.hireDate;
    _status = widget.personnel.status;
    _canShareLocation = widget.personnel.canShareLocation;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _hireDate,
      firstDate: DateTime.now().subtract(const Duration(days: 3650)),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _hireDate = picked;
      });
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
          .updatePersonnel(
            id: widget.personnelId,
            name: _nameController.text.trim(),
            phone: _phoneController.text.trim(),
            email: _emailController.text.trim().isEmpty
                ? null
                : _emailController.text.trim(),
            hireDate: _hireDate,
            status: _status,
            canShareLocation: _canShareLocation,
          );
      ref.invalidate(personnelDetailProvider(widget.personnelId));
      ref.invalidate(personnelListProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Personel güncellendi")));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Güncelleme başarısız: $error")));
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
    final dateText = DateFormat("dd MMM yyyy").format(_hireDate);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Personel Düzenle",
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: "İsim"),
                validator: (value) => value == null || value.trim().length < 2
                    ? "İsim girin"
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: "Telefon"),
                keyboardType: TextInputType.phone,
                validator: (value) => value == null || value.trim().length < 6
                    ? "Telefon girin"
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: "E-posta (opsiyonel)",
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: Text("İşe giriş tarihi: $dateText")),
                  TextButton(
                    onPressed: _pickDate,
                    child: const Text("Tarih seç"),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownMenu<String>(
                initialSelection: _status,
                label: const Text("Durum"),
                onSelected: (value) {
                  if (value != null) {
                    setState(() {
                      _status = value;
                    });
                  }
                },
                dropdownMenuEntries: const [
                  DropdownMenuEntry(value: "ACTIVE", label: "Aktif"),
                  DropdownMenuEntry(value: "SUSPENDED", label: "Askıda"),
                  DropdownMenuEntry(value: "INACTIVE", label: "Pasif"),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text("Konum paylaşımı"),
                value: _canShareLocation,
                onChanged: (value) {
                  setState(() {
                    _canShareLocation = value;
                  });
                },
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
}

class _LeavesManagementSheet extends ConsumerStatefulWidget {
  const _LeavesManagementSheet({
    required this.personnelId,
    required this.personnelName,
  });

  final String personnelId;
  final String personnelName;

  @override
  ConsumerState<_LeavesManagementSheet> createState() =>
      _LeavesManagementSheetState();
}

class _LeavesManagementSheetState
    extends ConsumerState<_LeavesManagementSheet> {
  List<PersonnelLeave> _leaves = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadLeaves();
  }

  Future<void> _loadLeaves() async {
    setState(() {
      _loading = true;
    });
    try {
      final leaves = await ref
          .read(adminRepositoryProvider)
          .fetchPersonnelLeaves(widget.personnelId);
      if (mounted) {
        setState(() {
          _leaves = leaves;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("İzinler yüklenemedi: $error")));
      }
    }
  }

  Future<void> _addLeave() async {
    DateTime? startDate;
    DateTime? endDate;
    final reasonController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text("İzin Ekle"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: Text(
                      startDate == null
                          ? "Başlangıç Tarihi Seç"
                          : DateFormat("dd MMM yyyy").format(startDate!),
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: startDate ?? DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setState(() {
                          startDate = picked;
                          if (endDate != null && endDate!.isBefore(picked)) {
                            endDate = null;
                          }
                        });
                      }
                    },
                  ),
                  ListTile(
                    title: Text(
                      endDate == null
                          ? "Bitiş Tarihi Seç"
                          : DateFormat("dd MMM yyyy").format(endDate!),
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: endDate ?? startDate ?? DateTime.now(),
                        firstDate: startDate ?? DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setState(() {
                          endDate = picked;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: reasonController,
                    decoration: const InputDecoration(
                      labelText: "İzin Nedeni (Opsiyonel)",
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text("İptal"),
              ),
              FilledButton(
                onPressed: startDate != null && endDate != null
                    ? () => Navigator.of(context).pop(true)
                    : null,
                child: const Text("Ekle"),
              ),
            ],
          );
        },
      ),
    );

    if (result != true || startDate == null || endDate == null) return;

    try {
      await ref
          .read(adminRepositoryProvider)
          .createPersonnelLeave(
            personnelId: widget.personnelId,
            startDate: startDate!,
            endDate: endDate!,
            reason: reasonController.text.trim().isEmpty
                ? null
                : reasonController.text.trim(),
          );
      ref.invalidate(personnelDetailProvider(widget.personnelId));
      ref.invalidate(personnelListProvider);
      await _loadLeaves();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("İzin eklendi")));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("İzin eklenemedi: $error")));
    }
  }

  Future<void> _deleteLeave(String leaveId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("İzni Sil"),
        content: const Text("Bu izni silmek istediğinize emin misiniz?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("İptal"),
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
      await ref
          .read(adminRepositoryProvider)
          .deletePersonnelLeave(
            personnelId: widget.personnelId,
            leaveId: leaveId,
          );
      ref.invalidate(personnelDetailProvider(widget.personnelId));
      ref.invalidate(personnelListProvider);
      await _loadLeaves();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("İzin silindi")));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("İzin silinemedi: $error")));
    }
  }

  Widget _buildLeavesList() {
    final now = DateTime.now();
    final activeLeaves = _leaves.where((leave) {
      return now.isAfter(leave.startDate) &&
          now.isBefore(leave.endDate.add(const Duration(days: 1)));
    }).toList();
    final pastLeaves = _leaves.where((leave) {
      return now.isAfter(leave.endDate.add(const Duration(days: 1)));
    }).toList();

    return ListView(
      shrinkWrap: true,
      children: [
        // Aktif İzinler Bölümü
        if (activeLeaves.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8, top: 8),
            child: Text(
              "Aktif İzinler",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF2563EB),
              ),
            ),
          ),
          ...activeLeaves.map((leave) => _buildLeaveCard(leave, true)),
          const SizedBox(height: 16),
        ],
        // Geçmiş İzin Kayıtları Bölümü
        if (pastLeaves.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8, top: 8),
            child: Text(
              "Geçmiş İzin Kayıtları",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          ...pastLeaves.map((leave) => _buildLeaveCard(leave, false)),
        ],
      ],
    );
  }

  Widget _buildLeaveCard(PersonnelLeave leave, bool isActive) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isActive ? const Color(0xFF2563EB).withValues(alpha: 0.05) : null,
      child: ListTile(
        leading: Icon(
          Icons.beach_access,
          color: isActive ? const Color(0xFF2563EB) : Colors.grey.shade600,
        ),
        title: Text(
          "${DateFormat("dd MMM yyyy").format(leave.startDate)} - ${DateFormat("dd MMM yyyy").format(leave.endDate)}",
          style: TextStyle(
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            color: isActive ? const Color(0xFF2563EB) : Colors.black87,
          ),
        ),
        subtitle: leave.reason != null ? Text(leave.reason!) : null,
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () => _deleteLeave(leave.id),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  "${widget.personnelName} - İzinler",
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_leaves.isEmpty)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.beach_access,
                    size: 48,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Henüz izin kaydı yok",
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            )
          else
            Expanded(child: _buildLeavesList()),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _addLeave,
              icon: const Icon(Icons.add),
              label: const Text("İzin Ekle"),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
        ],
      ),
    );
  }
}
