import "dart:async";

import "package:flutter/material.dart";
import "package:flutter/foundation.dart" show debugPrint;
import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:intl/intl.dart";
import "package:geocoding/geocoding.dart";
import "package:geolocator/geolocator.dart";
import "package:flutter_map/flutter_map.dart";
import "package:latlong2/latlong.dart";

import "../../../../core/error/error_handler.dart";
import "../../application/customer_list_notifier.dart";
import "../../data/admin_repository.dart";
import "../../data/models/customer.dart";
import "customer_detail_page.dart" show customerDetailProvider;
import "customers_view.dart"; // CustomerFilterType enum'ı için

class EditCustomerSheet extends ConsumerStatefulWidget {
  const EditCustomerSheet({super.key, required this.customer});

  final Customer customer;

  @override
  ConsumerState<EditCustomerSheet> createState() => _EditCustomerSheetState();
}

class _EditCustomerSheetState extends ConsumerState<EditCustomerSheet> {
  late final GlobalKey<FormState> _formKey;
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _addressController;
  late final TextEditingController _debtAmountController;
  late final TextEditingController _installmentCountController;
  late final TextEditingController _installmentIntervalDaysController;

  bool? _hasDebt;
  bool _debtHasInstallment = false;
  DateTime? _createdAt;
  DateTime? _nextDebtDate;
  DateTime? _installmentStartDate;
  bool _submitting = false;
  LatLng? _currentLocation; // Konum bilgisi
  DateTime _lastMaintenanceDate = DateTime.now(); // Son bakım tarihi
  double _nextMaintenanceMonths = 0.0; // Sonraki bakım ayı (0-12 arası)
  bool _maintenanceDateChanged = false; // Bakım tarihi değiştirildi mi?

  @override
  void initState() {
    super.initState();
    _formKey = GlobalKey<FormState>();
    final customer = widget.customer;
    _nameController = TextEditingController(text: customer.name);
    _phoneController = TextEditingController(text: customer.phone);
    _emailController = TextEditingController(text: customer.email ?? "");
    _addressController = TextEditingController(text: customer.address);
    _debtAmountController = TextEditingController(
      text: customer.debtAmount?.toStringAsFixed(2) ?? "",
    );
    _installmentCountController = TextEditingController(
      text: customer.installmentCount?.toString() ?? "",
    );
    _installmentIntervalDaysController = TextEditingController(
      text: customer.installmentIntervalDays?.toString() ?? "",
    );

    _hasDebt = customer.hasDebt;
    _debtHasInstallment = customer.hasInstallment;
    _createdAt = customer.createdAt;
    _nextDebtDate = customer.nextDebtDate;
    _installmentStartDate = customer.installmentStartDate;
    // Bakım tarihi - varsayılan olarak bugün veya müşterinin nextMaintenanceDate'i
    try {
      final nextMaintenance = customer.nextMaintenanceDate;
      if (nextMaintenance != null) {
        // Eğer nextMaintenanceDate varsa, bunu son bakım tarihi olarak kullan
        _lastMaintenanceDate = nextMaintenance;
        // Slider değerini 0 olarak başlat (kullanıcı değiştirebilir)
        _nextMaintenanceMonths = 0.0;
      } else {
        // Eğer nextMaintenanceDate yoksa, bugünü kullan
        _lastMaintenanceDate = DateTime.now();
        _nextMaintenanceMonths = 0.0;
      }
      _maintenanceDateChanged = false; // Başlangıçta değişiklik yok
    } catch (e) {
      // Hata durumunda bugünü kullan
      _lastMaintenanceDate = DateTime.now();
      _nextMaintenanceMonths = 0.0;
      _maintenanceDateChanged = false;
    }

    // Mevcut müşterinin konum bilgisini yükle
    if (customer.location != null) {
      _currentLocation = LatLng(
        customer.location!.latitude,
        customer.location!.longitude,
      );
    }

    // Adres değiştiğinde haritayı güncelle
    _addressController.addListener(() {
      if (_addressController.text.trim().isEmpty) {
        setState(() {
          _currentLocation = null;
        });
      }
    });
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
    super.dispose();
  }

