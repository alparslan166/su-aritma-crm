import "package:flutter/material.dart";
import "package:geocoding/geocoding.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";

import "../../../../core/constants/app_config.dart";
import "../../../../core/error/error_handler.dart";
import "../../application/customer_list_notifier.dart";
import "../../application/personnel_list_notifier.dart";
import "../../data/admin_repository.dart";
import "../../data/models/customer.dart";
import "../../data/models/inventory_item.dart";
import "../../data/models/personnel.dart";

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
  final Map<String, int> _selectedMaterials = {}; // Seçilen malzemeler
  List<InventoryItem> _inventoryList =
      []; // Stok listesi (malzeme isimleri için)

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

  Future<void> _selectMaterials() async {
    final inventory = await ref.read(adminRepositoryProvider).fetchInventory();
    if (!mounted) return;

    final selected = await showDialog<Map<String, int>>(
      context: context,
      builder: (context) => _MaterialSelectionDialog(
        inventory: inventory,
        initialSelection: _selectedMaterials,
      ),
    );
    if (selected != null) {
      setState(() {
        _selectedMaterials.clear();
        _selectedMaterials.addAll(selected);
        _inventoryList = inventory; // Malzeme isimleri için sakla
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
    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Lütfen müşteri seçin")));
      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
      // Geocode address to get location
      Location? location;
      try {
        final locations = await locationFromAddress(_selectedCustomer!.address);
        if (locations.isNotEmpty) {
          location = locations.first;
        }
      } catch (e) {
        // Geocoding failed, continue without location
      }

      // Prepare material IDs from selected materials
      final materialIds = _selectedMaterials.entries
          .map((e) => {"inventoryItemId": e.key, "quantity": e.value})
          .toList();

      await ref
          .read(adminRepositoryProvider)
          .createJob(
            title: _titleController.text.trim(),
            customerName: _selectedCustomer!.name,
            customerPhone: _selectedCustomer!.phone,
            customerAddress: _selectedCustomer!.address,
            customerEmail: _selectedCustomer!.email,
            personnelIds: _selectedPersonnelList.map((p) => p.id).toList(),
            latitude: location?.latitude,
            longitude: location?.longitude,
            locationDescription: _selectedCustomer!.address,
            materialIds: materialIds.isNotEmpty ? materialIds : null,
          );

      // Refresh lists
      ref.invalidate(personnelListProvider);
      ref.invalidate(customerListProvider);

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
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text("İş Ata"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24), //---------------------------------
                //--------------------------------- Müşteri Seç
                OutlinedButton.icon(
                  onPressed: _selectCustomer,
                  icon: const Icon(Icons.business),
                  label: Text(
                    _selectedCustomer != null
                        ? _selectedCustomer!.name
                        : "Müşteri Seç",
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
                const SizedBox(height: 16), //---------------------------------
                //--------------------------------- Personel Seç
                OutlinedButton.icon(
                  onPressed: _selectPersonnel,
                  icon: const Icon(Icons.person),
                  label: Text(
                    _selectedPersonnelList.isEmpty
                        ? "Personel Seç"
                        : "${_selectedPersonnelList.length} personel seçildi",
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
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _selectMaterials,
                    icon: const Icon(Icons.inventory_2),
                    label: Text(
                      _selectedMaterials.isEmpty
                          ? "Yapılacak İşlem - Malzeme Seç"
                          : "${_selectedMaterials.length} malzeme seçildi",
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 18,
                      ),
                      side: BorderSide(
                        color: _selectedMaterials.isEmpty
                            ? Colors.grey.shade300
                            : const Color(0xFF2563EB),
                        width: _selectedMaterials.isEmpty ? 1 : 2,
                      ),
                    ),
                  ),
                ),
                if (_selectedMaterials.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _selectedMaterials.entries.map((entry) {
                      // Get inventory item name from stored list
                      final item = _inventoryList.firstWhere(
                        (item) => item.id == entry.key,
                        orElse: () => InventoryItem(
                          id: entry.key,
                          name: "Bilinmeyen",
                          category: "",
                          sku: "",
                          unit: "adet",
                          unitPrice: 0,
                          stockQty: 0,
                          criticalThreshold: 0,
                          isActive: true,
                        ),
                      );
                      return Chip(
                        label: Text(
                          "${item.name} (${entry.value} ${item.unit})",
                        ),
                        onDeleted: () {
                          setState(() {
                            _selectedMaterials.remove(entry.key);
                          });
                        },
                        deleteIcon: const Icon(Icons.close, size: 18),
                        backgroundColor: const Color(
                          0xFF2563EB,
                        ).withValues(alpha: 0.1),
                        labelStyle: const TextStyle(
                          color: Color(0xFF2563EB),
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 24),
                // Yapılacak İşlem
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: "Yapılacak işlem bilgisi",
                    hintText: "Yapılacak işlem hakkında not",
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
              ],
            ),
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
                      prefixIcon: Icon(Icons.search),
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
                      prefixIcon: Icon(Icons.search),
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
                  leading: const Icon(Icons.business),
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

class _MaterialSelectionDialog extends StatefulWidget {
  const _MaterialSelectionDialog({
    required this.inventory,
    required this.initialSelection,
  });

  final List<InventoryItem> inventory;
  final Map<String, int> initialSelection;

  @override
  State<_MaterialSelectionDialog> createState() =>
      _MaterialSelectionDialogState();
}

class _MaterialSelectionDialogState extends State<_MaterialSelectionDialog> {
  final Map<String, int> _selection = {};
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _selection.addAll(widget.initialSelection);
    for (final item in widget.inventory) {
      _controllers[item.id] = TextEditingController(
        text: widget.initialSelection[item.id]?.toString() ?? "",
      );
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Malzeme Seç"),
      content: SizedBox(
        width: double.maxFinite,
        child: widget.inventory.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Text("Stokta ürün bulunmuyor"),
                ),
              )
            : ListView.builder(
                shrinkWrap: true,
                itemCount: widget.inventory.length,
                itemBuilder: (context, index) {
                  final item = widget.inventory[index];
                  final controller = _controllers[item.id]!;
                  final quantity = int.tryParse(controller.text) ?? 0;
                  return ListTile(
                    leading: Checkbox(
                      value: quantity > 0,
                      onChanged: (checked) {
                        if (checked == true) {
                          controller.text = "1";
                          _selection[item.id] = 1;
                        } else {
                          controller.text = "";
                          _selection.remove(item.id);
                        }
                        setState(() {});
                      },
                    ),
                    title: Text(item.name),
                    subtitle: Text("Stok: ${item.stockQty} ${item.unit}"),
                    trailing: SizedBox(
                      width: 80,
                      child: TextField(
                        controller: controller,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: "Miktar",
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                        ),
                        onChanged: (value) {
                          final qty = int.tryParse(value) ?? 0;
                          if (qty > 0) {
                            _selection[item.id] = qty;
                          } else {
                            _selection.remove(item.id);
                          }
                          setState(() {});
                        },
                      ),
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text("İptal"),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_selection),
          child: const Text("Tamam"),
        ),
      ],
    );
  }
}
