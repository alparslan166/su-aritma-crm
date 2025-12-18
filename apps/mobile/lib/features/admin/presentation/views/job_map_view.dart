import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_map/flutter_map.dart";
import "package:geocoding/geocoding.dart";
import "package:geolocator/geolocator.dart";
import "package:go_router/go_router.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:intl/intl.dart";
import "package:latlong2/latlong.dart";
import "package:mobile/core/constants/app_config.dart";
import "package:mobile/widgets/admin_app_bar.dart";
import "package:mobile/widgets/empty_state.dart";

import "../../application/customer_list_notifier.dart";
import "../../application/personnel_list_notifier.dart";
import "../../data/admin_repository.dart";
import "../../data/models/customer.dart";
import "../../data/models/personnel.dart";

class JobMapView extends ConsumerStatefulWidget {
  const JobMapView({
    super.key,
    this.initialCustomerLocation,
    this.initialCustomerId,
  });

  final LatLng? initialCustomerLocation;
  final String? initialCustomerId;

  @override
  ConsumerState<JobMapView> createState() => _JobMapViewState();
}

enum MapFilter { all, customersOnly, personnelOnly }

class _JobMapViewState extends ConsumerState<JobMapView> {
  final MapController _mapController = MapController();
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  final Map<String, LatLng> _resolvedLocations = {};
  final Set<String> _loadingLocations = {};
  final Map<String, String> _locationErrors = {};
  bool _initialized = false;
  MapFilter _filter = MapFilter.all;
  String? _highlightedCustomerId; // Popup gösterilecek müşteri ID'si
  bool _isSheetExpanded = false; // Sheet'in açık/kapalı durumu
  bool _isToggling = false; // Toggle işlemi devam ediyor mu?
  LatLng? _userLocation; // Kullanıcının konumu