  Future<void> _submit() async {
    debugPrint(
      "═══════════════════════════════════════════════════════════════════════════════════════════",
    );
    debugPrint("🔵🔵🔵 Frontend - _submit BAŞLADI 🔵🔵🔵");
    debugPrint("   Customer ID: ${widget.customer.id}");
    
    if (!_formKey.currentState!.validate()) {
      debugPrint("   ❌ Form validation başarısız!");
      debugPrint(
        "═══════════════════════════════════════════════════════════════════════════════════════════",
      );
      return;
    }
    debugPrint("   ✅ Form validation başarılı");
    
    setState(() {
      _submitting = true;
    });
    try {
      // Prepare debt data
      final hasDebt = _hasDebt == true;
      final newDebtAmount = hasDebt && _debtAmountController.text.isNotEmpty
          ? double.tryParse(_debtAmountController.text)
          : null;

      // Calculate remaining debt: if new debt is set, add to existing remaining debt
      double? remainingDebtAmount;
      if (hasDebt && newDebtAmount != null) {
        final existingRemaining = widget.customer.remainingDebtAmount ?? 0.0;
        remainingDebtAmount = existingRemaining + newDebtAmount;
      }

      // Calculate total debt: if new debt is set, add to existing debt
      double? debtAmount;
      if (hasDebt && newDebtAmount != null) {
        final existingDebt = widget.customer.debtAmount ?? 0.0;
        debtAmount = existingDebt + newDebtAmount;
      }

      final hasInstallment = hasDebt && _debtHasInstallment;
      final installmentCount =
          hasInstallment && _installmentCountController.text.isNotEmpty
          ? int.tryParse(_installmentCountController.text)
          : null;
      final installmentIntervalDays =
          hasInstallment && _installmentIntervalDaysController.text.isNotEmpty
          ? int.tryParse(_installmentIntervalDaysController.text)
          : null;

      // Show confirmation dialog for debt changes
      if (hasDebt && newDebtAmount != null && newDebtAmount > 0) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Borç Ekleme Onayı"),
            content: Text(
              "${newDebtAmount.toStringAsFixed(2)} TL borç eklenecek.\n"
              "Mevcut borç: ${widget.customer.remainingDebtAmount?.toStringAsFixed(2) ?? "0.00"} TL\n"
              "Yeni toplam borç: ${remainingDebtAmount?.toStringAsFixed(2) ?? "0.00"} TL\n\n"
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
        if (confirm != true) {
          if (mounted) {
            setState(() {
              _submitting = false;
            });
          }
          return;
        }
      }

      // Hesaplanan bakım tarihi - sadece kullanıcı değişiklik yaptıysa gönder
      // Her zaman calculatedMaintenanceDate'i hesapla
      // Eğer slider 0 ise null gönder (bakım tarihini temizle)
      // Eğer slider > 0 ise hesaplanan tarihi gönder
      DateTime? calculatedMaintenanceDate;
      if (_nextMaintenanceMonths > 0) {
        calculatedMaintenanceDate = _lastMaintenanceDate.add(
          Duration(days: (_nextMaintenanceMonths * 30).toInt()),
        );
      } else {
        // Slider 0 ise bakım tarihini temizle (null gönder)
        calculatedMaintenanceDate = null;
      }

      debugPrint(
        "═══════════════════════════════════════════════════════════════════════════════════════════",
      );
      debugPrint(
        "🔵🔵🔵 Frontend - Bakım Tarihi Hesaplama 🔵🔵🔵",
      );
      debugPrint(
        "   _maintenanceDateChanged: $_maintenanceDateChanged",
      );
      debugPrint(
        "   _nextMaintenanceMonths: $_nextMaintenanceMonths",
      );
      debugPrint(
        "   _lastMaintenanceDate: $_lastMaintenanceDate",
      );
      debugPrint(
        "   calculatedMaintenanceDate: $calculatedMaintenanceDate",
      );
      debugPrint(
        "   sendNextMaintenanceDate: true (her zaman gönderiliyor)",
      );
      debugPrint(
        "═══════════════════════════════════════════════════════════════════════════════════════════",
      );

      // GPS konumunu location formatına çevir
      Map<String, dynamic>? locationData;
      if (_currentLocation != null) {
        locationData = {
          "latitude": _currentLocation!.latitude,
          "longitude": _currentLocation!.longitude,
        };
      }

      // Update customer
      // nextMaintenanceDate sadece kullanıcı değişiklik yaptıysa gönder
      debugPrint(
        "═══════════════════════════════════════════════════════════════════════════════════════════",
      );
      debugPrint("🔵🔵🔵 Frontend - updateCustomer ÇAĞRILIYOR 🔵🔵🔵");
      debugPrint("   Customer ID: ${widget.customer.id}");
      debugPrint("   nextMaintenanceDate: $calculatedMaintenanceDate");
      debugPrint("   sendNextMaintenanceDate: true");
      debugPrint(
        "═══════════════════════════════════════════════════════════════════════════════════════════",
      );
      
      await ref
          .read(adminRepositoryProvider)
          .updateCustomer(
            id: widget.customer.id,
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
            remainingDebtAmount: remainingDebtAmount,
            hasInstallment: hasInstallment,
            installmentCount: installmentCount,
            nextDebtDate: _nextDebtDate,
            installmentStartDate: _installmentStartDate,
            installmentIntervalDays: installmentIntervalDays,
            nextMaintenanceDate: calculatedMaintenanceDate, // null veya tarih
            sendNextMaintenanceDate:
                true, // Her zaman gönder (null veya tarih)
          );
      
      debugPrint(
        "═══════════════════════════════════════════════════════════════════════════════════════════",
      );
      debugPrint("✅ Frontend - updateCustomer TAMAMLANDI (await sonrası)");
      debugPrint(
        "═══════════════════════════════════════════════════════════════════════════════════════════",
      );

      // Tüm filter type'lar için provider'ları refresh et
      // Böylece hangi sayfada olursa olsun müşteri listesi otomatik güncellenir
      // Mevcut filtreleri koruyarak refresh et (showLoading=false)
      try {
        ref.read(customerListProvider.notifier).refresh(showLoading: false);
      } catch (e) {
        // Provider henüz initialize edilmemiş olabilir, hata yok say
      }

      // Tüm filter type'lar için ayrı ayrı refresh et
      for (final filterType in [
        CustomerFilterType.all,
        CustomerFilterType.overduePayment,
        CustomerFilterType.upcomingMaintenance,
        CustomerFilterType.overdueInstallment,
      ]) {
        try {
          final filterTypeKey = filterType.toString();
          final notifier = ref.read(
            customerListProviderForFilter(filterTypeKey).notifier,
          );
          // Mevcut filtreleri koruyarak refresh et (showLoading=false)
          notifier.refresh(showLoading: false);
        } catch (e) {
          // Provider henüz initialize edilmemiş olabilir, hata yok say
        }
      }

      // Invalidate customer detail provider to refresh the detail page
      ref.invalidate(customerDetailProvider(widget.customer.id));
      // Also refresh to ensure immediate update
      await ref.read(customerDetailProvider(widget.customer.id).future);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Müşteri güncellendi")));
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
            _currentLocation = LatLng(position.latitude, position.longitude);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: "Geri",
        ),
        title: const Text("Müşteri Düzenle"),
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
                // Kayıt Bilgileri
                Text(
                  "Kayıt Bilgileri",
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  readOnly: true,
                  controller: TextEditingController(
                    text: _createdAt != null
                        ? DateFormat("dd.MM.yyyy").format(_createdAt!)
                        : "",
                  ),
                  decoration: InputDecoration(
                    labelText: "Kayıt Tarihi",
                    hintText: "Tarih seçin",
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _createdAt ?? DateTime.now(),
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
                // Bakım Bilgileri
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                Text(
                  "Bakım Bilgileri",
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                // Son bakım tarihi
                TextFormField(
                  readOnly: true,
                  controller: TextEditingController(
                    text: DateFormat("dd.MM.yyyy").format(_lastMaintenanceDate),
                  ),
                  decoration: InputDecoration(
                    labelText: "Son bakım tarihi",
                    hintText: "Tarih seçin",
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _lastMaintenanceDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setState(() {
                            _lastMaintenanceDate = picked;
                            _maintenanceDateChanged =
                                true; // Kullanıcı tarihi değiştirdi
                          });
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Sonraki Bakım Tarihi Slider
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Sonraki Bakım Tarihi ?",
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        Text(
                          "${_nextMaintenanceMonths.toInt()} ay",
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF2563EB),
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Slider(
                      value: _nextMaintenanceMonths,
                      min: 0,
                      max: 12,
                      divisions: 12,
                      label: "${_nextMaintenanceMonths.toInt()} ay",
                      onChanged: (value) {
                        setState(() {
                          _nextMaintenanceMonths = value;
                          _maintenanceDateChanged =
                              true; // Kullanıcı slider'ı değiştirdi
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Bakım Zamanı (Hesaplanan)
                TextFormField(
                  readOnly: true,
                  controller: TextEditingController(
                    text: DateFormat("dd.MM.yyyy").format(
                      _lastMaintenanceDate.add(
                        Duration(days: (_nextMaintenanceMonths * 30).toInt()),
                      ),
                    ),
                  ),
                  decoration: InputDecoration(
                    labelText: "Bakım Zamanı",
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
                const SizedBox(height: 24),
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
                        : const Text("Güncelle"),
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
