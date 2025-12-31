import "dart:async";

import "package:flutter/material.dart";

import "../../../../core/error/error_handler.dart";
import "package:geocoding/geocoding.dart";
import "package:geolocator/geolocator.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:intl/intl.dart";
import "package:flutter_map/flutter_map.dart";
import "package:latlong2/latlong.dart";

import "../../application/customer_list_notifier.dart";
import "../../data/admin_repository.dart";
import "../../data/models/inventory_item.dart";
import "../../../dashboard/presentation/home_page_provider.dart";
import "../widgets/interactive_location_picker.dart";
import "../widgets/material_selection_dialog.dart";
import "customers_view.dart"; // CustomerFilterType enum'ı için

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
  final _debtAmountController = TextEditingController();
  final _installmentCountController = TextEditingController();
  final _installmentIntervalDaysController = TextEditingController();
  final _receivedAmountController = TextEditingController(); // Alınan ücret
  bool? _hasDebt; // null = not selected, true = yes, false = no
  bool _debtHasInstallment = false;
  late DateTime _createdAt;
  DateTime? _nextDebtDate;
  DateTime? _installmentStartDate;
  bool _submitting = false;
  final Map<String, int> _selectedMaterials = {}; // Seçilen malzemeler
  bool _deductFromStock = true; // Stoktan düşülsün mü?
  List<InventoryItem> _inventoryList =
      []; // Stok listesi (malzeme isimleri için)
  LatLng? _currentLocation; // Konum bilgisi
  late DateTime _lastTransactionDate; // Son işlem tarihi
  double _filterChangeMonths = 0.0; // Filtre değişim ayı (0-12 arası)
  DateTime? _paymentDate; // Ücret alım tarihi

  @override
  void initState() {
    super.initState();
    _createdAt = DateTime.now();
    _lastTransactionDate = DateTime.now(); // Varsayılan olarak bugün
    _paymentDate = DateTime.now(); // Varsayılan olarak bugün
    _installmentStartDate = DateTime.now(); // Varsayılan: bugün
    _installmentIntervalDaysController.text = "30"; // Varsayılan: 30 gün
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _debtAmountController.dispose();
    _installmentCountController.dispose();
    _installmentIntervalDaysController.dispose();
    _receivedAmountController.dispose();
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

      // Show interactive location picker
      if (!mounted) return;
      final initialLocation = LatLng(position.latitude, position.longitude);

      final selectedLocation = await showModalBottomSheet<LatLng>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => InteractiveLocationPicker(
          initialLocation: initialLocation,
          onLocationSelected: (location) {
            Navigator.of(context).pop(location);
          },
        ),
      );

      if (selectedLocation != null && mounted) {
        // Reverse geocoding ile adres bilgisini al
        try {
          List<Placemark> placemarks = await placemarkFromCoordinates(
            selectedLocation.latitude,
            selectedLocation.longitude,
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
            if (placemark.postalCode != null &&
                placemark.postalCode!.isNotEmpty) {
              addressParts.add(placemark.postalCode!);
            }

            final address = addressParts.join(', ');

            setState(() {
              _addressController.text = address;
              _currentLocation = selectedLocation;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Konum seçildi ve adres otomatik olarak eklendi"),
                backgroundColor: Colors.green,
              ),
            );
          } else {
            setState(() {
              _currentLocation = selectedLocation;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Konum seçildi (adres bilgisi alınamadı)"),
              ),
            );
          }
        } catch (e) {
          // If reverse geocoding fails, just save the location
          setState(() {
            _currentLocation = selectedLocation;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Konum seçildi (adres alınamadı: $e)")),
          );
        }
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

      // GPS konumunu location formatına çevir
      Map<String, dynamic>? locationData;
      if (_currentLocation != null) {
        locationData = {
          "latitude": _currentLocation!.latitude,
          "longitude": _currentLocation!.longitude,
        };
      }

      // Hesaplanan bakım tarihi - slider değeri 0 veya büyükse gönder
      DateTime? calculatedMaintenanceDate;
      if (_filterChangeMonths >= 0) {
        calculatedMaintenanceDate = _lastTransactionDate.add(
          Duration(days: (_filterChangeMonths * 30).toInt()),
        );
      }

      // Create customer
      await ref
          .read(adminRepositoryProvider)
          .createCustomer(
            name: _nameController.text.trim(),
            phone: _phoneController.text.trim(),
            address: _addressController.text.trim(),
            email: _emailController.text.trim().isEmpty
                ? null
                : _emailController.text.trim(),
            location: locationData, // GPS konumunu direkt kullan
            createdAt: _createdAt,
            hasDebt: hasDebt,
            debtAmount: debtAmount,
            hasInstallment: hasInstallment,
            installmentCount: installmentCount,
            nextDebtDate: _nextDebtDate,
            installmentStartDate: _installmentStartDate,
            installmentIntervalDays: installmentIntervalDays,
            nextMaintenanceDate:
                calculatedMaintenanceDate, // Bakım bilgilerini gönder
            receivedAmount: _receivedAmountController.text.trim().isNotEmpty
                ? double.tryParse(_receivedAmountController.text.trim())
                : null,
            paymentDate: _paymentDate,
          );

      // Tüm filter type'lar için provider'ları refresh et
      // Böylece hangi sayfada olursa olsun müşteri listesi otomatik güncellenir
      // Mevcut filtreleri koruyarak refresh et (showLoading=false)
      ref.read(customerListProvider.notifier).refresh(showLoading: false);

      // Tüm filter type'lar için ayrı ayrı refresh et
      for (final filterType in [
        CustomerFilterType.all,
        CustomerFilterType.overduePayment,
        CustomerFilterType.upcomingMaintenance,
        CustomerFilterType.overdueInstallment,
      ]) {
        final filterTypeKey = filterType.toString();
        final notifier = ref.read(
          customerListProviderForFilter(filterTypeKey).notifier,
        );
        // Mevcut filtreleri koruyarak refresh et (showLoading=false)
        notifier.refresh(showLoading: false);
      }

      // Ana sayfa grafik ve istatistiklerini statik olarak yenile
      ref.invalidate(dashboardStatsProvider);
      ref.invalidate(customerCategoryDataProvider);
      ref.invalidate(overduePaymentsCustomersProvider);
      ref.invalidate(upcomingMaintenanceProvider);

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Müşteri eklendi")));
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

    final result = await showDialog<({Map<String, int> selection, bool deductFromStock})>(
      context: context,
      builder: (context) => MaterialSelectionDialog(
        inventory: inventory,
        initialSelection: _selectedMaterials,
      ),
    );
    if (result != null) {
      setState(() {
        _selectedMaterials.clear();
        _selectedMaterials.addAll(result.selection);
        _deductFromStock = result.deductFromStock;
        _inventoryList = inventory; // Malzeme isimleri için sakla
      });
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
                // Kayıt Tarihi - Filtre Değişim bölümü gibi güzel gösterim
                Text(
                  "Kayıt Bilgileri",
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  readOnly: true,
                  controller: TextEditingController(
                    text: DateFormat("dd.MM.yyyy").format(_createdAt),
                  ),
                  decoration: InputDecoration(
                    labelText: "Kayıt Tarihi",
                    hintText: "Tarih seçin",
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_today),
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
                    ),
                  ),
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
                                _currentLocation != null
                                    ? "Konumu Düzenle"
                                    : "Bulunduğum Konumu Seç",
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
                // Alınan Ücret alanı
                TextField(
                  controller: _receivedAmountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: "Alınan Ücret (₺)",
                    prefixIcon: const Icon(Icons.attach_money),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                ),
                const SizedBox(height: 12),
                // Ücret Alım Tarihi
                TextFormField(
                  readOnly: true,
                  controller: TextEditingController(
                    text: _paymentDate != null
                        ? DateFormat("dd.MM.yyyy").format(_paymentDate!)
                        : "",
                  ),
                  decoration: InputDecoration(
                    labelText: "Ücret Alım Tarihi",
                    hintText: "Tarih seçin",
                    prefixIcon: const Icon(Icons.calendar_today),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _paymentDate ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setState(() {
                            _paymentDate = picked;
                          });
                        }
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                ),
                // Harita gösterimi - konum ve adres varsa
                if (_currentLocation != null &&
                    _addressController.text.trim().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.grey.shade200, width: 1),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(
                        height: 200,
                        width: double.infinity,
                        child: FlutterMap(
                          options: MapOptions(
                            initialCenter: _currentLocation!,
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
                                  point: _currentLocation!,
                                  width: 40,
                                  height: 40,
                                  child: const Icon(
                                    Icons.location_on,
                                    color: Color(0xFF2563EB),
                                    size: 40,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
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
                          ? "Kullanılan Ürün Bilgisi"
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
                // Filtre Değişim Tarihi Bölümü
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                Text(
                  "Filtre Değişim Bilgileri",
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                // Son işlem tarihi
                TextFormField(
                  readOnly: true,
                  controller: TextEditingController(
                    text: DateFormat("dd.MM.yyyy").format(_lastTransactionDate),
                  ),
                  decoration: InputDecoration(
                    labelText: "Son işlem tarihi",
                    hintText: "Tarih seçin",
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _lastTransactionDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setState(() {
                            _lastTransactionDate = picked;
                          });
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Sonraki Filtre Değişim Tarihi Slider
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Sonraki Filtre Değişim Tarihi ?",
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Minus button
                            GestureDetector(
                              onTap: () {
                                if (_filterChangeMonths > 0) {
                                  setState(() {
                                    _filterChangeMonths--;
                                  });
                                }
                              },
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2563EB),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(
                                  Icons.remove,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              "${_filterChangeMonths.toInt()} ay",
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF2563EB),
                                  ),
                            ),
                            const SizedBox(width: 12),
                            // Plus button
                            GestureDetector(
                              onTap: () {
                                if (_filterChangeMonths < 12) {
                                  setState(() {
                                    _filterChangeMonths++;
                                  });
                                }
                              },
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2563EB),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(
                                  Icons.add,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Slider(
                      value: _filterChangeMonths,
                      min: 0,
                      max: 12,
                      divisions: 12,
                      label: "${_filterChangeMonths.toInt()} ay",
                      onChanged: (value) {
                        setState(() {
                          _filterChangeMonths = value;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Filtre Değişim Zamanı (Hesaplanan)
                TextFormField(
                  readOnly: true,
                  controller: TextEditingController(
                    text: DateFormat("dd.MM.yyyy").format(
                      _lastTransactionDate.add(
                        Duration(days: (_filterChangeMonths * 30).toInt()),
                      ),
                    ),
                  ),
                  decoration: InputDecoration(
                    labelText: "Filtre Değişim Zamanı",
                    hintText: "Tarih hesaplanacak",
                    suffixIcon: const Icon(Icons.calendar_today),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                  ),
                  style: const TextStyle(color: Colors.black),
                ),
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
                    onChanged: (_) => setState(() {}), // Kutucukları güncelle
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
                    TextFormField(
                      readOnly: true,
                      controller: TextEditingController(
                        text: _nextDebtDate != null
                            ? DateFormat("dd.MM.yyyy").format(_nextDebtDate!)
                            : "",
                      ),
                      decoration: InputDecoration(
                        labelText: "Ödeme Tarihi",
                        hintText: "Tarih seçin",
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.calendar_today),
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
                        ),
                      ),
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
                          child: const Text("Taksitli Satış Var"),
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
                          child: const Text("Taksitli Satış Yok"),
                        ),
                      ),
                    ],
                  ),
                  if (_debtHasInstallment) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _installmentCountController,
                      decoration: const InputDecoration(
                        labelText: "Kaç taksit olacak?",
                        prefixIcon: Icon(Icons.numbers),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}), // Kutucukları güncelle
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
                    TextFormField(
                      readOnly: true,
                      controller: TextEditingController(
                        text: _installmentStartDate != null
                            ? DateFormat(
                                "dd.MM.yyyy",
                              ).format(_installmentStartDate!)
                            : "",
                      ),
                      decoration: InputDecoration(
                        labelText: "Taksit Başlama Tarihi",
                        hintText: "Tarih seçin",
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.calendar_today),
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
                        ),
                      ),
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
                      onChanged: (_) => setState(() {}), // Kutucukları güncelle
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
                    // Taksit Önizleme Kutucukları
                    if (_installmentCountController.text.isNotEmpty &&
                        int.tryParse(_installmentCountController.text) != null &&
                        int.parse(_installmentCountController.text) > 0) ...[
                      const SizedBox(height: 16),
                      Text(
                        "Taksit Planı Önizlemesi",
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: List.generate(
                            int.parse(_installmentCountController.text),
                            (index) {
                              final installmentNo = index + 1;
                              final intervalDays = int.tryParse(
                                    _installmentIntervalDaysController.text,
                                  ) ??
                                  30;
                              final startDate =
                                  _installmentStartDate ?? DateTime.now();
                              final dueDate = startDate.add(
                                Duration(days: intervalDays * installmentNo),
                              );
                              final debtAmount = double.tryParse(
                                    _debtAmountController.text,
                                  ) ??
                                  0;
                              final installmentAmount =
                                  debtAmount /
                                  int.parse(_installmentCountController.text);

                              return Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      "$installmentNo",
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF2563EB),
                                      ),
                                    ),
                                    Text(
                                      "${installmentAmount.toStringAsFixed(0)}₺",
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    Text(
                                      DateFormat("dd/MM/yyyy").format(dueDate),
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
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
                const SizedBox(height: 80),
                SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


