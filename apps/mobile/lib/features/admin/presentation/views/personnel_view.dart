import "package:flutter/material.dart";
import "package:go_router/go_router.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:intl/intl.dart";
import "package:mobile/widgets/admin_app_bar.dart";
import "package:mobile/widgets/empty_state.dart";

import "../../application/personnel_list_notifier.dart";
import "../../data/admin_repository.dart";
import "../../data/models/personnel.dart";

class PersonnelView extends ConsumerWidget {
  const PersonnelView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(personnelListProvider);
    final notifier = ref.read(personnelListProvider.notifier);
    final content = state.when(
      data: (items) {
        if (items.isEmpty) {
          return RefreshIndicator(
            onRefresh: notifier.refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
              children: const [
                SizedBox(height: 120),
                EmptyState(
                  icon: Icons.group_outlined,
                  title: "Hiç personel bulunmuyor",
                  subtitle:
                      "Yeni personel ekleyerek ekibinizi oluşturabilirsiniz.",
                ),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: notifier.refresh,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            cacheExtent: 500,
            addAutomaticKeepAlives: false,
            addRepaintBoundaries: true,
            itemBuilder: (context, index) {
              final item = items[index];
              return RepaintBoundary(
                child: GestureDetector(
                  onTap: () => context.pushNamed(
                    "admin-personnel-detail",
                    pathParameters: {"id": item.id},
                    extra: item,
                  ),
                  child: _PersonnelTile(item: item),
                ),
              );
            },
          ),
        );
      },
      error: (error, _) => _ErrorState(
        message: error.toString(),
        onRetry: () => ref.read(personnelListProvider.notifier).refresh(),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
    final padding = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      appBar: const AdminAppBar(title: "Personeller"),
      body: Stack(
        children: [
          Positioned.fill(child: content),
          Positioned(
            right: 16,
            bottom: 16 + padding,
            child: FloatingActionButton.extended(
              onPressed: () => _openAddPersonnelSheet(context, ref),
              icon: const Icon(Icons.person_add),
              label: const Text("Personel Ekle"),
            ),
          ),
        ],
      ),
    );
  }

  void _openAddPersonnelSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: const _PersonnelFormSheet(),
      ),
    );
  }
}

class _PersonnelTile extends StatelessWidget {
  const _PersonnelTile({required this.item});

  final Personnel item;

  Color _statusColor() {
    // İzinli personeller mavi renkte
    if (item.isOnLeave) {
      return const Color(0xFF2563EB);
    }
    switch (item.status) {
      case "ACTIVE":
        return const Color(0xFF10B981);
      case "SUSPENDED":
        return const Color(0xFFF59E0B);
      case "INACTIVE":
        return Colors.grey.shade400;
      default:
        return Colors.grey.shade400;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
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
                      item.name.isNotEmpty ? item.name[0].toUpperCase() : "P",
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              item.name,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: item.isOnLeave
                                    ? const Color(0xFF2563EB)
                                    : const Color(0xFF1F2937),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (item.isOnLeave) ...[
                            const SizedBox(width: 6),
                            Icon(
                              Icons.beach_access,
                              size: 16,
                              color: const Color(0xFF2563EB),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.phone,
                            size: 14,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              item.phone,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _statusColor().withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _statusColor().withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _statusColor(),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            item.isOnLeave ? "İZİNLİ" : item.status,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _statusColor(),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (item.email != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.email, size: 16, color: Colors.grey.shade500),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.email!,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: item.canShareLocation
                          ? const Color(0xFF10B981).withValues(alpha: 0.1)
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      item.canShareLocation
                          ? Icons.location_on
                          : Icons.location_off,
                      size: 16,
                      color: item.canShareLocation
                          ? const Color(0xFF10B981)
                          : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.canShareLocation
                          ? "Konum paylaşımı açık"
                          : "Konum kapalı",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item.loginCode,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2563EB),
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonnelFormSheet extends ConsumerStatefulWidget {
  const _PersonnelFormSheet();

  @override
  ConsumerState<_PersonnelFormSheet> createState() =>
      _PersonnelFormSheetState();
}

class _PersonnelFormSheetState extends ConsumerState<_PersonnelFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  DateTime _hireDate = DateTime.now();
  bool _canShareLocation = true;
  bool _submitting = false;

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
          .createPersonnel(
            name: _nameController.text.trim(),
            phone: _phoneController.text.trim(),
            email: _emailController.text.trim().isEmpty
                ? null
                : _emailController.text.trim(),
            hireDate: _hireDate,
            canShareLocation: _canShareLocation,
          );
      await ref.read(personnelListProvider.notifier).refresh();
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Yeni personel eklendi")));
    } catch (error) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Personel eklenemedi: $error")));
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
                "Personel Ekle",
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key("personnel-name-field"),
                controller: _nameController,
                decoration: const InputDecoration(labelText: "İsim"),
                validator: (value) => value == null || value.trim().length < 2
                    ? "İsim girin"
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key("personnel-phone-field"),
                controller: _phoneController,
                decoration: const InputDecoration(labelText: "Telefon"),
                keyboardType: TextInputType.phone,
                validator: (value) => value == null || value.trim().length < 6
                    ? "Telefon girin"
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key("personnel-email-field"),
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
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _canShareLocation,
                title: const Text("Konum paylaşımı"),
                onChanged: (value) {
                  setState(() {
                    _canShareLocation = value;
                  });
                },
              ),
              const SizedBox(height: 12),
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

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Personel listesi alınamadı",
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text("Tekrar dene"),
          ),
        ],
      ),
    );
  }
}
