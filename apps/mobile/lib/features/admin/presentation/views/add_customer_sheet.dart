import "dart:async";

import "package:flutter/material.dart";

import "../../../../core/error/error_handler.dart";
import "package:geocoding/geocoding.dart";
import "package:geolocator/geolocator.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:intl/intl.dart";

import "../../../../features/auth/domain/auth_role.dart";
import "../../../../core/session/session_provider.dart";
import "../../application/customer_list_notifier.dart";
import "../../application/personnel_list_notifier.dart";
import "../../data/admin_repository.dart";
import "../../data/models/personnel.dart";
import "../../data/models/inventory_item.dart";

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
  List<Personnel> _selectedPersonnel = [];
  final Map<String, int> _selectedMaterials = {}; // Seçilen malzemeler
  List<InventoryItem> _inventoryList =
      []; // Stok listesi (malzeme isimleri için)

  @override
  void initState() {
    super.initState();
    _createdAt = DateTime.now();
    _jobTitleController.addListener(() {
      setState(() {}); // Buton durumunu güncelle
    });
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

  Future<void> _getCurrentLocation() async {
    try {
      // Konum izni kontrolü
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Konum servisleri kapalı. Lütfen açın."),
          ),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Konum izni reddedildi.")),
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Konum izni kalıcı olarak reddedilmiş. Ayarlardan açın.",
            ),
          ),
        );
        return;
      }

      // Mevcut konumu al
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Konum alınıyor..."),
          duration: Duration(seconds: 1),
        ),
      );

      Position position;
      try {
        position =
            await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high,
            ).timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                throw TimeoutException(
                  "Konum alınamadı",
                  const Duration(seconds: 10),
                );
              },
            );
      } on TimeoutException catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Mevcut konum alınamadı. Lütfen tekrar deneyin."),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

      // Reverse geocoding ile adres bilgisini al
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        // Adres bilgisini formatla
        final addressParts = <String>[];
        if (placemark.street != null && placemark.street!.isNotEmpty) {
          addressParts.add(placemark.street!);
        }
        if (placemark.subThoroughfare != null &&
            placemark.subThoroughfare!.isNotEmpty) {
          addressParts.add('No: ${placemark.subThoroughfare}');
        }
        if (placemark.subLocality != null &&
            placemark.subLocality!.isNotEmpty) {
          addressParts.add(placemark.subLocality!);
        }
        if (placemark.locality != null && placemark.locality!.isNotEmpty) {
          addressParts.add(placemark.locality!);
        }
        if (placemark.administrativeArea != null &&
            placemark.administrativeArea!.isNotEmpty) {
          addressParts.add(placemark.administrativeArea!);
        }
        if (placemark.postalCode != null && placemark.postalCode!.isNotEmpty) {
          addressParts.add(placemark.postalCode!);
        }

        final address = addressParts.join(', ');

        if (mounted) {
          setState(() {
            _addressController.text = address;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Adres otomatik olarak eklendi"),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Adres bilgisi alınamadı")),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Konum alınamadı: $e")));
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
            final locations = await locationFromAddress(
              _addressController.text.trim(),
            );
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
              .createJobForCustomer(
                customerId: customer.id,
                title: jobTitle,
                latitude: location?.latitude,
                longitude: location?.longitude,
                locationDescription: _addressController.text.trim(),
                personnelIds: _selectedPersonnel.isNotEmpty
                    ? _selectedPersonnel.map((p) => p.id).toList()
                    : null,
                materialIds: materialIds.isNotEmpty ? materialIds : null,
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            jobTitle.isNotEmpty ? "Müşteri ve iş eklendi" : "Müşteri eklendi",
          ),
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

  Future<void> _showPersonnelSelection() async {
    final personnelState = ref.read(personnelListProvider);
    List<Personnel> personnelList = [];

    if (personnelState.hasValue) {
      personnelList = personnelState.value!;
    } else {
      // Personel listesi yüklenmemişse, yükle
      final asyncValue = await ref.read(personnelListProvider.future);
      personnelList = asyncValue;
    }

    if (personnelList.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Personel bulunamadı"),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    if (!mounted) return;
    final selected = await showModalBottomSheet<List<Personnel>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _PersonnelSelectionSheet(
        personnelList: personnelList,
        initialSelection: _selectedPersonnel,
      ),
    );

    if (selected != null && mounted) {
      setState(() {
        _selectedPersonnel = selected;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authSessionProvider);
    final isAdmin = session?.role == AuthRole.admin;

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
                          firstDate: DateTime.now().subtract(
                            const Duration(days: 3650),
                          ),
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
                  textCapitalization: TextCapitalization.words,
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
                  textCapitalization: TextCapitalization.sentences,
                  validator: (value) => value == null || value.trim().length < 3
                      ? "Adres girin"
                      : null,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.grey.shade200, width: 1),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _getCurrentLocation,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 18,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF2563EB).withValues(alpha: 0.1),
                                const Color(0xFF2563EB).withValues(alpha: 0.05),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF2563EB,
                                  ).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.my_location,
                                  color: Color(0xFF2563EB),
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                "Bulunduğum Konumu Seç",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade900,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
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
                const SizedBox(height: 12),
                TextFormField(
                  controller: _jobTitleController,
                  decoration: const InputDecoration(
                    labelText: "Yapılacak işlem bilgisi (Opsiyonel)",
                    hintText: "Yapılacak işlem hakkında not",
                  ),
                  maxLines: 3,
                ),
                if (isAdmin) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.grey.shade200, width: 1),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _jobTitleController.text.trim().isEmpty
                              ? null
                              : _showPersonnelSelection,
                          borderRadius: BorderRadius.circular(16),
                          child: Opacity(
                            opacity: _jobTitleController.text.trim().isEmpty
                                ? 0.5
                                : 1.0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 18,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(
                                      0xFF10B981,
                                    ).withValues(alpha: 0.1),
                                    const Color(
                                      0xFF10B981,
                                    ).withValues(alpha: 0.05),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF10B981,
                                      ).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.person_add,
                                      color: Color(0xFF10B981),
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    _selectedPersonnel.isEmpty
                                        ? "Personel Ata"
                                        : "${_selectedPersonnel.length} Personel Seçildi",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade900,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_selectedPersonnel.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _selectedPersonnel.map((personnel) {
                        return Chip(
                          label: Text(personnel.name),
                          onDeleted: () {
                            setState(() {
                              _selectedPersonnel.remove(personnel);
                            });
                          },
                          deleteIcon: const Icon(Icons.close, size: 18),
                          backgroundColor: const Color(
                            0xFF10B981,
                          ).withValues(alpha: 0.1),
                          labelStyle: const TextStyle(
                            color: Color(0xFF10B981),
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
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
                  // Ödeme Tarihi - Sadece taksit yoksa göster
                  if (!_debtHasInstallment) ...[
                    const SizedBox(height: 12),
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
                              lastDate: DateTime.now().add(
                                const Duration(days: 3650),
                              ),
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
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _debtHasInstallment = true;
                              _nextDebtDate =
                                  null; // Taksit seçildiğinde ödeme tarihini temizle
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
                              initialDate:
                                  _installmentStartDate ?? DateTime.now(),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(
                                const Duration(days: 3650),
                              ),
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
                    // Ödeme Tekrar Günü
                    TextFormField(
                      controller: _installmentIntervalDaysController,
                      decoration: const InputDecoration(
                        labelText: "Ödeme kaç günde bir olacak?",
                        prefixIcon: Icon(Icons.repeat),
                        helperText:
                            "Her kaç günde bir taksit ödemesi yapılacak? (örn: 30)",
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (_debtHasInstallment &&
                            (value == null || value.trim().isEmpty)) {
                          return "Ödeme tekrar günü girin";
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

class _PersonnelSelectionSheet extends ConsumerStatefulWidget {
  const _PersonnelSelectionSheet({
    required this.personnelList,
    required this.initialSelection,
  });

  final List<Personnel> personnelList;
  final List<Personnel> initialSelection;

  @override
  ConsumerState<_PersonnelSelectionSheet> createState() =>
      _PersonnelSelectionSheetState();
}

class _PersonnelSelectionSheetState
    extends ConsumerState<_PersonnelSelectionSheet> {
  late Set<String> _selectedIds;

  @override
  void initState() {
    super.initState();
    _selectedIds = widget.initialSelection.map((p) => p.id).toSet();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Personel Seç",
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              if (_selectedIds.isNotEmpty)
                Text(
                  "${_selectedIds.length} seçildi",
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: widget.personnelList.length,
              itemBuilder: (context, index) {
                final personnel = widget.personnelList[index];
                final isSelected = _selectedIds.contains(personnel.id);
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isSelected
                          ? const Color(0xFF2563EB)
                          : Colors.grey.shade200,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: CheckboxListTile(
                    value: isSelected,
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _selectedIds.add(personnel.id);
                        } else {
                          _selectedIds.remove(personnel.id);
                        }
                      });
                    },
                    title: Text(
                      personnel.name,
                      style: TextStyle(
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(personnel.phone),
                    secondary: CircleAvatar(
                      backgroundColor: isSelected
                          ? const Color(0xFF2563EB).withValues(alpha: 0.1)
                          : Colors.grey.shade200,
                      child: Text(
                        personnel.name.isNotEmpty
                            ? personnel.name[0].toUpperCase()
                            : "P",
                        style: TextStyle(
                          color: isSelected
                              ? const Color(0xFF2563EB)
                              : Colors.grey.shade600,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                final selected = widget.personnelList
                    .where((p) => _selectedIds.contains(p.id))
                    .toList();
                Navigator.of(context).pop(selected);
              },
              child: const Text("Tamam"),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
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