  @override
  void initState() {
    super.initState();
    // Kullanıcının konumunu al
    _getUserLocation();
    // Initialize customer and personnel lists when map view is opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Future.wait([
          ref.read(customerListProvider.notifier).refresh(showLoading: true),
          ref.read(personnelListProvider.notifier).refresh(),
        ]).then((_) {
          if (mounted) {
            setState(() {
              _initialized = true;
            });
          }
        });
      }
    });
  }

  Future<void> _getUserLocation() async {
    try {
      // Konum izni kontrolü
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return; // Konum servisleri kapalı, sessizce devam et
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return; // İzin reddedildi, sessizce devam et
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return; // İzin kalıcı olarak reddedilmiş, sessizce devam et
      }

      // Mevcut konumu al - yüksek doğruluk kullan
      final position =
          await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high, // medium yerine high kullan
          ).timeout(
            const Duration(seconds: 10), // timeout süresini artır
            onTimeout: () {
              throw TimeoutException("Konum alınamadı");
            },
          );

      if (mounted) {
        final newLocation = LatLng(position.latitude, position.longitude);
        setState(() {
          _userLocation = newLocation;
        });
        // Kullanıcı konumu alındığında haritayı oraya taşı
        // (eğer initialCustomerLocation yoksa ve marker yoksa)
        if (widget.initialCustomerLocation == null && _initialized) {
          try {
            _mapController.move(newLocation, 12.0);
          } catch (e) {
            debugPrint("Harita taşınamadı: $e");
          }
        }
      }
    } catch (e) {
      debugPrint("Kullanıcı konumu alınamadı: $e");
      // Hata durumunda sessizce devam et, varsayılan konum kullanılacak
    }
  }

  void _toggleSheet() {
    if (!mounted || _isToggling) return;

    debugPrint("🔄 Toggle sheet called. Current expanded: $_isSheetExpanded");

    // Toggle flag'ini aktif et
    setState(() {
      _isToggling = true;
      // State'i hemen güncelle (buton ikonu için)
      // İçerik opacity ile kontrol edildiği için kaybolmaz
      _isSheetExpanded = !_isSheetExpanded;
    });

    // Mevcut durumu kontrol et
    final shouldExpand = _isSheetExpanded;

    // Controller attach olana kadar bekle
    void _animateSheet([int retryCount = 0]) {
      if (!mounted) {
        setState(() {
          _isToggling = false;
        });
        return;
      }

      // Maksimum 10 deneme (yaklaşık 500ms)
      if (retryCount > 10) {
        debugPrint("⚠️ Sheet controller attach timeout");
        if (mounted) {
          setState(() {
            _isToggling = false;
          });
        }
        return;
      }

      if (!_sheetController.isAttached) {
        // Controller henüz hazır değil, kısa bir süre bekle ve tekrar dene
        Future.delayed(const Duration(milliseconds: 50), () {
          if (mounted) {
            _animateSheet(retryCount + 1);
          } else {
            setState(() {
              _isToggling = false;
            });
          }
        });
        return;
      }

      // Controller'ı animate et
      try {
        if (shouldExpand) {
          // Yarıya kadar aç
          debugPrint("📂 Opening sheet to 0.5");
          _sheetController
              .animateTo(
                0.5,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              )
              .then((_) {
                // Animasyon bittiğinde toggle flag'ini kaldır
                if (mounted) {
                  setState(() {
                    _isToggling = false;
                  });
                }
              });
        } else {
          // Tamamen kapat (sadece buton gözüksün)
          debugPrint("📁 Closing sheet to 0.1");
          _sheetController
              .animateTo(
                0.1, // minChildSize
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              )
              .then((_) {
                // Animasyon bittiğinde toggle flag'ini kaldır
                if (mounted) {
                  setState(() {
                    _isToggling = false;
                  });
                }
              });
        }
      } catch (e) {
        debugPrint("❌ Toggle sheet error: $e");
        if (mounted) {
          setState(() {
            _isToggling = false;
          });
        }
      }
    }

    // Animasyonu başlat
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _animateSheet();
      } else {
        setState(() {
          _isToggling = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _sheetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customerState = ref.watch(customerListProvider);
    final personnelState = ref.watch(personnelListProvider);

    // Handle loading state - show loading indicator if not initialized yet
    if (!_initialized || customerState.isLoading || personnelState.isLoading) {
      return Scaffold(
        appBar: const AdminAppBar(title: Text("Harita")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Use valueOrNull to safely handle error states
    final customers = customerState.valueOrNull ?? [];
    final personnel = personnelState.valueOrNull ?? [];

    // Debug: Log to see what we're getting
    if (customers.isNotEmpty) {
      final withLocation = customers.where((c) => c.location != null).length;
      debugPrint(
        "🗺️ Customers with location: $withLocation/${customers.length}",
      );
      // Debug: Log first few customers' location data
      for (final customer in customers.take(3)) {
        debugPrint(
          "  - ${customer.name}: location=${customer.location?.latitude},${customer.location?.longitude}",
        );
      }
    }

    // Resolve locations for customers without location
    for (final customer in customers) {
      if (customer.location == null &&
          !_resolvedLocations.containsKey(customer.id) &&
          !_loadingLocations.contains(customer.id) &&
          !_locationErrors.containsKey(customer.id)) {
        _resolveCustomerLocation(customer);
      }
    }

    // Get all customers with location (either from backend or resolved)
    final customersWithLocation = customers.where((c) {
      return c.location != null || _resolvedLocations.containsKey(c.id);
    }).toList();

    // Get all personnel with location
    final personnelWithLocation = personnel
        .where((p) => p.canShareLocation && p.lastKnownLocation != null)
        .toList();

    // Apply filter
    final showCustomers = _filter != MapFilter.personnelOnly;
    final showPersonnel = _filter != MapFilter.customersOnly;

    final visibleCustomers = showCustomers
        ? customersWithLocation
        : <Customer>[];
    final visiblePersonnel = showPersonnel
        ? personnelWithLocation
        : <Personnel>[];

    final markers = <Marker>[
      ...visibleCustomers.map((customer) {
        final location = customer.location != null
            ? LatLng(customer.location!.latitude, customer.location!.longitude)
            : _resolvedLocations[customer.id];
        if (location == null) return null;
        return _customerMarker(
          context,
          customer,
          location,
          () => _showCustomerInfoSheet(context, customer),
          isHighlighted: _highlightedCustomerId == customer.id,
        );
      }).whereType<Marker>(),
      ...visiblePersonnel.map((person) {
        final location = person.lastKnownLocation!;
        return _personnelMarker(
          context,
          person,
          LatLng(location.lat, location.lng),
          () => _showPersonnelInfoSheet(context, person),
        );
      }),
    ];

    // Always show map with default center (user location or Istanbul) if no data
    final center = _initialCenter(
      visibleCustomers,
      visiblePersonnel,
      _userLocation,
    );

    return Scaffold(
      appBar: const AdminAppBar(title: Text("Harita")),
      body: Stack(
        children: [
          // Harita tam ekran
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: markers.isEmpty ? 10.0 : 11.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              onMapReady: () {
                // Center map on data when ready
                if (widget.initialCustomerLocation != null) {
                  // If initial location is provided, zoom to that location
                  Future.delayed(const Duration(milliseconds: 300), () {
                    _mapController.move(
                      widget.initialCustomerLocation!,
                      15.0, // Higher zoom for customer detail
                    );
                  });
                } else if (markers.isNotEmpty) {
                  Future.delayed(const Duration(milliseconds: 300), () {
                    final target = _initialCenter(
                      visibleCustomers,
                      visiblePersonnel,
                      _userLocation,
                    );
                    _mapController.move(target, 11.0);
                  });
                } else if (_userLocation != null) {
                  // Kullanıcı konumu varsa ama marker yoksa, kullanıcı konumuna odaklan
                  Future.delayed(const Duration(milliseconds: 300), () {
                    _mapController.move(_userLocation!, 12.0);
                  });
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                userAgentPackageName: "com.suaritma.app",
                maxZoom: 19,
                minZoom: 3,
              ),
              if (markers.isNotEmpty) MarkerLayer(markers: markers),
            ],
          ),
          // Error messages overlay
          if (customerState.hasError)
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Colors.red.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Müşteri konumları alınamadı",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Center button
          Positioned(
            top: 12,
            right: 12,
            child: FloatingActionButton.small(
              heroTag: "map-center-btn",
              onPressed: () {
                final target = _initialCenter(
                  visibleCustomers,
                  visiblePersonnel,
                  _userLocation,
                );
                final zoom = markers.isEmpty
                    ? (_userLocation != null ? 12.0 : 10.0)
                    : _mapController.camera.zoom;
                _mapController.move(target, zoom);
              },
              child: const Icon(Icons.my_location),
            ),
          ),
          // Draggable bottom sheet
          DraggableScrollableSheet(
            controller: _sheetController,
            initialChildSize: 0.1, // Başlangıçta kapalı (sadece buton)
            minChildSize: 0.1,
            maxChildSize: 0.9,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Ok butonu - aç/kapat toggle
                    // Tıklanabilir alanı genişletmek için behavior ve daha fazla padding
                    GestureDetector(
                      onTap: _toggleSheet,
                      behavior:
                          HitTestBehavior.opaque, // Tüm alanı tıklanabilir yap
                      child: Container(
                        width: double.infinity, // Tam genişlik
                        padding: const EdgeInsets.symmetric(
                          vertical: 20, // Daha fazla dikey padding
                          horizontal: 16,
                        ),
                        child: Center(
                          child: Icon(
                            _isSheetExpanded
                                ? Icons.keyboard_arrow_down
                                : Icons.keyboard_arrow_up,
                            color: Colors.grey.shade700,
                            size: 32,
                          ),
                        ),
                      ),
                    ),
                    // Filter buttons - sadece sheet açıkken göster
                    if (_isSheetExpanded) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilterChip(
                              label: const Text("Sadece Müşteriler"),
                              selected: _filter == MapFilter.customersOnly,
                              onSelected: (_) {
                                setState(() {
                                  _filter = _filter == MapFilter.customersOnly
                                      ? MapFilter.all
                                      : MapFilter.customersOnly;
                                });
                              },
                            ),
                            FilterChip(
                              label: const Text("Sadece Personeller"),
                              selected: _filter == MapFilter.personnelOnly,
                              onSelected: (_) {
                                setState(() {
                                  _filter = _filter == MapFilter.personnelOnly
                                      ? MapFilter.all
                                      : MapFilter.personnelOnly;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    // Scrollable content - Expanded Opacity dışında
                    Expanded(
                      child: Opacity(
                        opacity: _isSheetExpanded ? 1.0 : 0.0,
                        child: IgnorePointer(
                          ignoring: !_isSheetExpanded,
                          child: RefreshIndicator(
                            onRefresh: () async {
                              await Future.wait([
                                ref
                                    .read(customerListProvider.notifier)
                                    .refresh(),
                                ref
                                    .read(personnelListProvider.notifier)
                                    .refresh(),
                              ]);
                            },
                            child: ListView(
                              controller: scrollController,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              children: [
                                if (visibleCustomers.isEmpty &&
                                    visiblePersonnel.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 48),
                                    child: EmptyState(
                                      icon: Icons.map_outlined,
                                      title: "Henüz konum verisi yok",
                                      subtitle:
                                          "Müşteri veya personel konumları geldiğinde harita güncellenecek.",
                                    ),
                                  )
                                else ...[
                                  if (showCustomers &&
                                      visibleCustomers.isNotEmpty) ...[
                                    Text(
                                      "Müşteri Konumları",
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 8),
                                    ...visibleCustomers.map((customer) {
                                      // Müşteri durumuna göre renk belirleme
                                      final markerInfo = _getCustomerMarkerInfo(
                                        customer,
                                      );
                                      final markerColor = markerInfo.color;
                                      final statusText = markerInfo.statusText;

                                      return ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: Icon(
                                          Icons.location_on,
                                          color: markerColor,
                                        ),
                                        title: Text(customer.name),
                                        subtitle: Text(customer.address),
                                        trailing: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: markerColor.withValues(
                                              alpha: 0.1,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                            border: Border.all(
                                              color: markerColor,
                                            ),
                                          ),
                                          child: Text(
                                            statusText,
                                            style: TextStyle(
                                              color: markerColor,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        onTap: () =>
                                            _focusOnCustomerLocation(customer),
                                      );
                                    }),
                                    const SizedBox(height: 16),
                                  ],
                                  if (showPersonnel &&
                                      visiblePersonnel.isNotEmpty) ...[
                                    Text(
                                      "Personel Konumları",
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 8),
                                    ...visiblePersonnel.map((person) {
                                      final location =
                                          person.lastKnownLocation!;
                                      final subtitle =
                                          location.timestamp != null
                                          ? "Son konum: ${location.timestamp!.toLocal()}"
                                          : "Son konum zamanı bilinmiyor";
                                      return ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: const Icon(
                                          Icons.person_pin_circle,
                                          color: Color(0xFF2563EB),
                                        ),
                                        title: Text(person.name),
                                        subtitle: Text(subtitle),
                                        onTap: () =>
                                            _focusOnPersonnelLocation(person),
                                      );
                                    }),
                                  ],
                                ],
                                SizedBox(
                                  height:
                                      MediaQuery.of(context).padding.bottom +
                                      16,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _resolveCustomerLocation(Customer customer) async {
    if (_loadingLocations.contains(customer.id)) return;
    _loadingLocations.add(customer.id);

    try {
      // Note: CustomerJob model doesn't have location data,
      // so we'll use geocoding first, then fallback to fetching jobs

      // Try geocoding from address (faster than fetching all jobs)
      if (customer.address.isNotEmpty) {
        try {
          final locations = await locationFromAddress(customer.address);
          if (locations.isNotEmpty && mounted) {
            setState(() {
              _resolvedLocations[customer.id] = LatLng(
                locations.first.latitude,
                locations.first.longitude,
              );
              _loadingLocations.remove(customer.id);
            });
            return;
          }
        } catch (e) {
          debugPrint("Geocoding error for ${customer.name}: $e");
        }
      }

      // If geocoding fails, try to get location from jobs (as fallback)
      try {
        final jobs = await ref
            .read(adminRepositoryProvider)
            .fetchJobs(personnelId: null);
        final customerJobs =
            jobs
                .where(
                  (job) =>
                      job.customer.name == customer.name &&
                      job.customer.address == customer.address,
                )
                .where((job) => job.location != null)
                .toList()
              ..sort((a, b) {
                // Get most recent job
                final aDate = a.scheduledAt ?? a.createdAt;
                final bDate = b.scheduledAt ?? b.createdAt;
                if (aDate == null && bDate == null) return 0;
                if (aDate == null) return 1;
                if (bDate == null) return -1;
                return bDate.compareTo(aDate);
              });

        if (customerJobs.isNotEmpty && customerJobs.first.location != null) {
          final jobLocation = customerJobs.first.location!;
          if (mounted) {
            setState(() {
              _resolvedLocations[customer.id] = LatLng(
                jobLocation.latitude,
                jobLocation.longitude,
              );
              _loadingLocations.remove(customer.id);
            });
            return;
          }
        }
      } catch (e) {
        debugPrint("Error fetching jobs for ${customer.name}: $e");
      }

      // If all fails, mark as error
      if (mounted) {
        setState(() {
          _locationErrors[customer.id] = "Konum bulunamadı";
          _loadingLocations.remove(customer.id);
        });
      }
    } catch (e) {
      debugPrint("Error resolving location for ${customer.name}: $e");
      if (mounted) {
        setState(() {
          _locationErrors[customer.id] = "Konum yüklenemedi";
          _loadingLocations.remove(customer.id);
        });
      }
    }
  }

  void _openCustomerDetail(Customer customer) {
    context.pushNamed(
      "admin-customer-detail",
      pathParameters: {"id": customer.id},
      extra: customer,
    );
  }

  void _openPersonnelDetail(Personnel personnel) {
    context.pushNamed(
      "admin-personnel-detail",
      pathParameters: {"id": personnel.id},
      extra: personnel,
    );
  }

  void _focusOnCustomerLocation(Customer customer) {
    // Müşteri konumunu bul
    LatLng? location;
    if (customer.location != null) {
      location = LatLng(
        customer.location!.latitude,
        customer.location!.longitude,
      );
    } else if (_resolvedLocations.containsKey(customer.id)) {
      location = _resolvedLocations[customer.id];
    }

    if (location != null) {
      // Müşteri ismini göster
      setState(() {
        _highlightedCustomerId = customer.id;
      });

      // Haritayı müşteri konumuna odakla
      _mapController.move(location, 15.0);
      // Sheet'i küçült
      if (_sheetController.isAttached) {
        setState(() {
          _isSheetExpanded = false;
        });
        _sheetController.animateTo(
          0.1, // minChildSize
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }

      // 3 saniye sonra ismi kaldır
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _highlightedCustomerId == customer.id) {
          setState(() {
            _highlightedCustomerId = null;
          });
        }
      });
    }
  }

  void _focusOnPersonnelLocation(Personnel personnel) {
    // Personel konumunu bul
    final location = personnel.lastKnownLocation;
    if (location != null) {
      final latLng = LatLng(location.lat, location.lng);
      // Haritayı personel konumuna odakla
      _mapController.move(latLng, 15.0);
      // Sheet'i küçült
      if (_sheetController.isAttached) {
        setState(() {
          _isSheetExpanded = false;
        });
        _sheetController.animateTo(
          0.1, // minChildSize
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    }
  }

  void _showCustomerInfoSheet(BuildContext context, Customer customer) {
    // Müşteri durumuna göre renk belirleme
    final markerInfo = _getCustomerMarkerInfo(customer);
    final markerColor = markerInfo.color;
    final statusText = markerInfo.statusText;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black87,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person, size: 20, color: markerColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    customer.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (customer.address.isNotEmpty) ...[
              Text(
                customer.address,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: markerColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: markerColor),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: markerColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _openCustomerDetail(customer);
                  },
                  icon: const Icon(Icons.arrow_forward, color: Colors.white),
                  label: const Text(
                    "Detay",
                    style: TextStyle(color: Colors.white),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: markerColor,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showPersonnelInfoSheet(BuildContext context, Personnel person) {
    final location = person.lastKnownLocation!;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black87,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _PersonnelAvatar(
                  photoUrl: person.photoUrl,
                  name: person.name,
                  size: 40,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    person.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (location.timestamp != null) ...[
              Text(
                "Son konum: ${DateFormat("dd MMM yyyy HH:mm").format(location.timestamp!.toLocal())}",
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _openPersonnelDetail(person);
                  },
                  icon: const Icon(Icons.arrow_forward, color: Colors.white),
                  label: const Text(
                    "Detay",
                    style: TextStyle(color: Colors.white),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.secondary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

LatLng _initialCenter(
  List<Customer> customers,
  List<Personnel> personnel,
  LatLng? userLocation,
) {
  // Öncelik 1: Kullanıcının konumu
  if (userLocation != null) {
    return userLocation;
  }

  // Öncelik 2: Müşteri konumları
  if (customers.isNotEmpty) {
    final firstCustomer = customers.first;
    if (firstCustomer.location != null) {
      final location = firstCustomer.location!;
      return LatLng(location.latitude, location.longitude);
    }
  }

  // Öncelik 3: Personel konumları
  if (personnel.isNotEmpty && personnel.first.lastKnownLocation != null) {
    final loc = personnel.first.lastKnownLocation!;
    return LatLng(loc.lat, loc.lng);
  }

  // Son çare: Istanbul center - always show map even with no data
  return const LatLng(41.015137, 28.97953);
}

// Müşteri durumuna göre renk ve durum metni döndüren helper fonksiyon
({Color color, String statusText}) _getCustomerMarkerInfo(Customer customer) {
  // 1. Bakımı gelen → Turuncu (en yüksek öncelik)
  if (customer.hasUpcomingMaintenance) {
    return (color: Colors.orange, statusText: "Bakımı Gelen");
  }

  // 2. Mevcut iş olan (PENDING veya IN_PROGRESS) → Mavi
  final hasCurrentJob =
      customer.jobs?.any(
        (job) => job.status == "PENDING" || job.status == "IN_PROGRESS",
      ) ??
      false;
  if (hasCurrentJob) {
    return (color: Colors.blue, statusText: "Mevcut İş");
  }

  // 3. Aktif (status ACTIVE ve işleri var) → Yeşil
  if (customer.status == "ACTIVE" &&
      customer.jobs != null &&
      customer.jobs!.isNotEmpty) {
    return (color: Colors.green, statusText: "Aktif");
  }

  // 4. Pasif (diğer durumlar) → Gri
  return (color: Colors.grey, statusText: "Pasif");
}

Marker _customerMarker(
  BuildContext context,
  Customer customer,
  LatLng location,
  VoidCallback onTap, {
  bool isHighlighted = false,
}) {
  // Müşteri durumuna göre renk belirleme
  final markerInfo = _getCustomerMarkerInfo(customer);
  final markerColor = markerInfo.color;

  return Marker(
    point: location,
    width: isHighlighted ? 120 : 40,
    height: isHighlighted ? 60 : 40,
    child: Stack(
      alignment: Alignment.topCenter,
      children: [
        // İsim popup'ı (sadece highlight edildiğinde)
        if (isHighlighted)
          Positioned(
            top: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: Border.all(color: markerColor, width: 1.5),
              ),
              child: Text(
                customer.name,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: markerColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        // Marker ikonu
        Positioned(
          bottom: 0,
          child: GestureDetector(
            onTap: onTap,
            child: Icon(Icons.location_on, size: 32, color: markerColor),
          ),
        ),
      ],
    ),
  );
}

Marker _personnelMarker(
  BuildContext context,
  Personnel person,
  LatLng location,
  VoidCallback onTap,
) {
  return Marker(
    point: location,
    width: 40,
    height: 40,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: _PersonnelAvatar(
          photoUrl: person.photoUrl,
          name: person.name,
          size: 36,
        ),
      ),
    ),
  );
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
