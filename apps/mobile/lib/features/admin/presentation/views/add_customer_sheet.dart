import "package:flutter/material.dart";
import "package:geocoding/geocoding.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:intl/intl.dart";

import "../../application/customer_list_notifier.dart";
import "../../data/admin_repository.dart";
import "../../data/models/personnel.dart";

class AddCustomerSheet extends ConsumerStatefulWidget {
  const AddCustomerSheet({super.key});

  @override
  ConsumerState<AddCustomerSheet> createState() => _AddCustomerSheetState();
}

class _AddCustomerSheetState extends ConsumerState<AddCustomerSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _jobTitleController = TextEditingController();
  final _debtAmountController = TextEditingController();
  final _installmentCountController = TextEditingController();
  final _installmentIntervalDaysController = TextEditingController();
  bool? _hasDebt; // null = not selected, true = yes, false = no
  bool _debtHasInstallment = false;
  late DateTime _createdAt;
  DateTime? _nextDebtDate;
  DateTime? _installmentStartDate;
  bool _submitting = false;
  List<Personnel> _selectedPersonnelList = [];

  @override
  void initState() {
    super.initState();
    _createdAt = DateTime.now();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _jobTitleController.dispose();
    _debtAmountController.dispose();
    _installmentCountController.dispose();
    _installmentIntervalDaysController.dispose();
    super.dispose();
  }

  Future<void> _selectPersonnel() async {
    try {
      // Fetch personnel directly from repository
      final repository = ref.read(adminRepositoryProvider);
      final personnelList = await repository.fetchPersonnel();
      
      if (!mounted) return;
      
      if (personnelList.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Personel bulunamadı")),
        );
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Show confirmation dialog if debt is being added
    final hasDebt = _hasDebt == true;
    final debtAmount = hasDebt && _debtAmountController.text.isNotEmpty
        ? double.tryParse(_debtAmountController.text)
        : null;

    if (hasDebt && debtAmount != null && debtAmount > 0) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Borç Ekleme Onayı"),
          content: Text(
            "${debtAmount.toStringAsFixed(2)} TL borç eklenecek.\n\n"
            "Bu işlemi onaylıyor musunuz?",
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
    }

    setState(() {
      _submitting = true;
    });
    try {
      // Prepare debt data
      final hasInstallment = hasDebt && _debtHasInstallment;
      final installmentCount =
          hasInstallment && _installmentCountController.text.isNotEmpty
          ? int.tryParse(_installmentCountController.text)
          : null;
      final installmentIntervalDays =
          hasInstallment && _installmentIntervalDaysController.text.isNotEmpty
          ? int.tryParse(_installmentIntervalDaysController.text)
          : null;

      // Create customer
      final customer = await ref
          .read(adminRepositoryProvider)
          .createCustomer(
            name: _nameController.text.trim(),
            phone: _phoneController.text.trim(),
            address: _addressController.text.trim(),
            email: _emailController.text.trim().isEmpty
                ? null
                : _emailController.text.trim(),
            location: null,
            createdAt: _createdAt,
            hasDebt: hasDebt,
            debtAmount: debtAmount,
            hasInstallment: hasInstallment,
            installmentCount: installmentCount,
            nextDebtDate: _nextDebtDate,
            installmentStartDate: _installmentStartDate,
            installmentIntervalDays: installmentIntervalDays,
          );

      // If job title is provided, create a job for this customer
      final jobTitle = _jobTitleController.text.trim();
      if (jobTitle.isNotEmpty) {
        try {
          // Geocode address to get location
          Location? location;
          try {
            final locations = await locationFromAddress(_addressController.text.trim());
            if (locations.isNotEmpty) {
              location = locations.first;
            }
          } catch (e) {
            // Geocoding failed, continue without location
          }

          await ref.read(adminRepositoryProvider).createJobForCustomer(
                customerId: customer.id,
                title: jobTitle,
                latitude: location?.latitude,
                longitude: location?.longitude,
                locationDescription: _addressController.text.trim(),
                personnelIds: _selectedPersonnelList.isNotEmpty
                    ? _selectedPersonnelList.map((p) => p.id).toList()
                    : null,
              );
        } catch (e) {
          // Job creation failed, but customer was created successfully
          // Show warning but don't fail the whole operation
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Müşteri eklendi ancak iş oluşturulamadı: $e"),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      }

      await ref.read(customerListProvider.notifier).refresh();
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(
        content: Text(jobTitle.isNotEmpty 
            ? "Müşteri ve iş eklendi" 
            : "Müşteri eklendi"),
      ));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Müşteri eklenemedi: $error")));
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
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text("Yeni Müşteri Ekle"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                // Kayıt Tarihi
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        "Kayıt Tarihi: ${DateFormat("dd MMM yyyy").format(_createdAt)}",
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _createdAt,
                          firstDate: DateTime.now().subtract(const Duration(days: 3650)),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setState(() {
                            _createdAt = picked;
                          });
                        }
                      },
                      child: const Text("Tarih Seç"),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
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
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    labelText: "Adres",
                    hintText: "Şehir, ilçe, mahalle, sokak, bina no",
                  ),
                  maxLines: 2,
                  validator: (value) => value == null || value.trim().length < 3
                      ? "Adres girin"
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _jobTitleController,
                  decoration: const InputDecoration(
                    labelText: "Yapılacak İşlem",
                    hintText: "Örn: Su arıtma cihazı bakımı",
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                // Personel Ata
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
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                Text(
                  "Borç Bilgileri (Opsiyonel)",
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _hasDebt = true;
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          backgroundColor: _hasDebt == true
                              ? const Color(0xFF2563EB).withValues(alpha: 0.1)
                              : null,
                          side: BorderSide(
                            color: _hasDebt == true
                                ? const Color(0xFF2563EB)
                                : Colors.grey.shade300,
                            width: _hasDebt == true ? 2 : 1,
                          ),
                        ),
                        child: const Text("Evet"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _hasDebt = false;
                            _debtAmountController.clear();
                            _debtHasInstallment = false;
                            _installmentCountController.clear();
                            _installmentIntervalDaysController.clear();
                            _nextDebtDate = null;
                            _installmentStartDate = null;
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          backgroundColor: _hasDebt == false
                              ? const Color(0xFF2563EB).withValues(alpha: 0.1)
                              : null,
                          side: BorderSide(
                            color: _hasDebt == false
                                ? const Color(0xFF2563EB)
                                : Colors.grey.shade300,
                            width: _hasDebt == false ? 2 : 1,
                          ),
                        ),
                        child: const Text("Hayır"),
                      ),
                    ),
                  ],
                ),
                if (_hasDebt == true) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _debtAmountController,
                    decoration: const InputDecoration(
                      labelText: "Borç Miktarı (TL)",
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (_hasDebt == true &&
                          (value == null || value.trim().isEmpty)) {
                        return "Borç miktarı girin";
                      }
                      if (value != null && value.trim().isNotEmpty) {
                        final amount = double.tryParse(value);
                        if (amount == null || amount <= 0) {
                          return "Geçerli bir miktar girin";
                        }
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  // Ödeme Tarihi
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          "Ödeme Tarihi: ${_nextDebtDate != null ? DateFormat("dd MMM yyyy").format(_nextDebtDate!) : "Seçilmedi"}",
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _nextDebtDate ?? DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 3650)),
                          );
                          if (picked != null) {
                            setState(() {
                              _nextDebtDate = picked;
                            });
                          }
                        },
                        icon: const Icon(Icons.calendar_today, size: 18),
                        label: const Text("Tarih Seç"),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _debtHasInstallment = true;
                            });
                          },
                          style: OutlinedButton.styleFrom(
                            backgroundColor: _debtHasInstallment
                                ? const Color(0xFF2563EB).withValues(alpha: 0.1)
                                : null,
                            side: BorderSide(
                              color: _debtHasInstallment
                                  ? const Color(0xFF2563EB)
                                  : Colors.grey.shade300,
                              width: _debtHasInstallment ? 2 : 1,
                            ),
                          ),
                          child: const Text("Taksit Var"),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _debtHasInstallment = false;
                              _installmentCountController.clear();
                              _installmentIntervalDaysController.clear();
                              _installmentStartDate = null;
                            });
                          },
                          style: OutlinedButton.styleFrom(
                            backgroundColor: !_debtHasInstallment
                                ? const Color(0xFF2563EB).withValues(alpha: 0.1)
                                : null,
                            side: BorderSide(
                              color: !_debtHasInstallment
                                  ? const Color(0xFF2563EB)
                                  : Colors.grey.shade300,
                              width: !_debtHasInstallment ? 2 : 1,
                            ),
                          ),
                          child: const Text("Taksit Yok"),
                        ),
                      ),
                    ],
                  ),
                  if (_debtHasInstallment) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _installmentCountController,
                      decoration: const InputDecoration(
                        labelText: "Taksit Sayısı",
                        prefixIcon: Icon(Icons.numbers),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (_debtHasInstallment &&
                            (value == null || value.trim().isEmpty)) {
                          return "Taksit sayısı girin";
                        }
                        if (value != null && value.trim().isNotEmpty) {
                          final count = int.tryParse(value);
                          if (count == null || count <= 0) {
                            return "Geçerli bir sayı girin";
                          }
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    // Taksit Başlama Tarihi
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            "Taksit Başlama Tarihi: ${_installmentStartDate != null ? DateFormat("dd MMM yyyy").format(_installmentStartDate!) : "Seçilmedi"}",
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _installmentStartDate ?? DateTime.now(),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 3650)),
                            );
                            if (picked != null) {
                              setState(() {
                                _installmentStartDate = picked;
                              });
                            }
                          },
                          icon: const Icon(Icons.calendar_today, size: 18),
                          label: const Text("Tarih Seç"),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Taksit Tekrar Günü
                    TextFormField(
                      controller: _installmentIntervalDaysController,
                      decoration: const InputDecoration(
                        labelText: "Taksit Tekrar Günü",
                        prefixIcon: Icon(Icons.repeat),
                        helperText: "Her kaç günde bir taksit ödemesi yapılacak? (örn: 30)",
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (_debtHasInstallment &&
                            (value == null || value.trim().isEmpty)) {
                          return "Taksit tekrar günü girin";
                        }
                        if (value != null && value.trim().isNotEmpty) {
                          final days = int.tryParse(value);
                          if (days == null || days <= 0) {
                            return "Geçerli bir gün sayısı girin";
                          }
                        }
                        return null;
                      },
                    ),
                  ],
                ],
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
                    secondary: personnel.personnelId != null
                        ? Chip(
                            label: Text(
                              personnel.personnelId!,
                              style: const TextStyle(fontSize: 10),
                            ),
                          )
                        : const Icon(Icons.person),
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
