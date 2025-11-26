import "dart:typed_data";

import "package:dio/dio.dart";
import "package:flutter/material.dart";
import "package:flutter_map/flutter_map.dart";
import "package:go_router/go_router.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:image_picker/image_picker.dart";
import "package:intl/intl.dart";
import "package:latlong2/latlong.dart";
import "package:mobile/widgets/admin_app_bar.dart";
import "package:mobile/widgets/empty_state.dart";
import "full_screen_map_page.dart";

import "../../../../core/constants/app_config.dart";
import "../../../../core/network/api_client.dart" show apiClientProvider;
import "../../application/job_list_notifier.dart";
import "../../application/personnel_detail_provider.dart";
import "../../application/personnel_list_notifier.dart";
import "../../data/admin_repository.dart";
import "../../data/models/job.dart";
import "../../data/models/personnel.dart";
import "../widgets/job_card.dart";

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
        appBar: AdminAppBar(
          title: Text(widget.initialPersonnel?.name ?? "Personel"),
        ),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: const AdminAppBar(title: Text("Personel Detayı")),
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
                  subtitle: Text("Durum: ${_getJobStatusText(job.status)}"),
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

String _getPersonnelStatusText(String status) {
  switch (status) {
    case "ACTIVE":
      return "Aktif";
    case "SUSPENDED":
      return "Askıda";
    case "INACTIVE":
      return "Pasif";
    default:
      return status;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AdminAppBar(
        title: Row(
          children: [
            _PersonnelAvatar(
              photoUrl: personnel.photoUrl,
              name: personnel.name,
              size: 32,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(personnel.name)),
          ],
        ),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              // Harita bölümü - en üstte
              _PersonnelMapSection(personnel: personnel),
              const SizedBox(height: 24),
              // Bilgiler kartı
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Row(label: "Telefon", value: personnel.phone),
                      _Row(label: "E-posta", value: personnel.email ?? "-"),
                      _Row(
                        label: "Durum",
                        value: _getPersonnelStatusText(personnel.status),
                      ),
                      _Row(
                        label: "İşe giriş",
                        value: DateFormat(
                          "dd MMM yyyy",
                        ).format(personnel.hireDate.toLocal()),
                      ),
                      if (personnel.personnelId != null)
                        _Row(
                          label: "Personel ID",
                          value: personnel.personnelId!,
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
              const SizedBox(height: 24),
              // Geçmiş İşler bölümü
              _PastJobsSection(personnelId: personnel.id),
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
  final _imagePicker = ImagePicker();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late DateTime _hireDate;
  late String _status;
  bool _submitting = false;
  XFile? _selectedImage;
  Uint8List? _selectedImageBytes;
  bool _photoRemoved = false;

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

  Future<void> _pickImage() async {
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Fotoğraf Kaynağı"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text("Kamera"),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text("Galeri"),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source != null) {
      final image = await _imagePicker.pickImage(source: source);
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _selectedImage = image;
          _selectedImageBytes = bytes;
        });
      }
    }
  }

  Future<String?> _uploadImage(XFile image) async {
    try {
      final bytes = await image.readAsBytes();
      final contentType =
          image.path.endsWith(".jpg") || image.path.endsWith(".jpeg")
          ? "image/jpeg"
          : "image/png";

      // Get presigned URL from backend
      final client = ref.read(apiClientProvider);
      final presignedResponse = await client.post(
        "/media/sign",
        data: {"contentType": contentType, "prefix": "personnel-photos"},
      );
      final uploadUrl = presignedResponse.data["data"]["uploadUrl"] as String;
      final photoKey = presignedResponse.data["data"]["key"] as String;

      // Upload to S3 using presigned URL
      // Create a new Dio instance without interceptors to avoid conflicts
      final uploadClient = Dio();
      try {
        await uploadClient.put(
          uploadUrl,
          data: bytes,
          options: Options(
            headers: {"Content-Type": contentType},
            contentType: contentType,
            validateStatus: (status) => status != null && status < 600,
          ),
        );
      } catch (uploadError) {
        // Close the upload client to free resources
        uploadClient.close();
        rethrow;
      }
      uploadClient.close();

      // Return the photo key
      return photoKey;
    } catch (e) {
      if (mounted) {
        final errorMessage =
            e.toString().contains("connection error") ||
                e.toString().contains("XMLHttpRequest")
            ? "Fotoğraf yüklenemedi: Ağ bağlantı hatası. Lütfen internet bağlantınızı kontrol edin ve tekrar deneyin."
            : "Fotoğraf yüklenemedi: ${e.toString()}";
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            duration: const Duration(seconds: 5),
          ),
        );
      }
      return null;
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
    });
    try {
      String? photoUrl;
      bool shouldUpdatePhoto = false;

      // Upload image if selected
      if (_selectedImage != null) {
        photoUrl = await _uploadImage(_selectedImage!);
        if (photoUrl == null) {
          // Upload failed, don't update photo
          shouldUpdatePhoto = false;
        } else {
          shouldUpdatePhoto = true;
        }
      } else if (_photoRemoved) {
        // Photo was explicitly removed - send empty string to backend
        photoUrl = "";
        shouldUpdatePhoto = true;
      }
      // If neither condition is met, don't update photo (keep existing)

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
            photoUrl: shouldUpdatePhoto ? photoUrl : null,
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
              // Fotoğraf seçimi
              Center(
                child: Column(
                  children: [
                    Stack(
                      children: [
                        if (_selectedImageBytes != null)
                          ClipOval(
                            child: Image.memory(
                              _selectedImageBytes!,
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                            ),
                          )
                        else if (widget.personnel.photoUrl != null &&
                            widget.personnel.photoUrl!.isNotEmpty)
                          _PersonnelAvatar(
                            photoUrl: widget.personnel.photoUrl,
                            name: widget.personnel.name,
                            size: 100,
                          )
                        else
                          _PersonnelAvatar(
                            photoUrl: null,
                            name: widget.personnel.name,
                            size: 100,
                          ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: const Color(0xFF2563EB),
                            child: IconButton(
                              icon: const Icon(
                                Icons.camera_alt,
                                size: 18,
                                color: Colors.white,
                              ),
                              onPressed: _pickImage,
                              padding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_selectedImageBytes != null)
                      OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _selectedImage = null;
                            _selectedImageBytes = null;
                          });
                        },
                        icon: const Icon(Icons.delete_outline),
                        label: const Text("Kaldır"),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                    if (widget.personnel.photoUrl != null &&
                        widget.personnel.photoUrl!.isNotEmpty &&
                        _selectedImageBytes == null)
                      OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _photoRemoved = true;
                          });
                        },
                        icon: const Icon(Icons.delete_outline),
                        label: const Text("Fotoğrafı Kaldır"),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.red.shade300),
                        ),
                      ),
                  ],
                ),
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
    // Sadece bugünün tarihini kullan (saat bilgisini sıfırla)
    final today = DateTime(now.year, now.month, now.day);

    final activeLeaves = _leaves.where((leave) {
      // İzin başlangıç ve bitiş tarihlerini sadece tarih olarak al
      final start = DateTime(
        leave.startDate.year,
        leave.startDate.month,
        leave.startDate.day,
      );
      final end = DateTime(
        leave.endDate.year,
        leave.endDate.month,
        leave.endDate.day,
      );
      // Bugün izin aralığında mı kontrol et (başlangıç dahil, bitiş dahil)
      // today >= start && today <= end
      return today.compareTo(start) >= 0 && today.compareTo(end) <= 0;
    }).toList();

    final pastLeaves = _leaves.where((leave) {
      // İzin bitiş tarihini sadece tarih olarak al
      final end = DateTime(
        leave.endDate.year,
        leave.endDate.month,
        leave.endDate.day,
      );
      // Bugün izin bitiş tarihinden sonra mı kontrol et
      // today > end
      return today.compareTo(end) > 0;
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

class _PastJobsSection extends ConsumerWidget {
  const _PastJobsSection({required this.personnelId});

  final String personnelId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<Job>>(
      future: ref
          .read(adminRepositoryProvider)
          .fetchJobs(personnelId: personnelId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (snapshot.hasError) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 8),
                  Text(
                    "İşler yüklenemedi",
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    snapshot.error.toString(),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          );
        }

        final allJobs = snapshot.data ?? [];
        final pastJobs = allJobs
            .where(
              (job) => job.status == "DELIVERED" || job.status == "ARCHIVED",
            )
            .toList();

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.history, color: Color(0xFF2563EB)),
                    const SizedBox(width: 8),
                    Text(
                      "Geçmiş İşler",
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (pastJobs.isEmpty)
                  const EmptyState(
                    icon: Icons.history,
                    title: "Geçmiş iş bulunamadı",
                    subtitle:
                        "Bu personelin teslim ettiği işler burada listelenecek.",
                  )
                else
                  ...pastJobs.map((job) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: RepaintBoundary(
                        child: JobCard(
                          job: job,
                          onTap: () =>
                              context.push("/admin/jobs/${job.id}", extra: job),
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PersonnelMapSection extends ConsumerStatefulWidget {
  const _PersonnelMapSection({required this.personnel});

  final Personnel personnel;

  @override
  ConsumerState<_PersonnelMapSection> createState() =>
      _PersonnelMapSectionState();
}

class _PersonnelMapSectionState extends ConsumerState<_PersonnelMapSection> {
  LatLng? _personnelLocation;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  Future<void> _loadLocation() async {
    // Önce personelin lastKnownLocation bilgisini kontrol et
    debugPrint(
      "🗺️ Personnel location check: ${widget.personnel.lastKnownLocation != null}",
    );
    if (widget.personnel.lastKnownLocation != null) {
      debugPrint(
        "🗺️ Personnel has location: ${widget.personnel.lastKnownLocation!.lat}, ${widget.personnel.lastKnownLocation!.lng}",
      );
      setState(() {
        _personnelLocation = LatLng(
          widget.personnel.lastKnownLocation!.lat,
          widget.personnel.lastKnownLocation!.lng,
        );
      });
      return;
    }

    debugPrint("🗺️ Personnel location is null, trying to find from jobs...");

    // lastKnownLocation yoksa, personelin son işlerinden birinin konumunu kullan
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final jobs = await ref
          .read(adminRepositoryProvider)
          .fetchJobs(personnelId: widget.personnel.id);

      // Konum bilgisi olan en son işi bul
      final jobWithLocation = jobs.where((job) => job.location != null).toList()
        ..sort((a, b) {
          // En son tarihli işi al
          final aDate = a.scheduledAt ?? a.createdAt;
          final bDate = b.scheduledAt ?? b.createdAt;
          if (aDate == null && bDate == null) return 0;
          if (aDate == null) return 1;
          if (bDate == null) return -1;
          return bDate.compareTo(aDate);
        });

      if (!mounted) return;

      debugPrint("🗺️ Found ${jobWithLocation.length} jobs with location");
      if (jobWithLocation.isNotEmpty &&
          jobWithLocation.first.location != null) {
        final location = jobWithLocation.first.location!;
        debugPrint(
          "🗺️ Using job location: ${location.latitude}, ${location.longitude}",
        );
        setState(() {
          _personnelLocation = LatLng(location.latitude, location.longitude);
          _isLoading = false;
        });
      } else {
        debugPrint("🗺️ No jobs with location found");
        setState(() {
          _error = "Konum bilgisi bulunamadı";
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = "Konum yüklenemedi: $e";
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
                  "Son Bilinen Konum",
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
            onTap: _personnelLocation != null
                ? () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => FullScreenMapPage(
                          location: _personnelLocation!,
                          title: widget.personnel.name,
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
                  ? Center(
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
                  : _personnelLocation != null
                  ? Builder(
                      builder: (context) {
                        debugPrint(
                          "🗺️ Rendering personnel map at: ${_personnelLocation!.latitude}, ${_personnelLocation!.longitude}",
                        );
                        return ClipRect(
                          child: FlutterMap(
                            key: ValueKey(
                              "${_personnelLocation!.latitude}_${_personnelLocation!.longitude}",
                            ),
                            options: MapOptions(
                              initialCenter: _personnelLocation!,
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
                                    point: _personnelLocation!,
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
                        );
                      },
                    )
                  : Builder(
                      builder: (context) {
                        debugPrint(
                          "🗺️ Personnel location is null, showing error message",
                        );
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.location_off,
                                  color: Colors.grey.shade400,
                                  size: 48,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "Konum bilgisi bulunmuyor",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.place, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _personnelLocation != null &&
                            widget.personnel.lastKnownLocation != null
                        ? "${widget.personnel.lastKnownLocation!.lat.toStringAsFixed(6)}, "
                              "${widget.personnel.lastKnownLocation!.lng.toStringAsFixed(6)}"
                        : "Konum bilgisi yok",
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ),
                if (_personnelLocation != null) ...[
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => FullScreenMapPage(
                            location: _personnelLocation!,
                            title: widget.personnel.name,
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
          if (_personnelLocation != null &&
              widget.personnel.lastKnownLocation != null &&
              widget.personnel.lastKnownLocation!.timestamp != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 14,
                    color: Colors.grey.shade500,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    "Son güncelleme: ${DateFormat("dd MMM yyyy HH:mm").format(widget.personnel.lastKnownLocation!.timestamp!.toLocal())}",
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PersonnelAvatar extends StatelessWidget {
  const _PersonnelAvatar({
    required this.photoUrl,
    required this.name,
    this.size = 48,
  });

  final String? photoUrl;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    // Eğer photoUrl varsa ve boş değilse, fotoğrafı göster
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      // Default fotoğraflar için asset kullan
      if (photoUrl!.startsWith("default/")) {
        final gender = photoUrl!
            .replaceAll("default/", "")
            .replaceAll(".jpg", "");
        return ClipOval(
          child: Image.asset(
            "assets/images/$gender.jpg",
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return _buildInitialsAvatar();
            },
          ),
        );
      }
      // S3 URL için network image kullan
      final imageUrl = AppConfig.getMediaUrl(photoUrl!);
      return ClipOval(
        child: Image.network(
          imageUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            // Hata durumunda baş harf göster
            return _buildInitialsAvatar();
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return _buildInitialsAvatar();
          },
        ),
      );
    }
    // Fotoğraf yoksa baş harf göster
    return _buildInitialsAvatar();
  }

  Widget _buildInitialsAvatar() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF2563EB).withValues(alpha: 0.1),
            const Color(0xFF10B981).withValues(alpha: 0.1),
          ],
        ),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : "P",
          style: TextStyle(
            fontSize: size * 0.4,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF2563EB),
          ),
        ),
      ),
    );
  }
}
