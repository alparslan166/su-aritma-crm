import "dart:async";
import "dart:math" as math;

import "package:flutter/material.dart";
import "package:flutter_map/flutter_map.dart";
import "package:geolocator/geolocator.dart";
import "package:latlong2/latlong.dart";

class InteractiveLocationPicker extends StatefulWidget {
  const InteractiveLocationPicker({
    super.key,
    required this.initialLocation,
    required this.onLocationSelected,
  });

  final LatLng initialLocation;
  final Function(LatLng) onLocationSelected;

  @override
  State<InteractiveLocationPicker> createState() =>
      _InteractiveLocationPickerState();
}

enum MapViewType { map, satellite }

class _InteractiveLocationPickerState extends State<InteractiveLocationPicker>
    with TickerProviderStateMixin {
  late MapController _mapController;
  late LatLng _selectedLocation;
  MapViewType _viewType = MapViewType.map;
  final GlobalKey _mapKey = GlobalKey();
  bool _isDragging = false;
  Offset? _markerScreenPosition;
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;
  bool _hasInitializedLocation = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _selectedLocation = widget.initialLocation;

    // Initialize bounce animation
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _bounceAnimation = Tween<double>(begin: 0.0, end: 15.0).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
    );

    // Listen to map camera changes to update marker position
    _mapController.mapEventStream.listen((event) {
      if (mounted) {
        _updateMarkerScreenPosition();
      }
    });
  }

  void _updateMarkerScreenPosition() {
    try {
      final point = _mapController.camera.latLngToScreenPoint(
        _selectedLocation,
      );
      setState(() {
        // Görselin tam ortası konum olacak şekilde ayarla
        // Marker icon 50px yüksekliğinde, görsel 60px
        // Görselin merkezi marker konumuna gelecek
        _markerScreenPosition = Offset(point.x, point.y);
      });
    } catch (e) {
      // Ignore errors
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Update marker position after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateMarkerScreenPosition();
    });
    // Get user's current location when map first opens
    if (!_hasInitializedLocation) {
      _hasInitializedLocation = true;
      _initializeWithCurrentLocation();
    }
  }

  Future<void> _initializeWithCurrentLocation() async {
    try {
      // Check location permissions
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // If location services are disabled, use initialLocation
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          // If permission denied, use initialLocation
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        // If permission denied forever, use initialLocation
        return;
      }

      // Get current location
      final position =
          await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
          ).timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              throw TimeoutException("Konum alınamadı");
            },
          );

      final currentLocation = LatLng(position.latitude, position.longitude);

      if (!mounted) return;

      // Move map to current location
      _mapController.move(currentLocation, _mapController.camera.zoom);

      // Update selected location to current location
      setState(() {
        _selectedLocation = currentLocation;
      });

      // Update marker screen position
      _updateMarkerScreenPosition();
    } catch (e) {
      // If any error occurs, silently use initialLocation
      // No need to show error message on initialization
    }
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _zoomIn() {
    _mapController.move(
      _mapController.camera.center,
      _mapController.camera.zoom + 1,
    );
  }

  void _zoomOut() {
    _mapController.move(
      _mapController.camera.center,
      _mapController.camera.zoom - 1,
    );
  }

  Future<void> _goToCurrentLocation() async {
    try {
      // Check location permissions
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

      // Get current location
      final position =
          await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
          ).timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw TimeoutException("Konum alınamadı");
            },
          );

      final currentLocation = LatLng(position.latitude, position.longitude);

      // Move map to current location
      _mapController.move(currentLocation, _mapController.camera.zoom);

      // Update selected location to current location
      setState(() {
        _selectedLocation = currentLocation;
      });

      // Update marker screen position
      _updateMarkerScreenPosition();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Mevcut konuma gidildi"),
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Konum alınamadı: $e"),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    if (!_isDragging) {
      setState(() {
        _selectedLocation = point;
      });
      _updateMarkerScreenPosition();
    }
  }

  void _onMarkerPanUpdate(DragUpdateDetails details) {
    final RenderBox? renderBox =
        _mapKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    // Get the local position relative to the map
    final localPosition = renderBox.globalToLocal(details.globalPosition);
    final camera = _mapController.camera;
    final mapSize = renderBox.size;

    // Calculate the offset from center
    final centerX = mapSize.width / 2;
    final centerY = mapSize.height / 2;

    final offsetX = localPosition.dx - centerX;
    final offsetY = localPosition.dy - centerY;

    // Convert pixel offset to lat/lng offset
    // Using Web Mercator projection approximation
    final zoom = camera.zoom;
    final latRad = camera.center.latitude * math.pi / 180;
    final metersPerPixel = 156543.03392 * math.cos(latRad) / math.pow(2, zoom);

    final latOffset = offsetY * metersPerPixel / 111320.0;
    final lngOffset = offsetX * metersPerPixel / (111320.0 * math.cos(latRad));

    setState(() {
      _selectedLocation = LatLng(
        camera.center.latitude - latOffset,
        camera.center.longitude + lngOffset,
      );
      _markerScreenPosition = localPosition;
    });
  }

  void _onMarkerPanStart(DragStartDetails details) {
    setState(() {
      _isDragging = true;
    });
    // Pause animation while dragging
    _bounceController.stop();
  }

  void _onMarkerPanEnd(DragEndDetails details) {
    setState(() {
      _isDragging = false;
    });
    // Resume animation after drag ends
    _bounceController.repeat(reverse: true);
    // Update marker screen position after drag ends
    _updateMarkerScreenPosition();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Top bar with coordinates and map pin icon
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Text(
                  "${_selectedLocation.latitude.toStringAsFixed(6)}, ${_selectedLocation.longitude.toStringAsFixed(6)}",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade800,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Icon(Icons.place, color: Colors.grey.shade700, size: 20),
              ],
            ),
          ),
          // Map/Satellite toggle
          Container(
            padding: const EdgeInsets.all(8),
            child: SegmentedButton<MapViewType>(
              segments: const [
                ButtonSegment(value: MapViewType.map, label: Text("Map")),
                ButtonSegment(
                  value: MapViewType.satellite,
                  label: Text("Satellite"),
                ),
              ],
              selected: {_viewType},
              onSelectionChanged: (Set<MapViewType> newSelection) {
                if (newSelection.isNotEmpty) {
                  setState(() {
                    _viewType = newSelection.first;
                  });
                }
              },
            ),
          ),
          // Map
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  key: _mapKey,
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _selectedLocation,
                    initialZoom: 15.0,
                    onTap: _onMapTap,
                    interactionOptions: InteractionOptions(
                      flags: _isDragging
                          ? InteractiveFlag.none
                          : InteractiveFlag.all & ~InteractiveFlag.rotate,
                    ),
                  ),
                  children: [
                    // Tile layer based on view type
                    TileLayer(
                      urlTemplate: _viewType == MapViewType.map
                          ? "https://tile.openstreetmap.org/{z}/{x}/{y}.png"
                          : "https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}",
                      userAgentPackageName: "com.suaritma.app",
                      maxZoom: 19,
                      minZoom: 3,
                    ),
                  ],
                ),
                // Draggable marker overlay with bounce animation
                if (_markerScreenPosition != null)
                  Positioned(
                    // Görselin tam ortası konum olacak şekilde ayarla
                    // Marker icon 50px, görsel 40px
                    // Görselin merkezi _markerScreenPosition'a gelecek
                    left:
                        _markerScreenPosition!.dx -
                        20, // Görselin yarı genişliği (40/2)
                    top:
                        _markerScreenPosition!.dy -
                        50 -
                        20, // Marker yüksekliği (50) + görselin yarı yüksekliği (40/2)
                    child: GestureDetector(
                      onPanStart: _onMarkerPanStart,
                      onPanUpdate: _onMarkerPanUpdate,
                      onPanEnd: _onMarkerPanEnd,
                      child: AnimatedBuilder(
                        animation: _bounceAnimation,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(0, -_bounceAnimation.value),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Marker icon
                                const Icon(
                                  Icons.place,
                                  color: Colors.red,
                                  size: 50,
                                ),
                                // Crosshair image - tam ortası konum olacak
                                // Görselin merkezi marker konumuna hizalanacak
                                Transform.translate(
                                  offset: const Offset(
                                    0,
                                    -20,
                                  ), // Görselin yarı yüksekliği kadar yukarı (40/2)
                                  child: Image.asset(
                                    "assets/images/crosshair.png",
                                    width: 40,
                                    height: 40,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                // My location button (right top)
                Positioned(
                  right: 16,
                  top: 16,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _goToCurrentLocation,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.my_location,
                            color: Color(0xFF2563EB),
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Zoom controls (left bottom)
                Positioned(
                  left: 16,
                  bottom: 16,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _zoomIn,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(8),
                            ),
                            child: Container(
                              width: 40,
                              height: 40,
                              alignment: Alignment.center,
                              child: const Icon(Icons.add, size: 20),
                            ),
                          ),
                        ),
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: Colors.grey.shade300,
                        ),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _zoomOut,
                            borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(8),
                            ),
                            child: Container(
                              width: 40,
                              height: 40,
                              alignment: Alignment.center,
                              child: const Icon(Icons.remove, size: 20),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Bottom button bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text("İptal"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      widget.onLocationSelected(_selectedLocation);
                      // Callback zaten Navigator.pop() çağırıyor, burada tekrar çağırmaya gerek yok
                    },
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: const Color(0xFF2563EB),
                    ),
                    child: const Text("Seç"),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
