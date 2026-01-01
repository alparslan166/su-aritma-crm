import "package:flutter/material.dart";
import "package:geocoding/geocoding.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";

import "../../../../core/constants/app_config.dart";
import "../../../../core/error/error_handler.dart";
import "../../application/customer_list_notifier.dart";
import "../../application/personnel_list_notifier.dart";
import "../../data/admin_repository.dart";
import "../../data/models/customer.dart";
import "../../data/models/personnel.dart";
import "../../../dashboard/presentation/home_page_provider.dart";

class AssignJobSheet extends ConsumerStatefulWidget {
  const AssignJobSheet({super.key});

  @override
  ConsumerState<AssignJobSheet> createState() => _AssignJobSheetState();
}

class _AssignJobSheetState extends ConsumerState<AssignJobSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  List<Personnel> _selectedPersonnelList = [];
  Customer? _selectedCustomer;
  bool _submitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _selectPersonnel() async {
    try {
      // Fetch personnel directly from repository
      final repository = ref.read(adminRepositoryProvider);
      final personnelList = await repository.fetchPersonnel();

      if (!mounted) return;

      if (personnelList.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Personel bulunamadı")));
        return;
      }

      final selected = await showDialog<List<Personnel>>(
        context: context,
        builder: (context) => _PersonnelSelectionDialog(
          personnelList: personnelList,
          initialSelection: _selectedPersonnelList,
        ),
      );
      if (selected != null) {
        setState(() {
          _selectedPersonnelList = selected;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Personel listesi yüklenemedi: $e")),
        );
      }
    }
  }

  Future<void> _selectCustomer() async {
    // Ensure customer list is loaded
    await ref.read(customerListProvider.notifier).refresh();

    // Get data from provider
    final customerState = ref.read(customerListProvider);
    final customerList = customerState.value ?? [];

    if (!mounted) return;

    if (customerList.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Müşteri bulunamadı")));
      return;
    }

    final selected = await showDialog<Customer>(
      context: context,
      builder: (context) =>
          _CustomerSelectionDialog(customerList: customerList),
    );
    if (selected != null) {
      setState(() {
        _selectedCustomer = selected;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPersonnelList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lütfen en az bir personel seçin")),
      );
      return;
    }
    // Müşteri seçimi artık opsiyonel

    setState(() {
      _submitting = true;
    });

    try {
      if (_selectedCustomer != null) {
        // Müşteri seçilmişse, mevcut müşteriye iş ata
        // Geocode address to get location
        Location? location;
        try {
          final locations = await locationFromAddress(
            _selectedCustomer!.address,
          );
          if (locations.isNotEmpty) {
            location = locations.first;
          }
        } catch (e) {
          // Geocoding failed, continue without location
        }

        await ref
            .read(adminRepositoryProvider)
            .createJobForCustomer(
              customerId: _selectedCustomer!.id,
              title: _titleController.text.trim(),
              personnelIds: _selectedPersonnelList.map((p) => p.id).toList(),
              latitude: location?.latitude,
              longitude: location?.longitude,
              locationDescription: _selectedCustomer!.address,
              materialIds: null,
            );
      } else {
        // Müşteri seçilmemişse, müşteri olmadan iş oluştur
        await ref
            .read(adminRepositoryProvider)
            .createJob(
              title: _titleController.text.trim(),
              // Customer bilgileri gönderilmiyor - backend'de opsiyonel
              personnelIds: _selectedPersonnelList.map((p) => p.id).toList(),
              materialIds: null,
            );
      }

      // Refresh lists
      ref.invalidate(personnelListProvider);
      ref.invalidate(customerListProvider);

      // Ana sayfa grafik ve istatistiklerini statik olarak yenile
      ref.invalidate(dashboardStatsProvider);
      ref.invalidate(customerCategoryDataProvider);
      ref.invalidate(overduePaymentsCustomersProvider);
      ref.invalidate(upcomingMaintenanceProvider);

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("İş başarıyla atandı ve personel bilgilendirildi"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      if (!mounted) return;
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
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min, // Dialog için min kullan
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   Text(
                    "İş Ata",
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              //--------------------------------- Müşteri Seç
              OutlinedButton.icon(
                onPressed: _selectCustomer,
                icon: const Icon(Icons.business),
                label: Text(
                  _selectedCustomer != null
                      ? _selectedCustomer!.name
                      : "Müşteri Seç (Opsiyonel)",
                  style: const TextStyle(color: Colors.black),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  alignment: Alignment.centerLeft,
                ),
              ),
              if (_selectedCustomer != null) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Telefon: ${_selectedCustomer!.phone}",
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        "Adres: ${_selectedCustomer!.address}",
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              //--------------------------------- Personel Seç
              OutlinedButton.icon(
                onPressed: _selectPersonnel,
                icon: const Icon(Icons.person),
                label: Text(
                  _selectedPersonnelList.isEmpty
                      ? "Personel Seç"
                      : "${_selectedPersonnelList.length} personel seçildi",
                  style: const TextStyle(color: Colors.black),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  alignment: Alignment.centerLeft,
                ),
              ),
              if (_selectedPersonnelList.isNotEmpty) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _selectedPersonnelList.map((personnel) {
                      return Chip(
                        label: Text(personnel.name),
                        onDeleted: () {
                          setState(() {
                            _selectedPersonnelList.remove(personnel);
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              // Yapılacak İşlem
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: "Yapılacak işlem bilgisi",
                  // hintText: "Yapılacak işlem hakkında not",
                  labelStyle: TextStyle(color: Colors.black),
                  floatingLabelStyle: TextStyle(color: Colors.black),
                  border: OutlineInputBorder(), // Dialog içinde border daha iyi durur
                ),
                maxLines: 3,
                validator: (value) => value == null || value.trim().isEmpty
                    ? "Yapılacak işlemi girin"
                    : null,
              ),
              const SizedBox(height: 32),
              // Kaydet Butonu
              FilledButton(
                onPressed: _submitting ? null : _submit,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text("Kaydet"),
              ),
              SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
            ],
          ),
        ),
      ),
    );
  }
}

class _PersonnelSelectionDialog extends StatefulWidget {
  const _PersonnelSelectionDialog({
    required this.personnelList,
    required this.initialSelection,
  });

  final List<Personnel> personnelList;
  final List<Personnel> initialSelection;

  @override
  State<_PersonnelSelectionDialog> createState() =>
      _PersonnelSelectionDialogState();
}

class _PersonnelSelectionDialogState extends State<_PersonnelSelectionDialog> {
  final _searchController = TextEditingController();
  List<Personnel> _filteredList = [];
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _filteredList = widget.personnelList;
    _selectedIds.addAll(widget.initialSelection.map((p) => p.id));
    _searchController.addListener(_filterList);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterList() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredList = widget.personnelList.where((personnel) {
        return personnel.name.toLowerCase().contains(query) ||
            personnel.phone.contains(query) ||
            (personnel.personnelId?.toLowerCase().contains(query) ?? false);
      }).toList();
    });
  }

  void _toggleSelection(Personnel personnel) {
    setState(() {
      if (_selectedIds.contains(personnel.id)) {
        _selectedIds.remove(personnel.id);
      } else {
        _selectedIds.add(personnel.id);
      }
    });
  }

  void _confirmSelection() {
    final selected = widget.personnelList
        .where((p) => _selectedIds.contains(p.id))
        .toList();
    Navigator.of(context).pop(selected);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: "Personel Ara",
                      labelStyle: const TextStyle(color: Colors.black),
                      hintStyle: const TextStyle(color: Colors.black54),
                      prefixIcon: Icon(Icons.search, color: Colors.black54),
                      border: OutlineInputBorder(),
                    ),
                    autofocus: true,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          if (_filteredList.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text("Personel bulunamadı"),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _filteredList.length,
                itemBuilder: (context, index) {
                  final personnel = _filteredList[index];
                  final isSelected = _selectedIds.contains(personnel.id);
                  return CheckboxListTile(
                    value: isSelected,
                    onChanged: (_) => _toggleSelection(personnel),
                    title: Text(personnel.name),
                    subtitle: Text(personnel.phone),
                    secondary: _PersonnelAvatar(
                      photoUrl: personnel.photoUrl,
                      name: personnel.name,
                      size: 48,
                    ),
                  );
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "${_selectedIds.length} personel seçildi",
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                FilledButton(
                  onPressed: _confirmSelection,
                  child: const Text("Seç"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerSelectionDialog extends StatefulWidget {
  const _CustomerSelectionDialog({required this.customerList});

  final List<Customer> customerList;

  @override
  State<_CustomerSelectionDialog> createState() =>
      _CustomerSelectionDialogState();
}

class _CustomerSelectionDialogState extends State<_CustomerSelectionDialog> {
  final _searchController = TextEditingController();
  List<Customer> _filteredList = [];

  @override
  void initState() {
    super.initState();
    _filteredList = widget.customerList;
    _searchController.addListener(_filterList);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterList() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredList = widget.customerList.where((customer) {
        return customer.name.toLowerCase().contains(query) ||
            customer.phone.contains(query) ||
            customer.address.toLowerCase().contains(query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: "Müşteri Ara",
                      labelStyle: const TextStyle(color: Colors.black),
                      hintStyle: const TextStyle(color: Colors.black54),
                      prefixIcon: Icon(Icons.search, color: Colors.black54),
                      border: OutlineInputBorder(),
                    ),
                    autofocus: true,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _filteredList.length,
              itemBuilder: (context, index) {
                final customer = _filteredList[index];
                return ListTile(
                  leading: const Icon(Icons.business, color: Colors.black54),
                  title: Text(customer.name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(customer.phone),
                      Text(
                        customer.address,
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  onTap: () => Navigator.of(context).pop(customer),
                );
              },
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
