import "dart:async";

import "package:flutter/foundation.dart";
import "package:geolocator/geolocator.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";

import "../core/session/session_provider.dart";
import "../features/personnel/data/personnel_repository.dart";

class LocationTrackingService {
  LocationTrackingService(this._repository);

  final PersonnelRepository _repository;
  Timer? _locationTimer;
  bool _isTracking = false;
  StreamSubscription<Position>? _positionStream;

  /// Start location tracking - sends location every 30 seconds
  Future<void> startTracking() async {
    if (_isTracking) {
      debugPrint("📍 Location tracking already started");
      return;
    }

    // Check if location sharing is enabled
    try {
      final profile = await _repository.fetchMyProfile();
      final canShareLocation = profile["canShareLocation"] as bool? ?? false;

      if (!canShareLocation) {
        debugPrint("📍 Location sharing is disabled, not starting tracking");
        return;
      }
    } catch (e) {
      debugPrint("⚠️ Failed to check location sharing permission: $e");
      return;
    }

    // Check location permissions
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint("⚠️ Location services are disabled");
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint("⚠️ Location permission denied");
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint("⚠️ Location permission denied forever");
      return;
    }

    _isTracking = true;
    debugPrint("📍 Starting location tracking...");

    // Send location immediately
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      _sendLocation(position.latitude, position.longitude);
    } catch (e) {
      debugPrint("⚠️ Failed to get initial location: $e");
    }

    // Use positionStream for continuous updates with background support
    _positionStream =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 0, // Update regardless of distance
          ),
        ).listen(
          (Position position) {
            _sendLocation(position.latitude, position.longitude);
          },
          onError: (error) {
            debugPrint("❌ Location stream error: $error");
          },
        );

    // Fallback timer - send location every 30 seconds even if stream doesn't update
    _locationTimer = Timer.periodic(
      const Duration(seconds: 30),
      (timer) async {
        if (!_isTracking) {
          timer.cancel();
          return;
        }

        try {
          final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 10),
          );
          _sendLocation(position.latitude, position.longitude);
        } catch (e) {
          debugPrint("⚠️ Failed to get location in timer: $e");
        }
      },
    );
  }

  /// Stop location tracking
  void stopTracking() {
    if (!_isTracking) {
      return;
    }

    debugPrint("📍 Stopping location tracking...");
    _isTracking = false;
    _locationTimer?.cancel();
    _locationTimer = null;
    _positionStream?.cancel();
    _positionStream = null;
  }

  /// Send location to backend
  Future<void> _sendLocation(double lat, double lng) async {
    try {
      await _repository.updateLocation(lat, lng);
      debugPrint("📍 Location sent: $lat, $lng");
    } catch (e) {
      debugPrint("❌ Failed to send location: $e");
    }
  }

  /// Check if tracking is active
  bool get isTracking => _isTracking;

  void dispose() {
    stopTracking();
  }
}

// Riverpod provider for location tracking service
final locationTrackingServiceProvider = Provider<LocationTrackingService?>((
  ref,
) {
  final session = ref.watch(authSessionProvider);

  // Only create service for personnel
  if (session == null || session.role.name != "personnel") {
    return null;
  }

  final repository = ref.read(personnelRepositoryProvider);
  final service = LocationTrackingService(repository);

  // Auto-dispose when provider is disposed
  ref.onDispose(() {
    service.dispose();
  });

  return service;
});
