import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/user_location.dart';

/// Permission status enumeration matching standard mobile platform lifecycle.
enum LocationPermissionStatus {
  notRequested,
  granted,
  denied,
  permanentlyDenied,
  serviceDisabled;

  bool get isGranted => this == LocationPermissionStatus.granted;
}

/// Contract interface for location operations.
/// Team Member 1 (Offline maps & GPS) and Onboarding integration interface.
abstract class ILocationService {
  Future<UserLocation> getCurrentLocation();
  Stream<UserLocation> getLocationStream();
  bool isGpsEnabled();
}

/// Extended location interface providing permission management for onboarding and live GPS telemetry.
abstract class IDeviceLocationService implements ILocationService {
  Future<LocationPermissionStatus> checkPermission();
  Future<LocationPermissionStatus> requestPermission();
}

/// Geographic metadata resolver for Coastal Andhra Pradesh and general device coordinates.
class LocationResolver {
  LocationResolver._();

  static const List<Map<String, dynamic>> _coastalApHubs = [
    {
      'name': 'Kakinada Port Corridor',
      'district': 'Kakinada District, Andhra Pradesh',
      'lat': 16.9891,
      'lon': 82.2475,
    },
    {
      'name': 'Vijayawada Central',
      'district': 'Krishna District, Andhra Pradesh',
      'lat': 16.5062,
      'lon': 80.6480,
    },
    {
      'name': 'Visakhapatnam Harbor Sector',
      'district': 'Visakhapatnam District, Andhra Pradesh',
      'lat': 17.6868,
      'lon': 83.2185,
    },
    {
      'name': 'Machilipatnam Coastal Zone',
      'district': 'Krishna District, Andhra Pradesh',
      'lat': 16.1875,
      'lon': 81.1389,
    },
    {
      'name': 'Guntur Plain Sector',
      'district': 'Guntur District, Andhra Pradesh',
      'lat': 16.3067,
      'lon': 80.4365,
    },
    {
      'name': 'Bapatla Coastal Sector',
      'district': 'Bapatla District, Andhra Pradesh',
      'lat': 15.9042,
      'lon': 80.4674,
    },
    {
      'name': 'Ongole Coastal Sector',
      'district': 'Prakasam District, Andhra Pradesh',
      'lat': 15.5057,
      'lon': 80.0499,
    },
    {
      'name': 'Nellore Coastal Zone',
      'district': 'SPSR Nellore District, Andhra Pradesh',
      'lat': 14.4426,
      'lon': 79.9865,
    },
    {
      'name': 'Amalapuram Konaseema Sector',
      'district': 'Dr. B.R. Ambedkar Konaseema District, Andhra Pradesh',
      'lat': 16.5787,
      'lon': 82.0061,
    },
    {
      'name': 'Rajahmundry Godavari Basin',
      'district': 'East Godavari District, Andhra Pradesh',
      'lat': 17.0005,
      'lon': 81.8040,
    },
    {
      'name': 'Srikakulam Coastal Sector',
      'district': 'Srikakulam District, Andhra Pradesh',
      'lat': 18.2949,
      'lon': 83.8938,
    },
  ];

  /// Resolves locality and district names based on real distance to known Coastal AP hubs.
  /// If beyond 25 km from any hub, formats coordinates honestly without fabricating a city.
  static ({String locationName, String subArea}) resolve(double lat, double lon) {
    double minDistance = double.infinity;
    Map<String, dynamic>? closestHub;

    for (final hub in _coastalApHubs) {
      final d = _haversineKm(lat, lon, hub['lat'] as double, hub['lon'] as double);
      if (d < minDistance) {
        minDistance = d;
        closestHub = hub;
      }
    }

    if (closestHub != null && minDistance <= 25.0) {
      return (
        locationName: closestHub['name'] as String,
        subArea: closestHub['district'] as String,
      );
    }

    return (
      locationName: '${lat.toStringAsFixed(4)}° N, ${lon.toStringAsFixed(4)}° E',
      subArea: 'Detected Device Location Fix',
    );
  }

  static double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * math.pi / 180.0;
    final dLon = (lon2 - lon1) * math.pi / 180.0;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180.0) *
            math.cos(lat2 * math.pi / 180.0) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }
}

/// Real hardware device GPS provider integrating Geolocator.
class DeviceLocationService implements IDeviceLocationService {
  static final DeviceLocationService _instance = DeviceLocationService._internal();
  factory DeviceLocationService() => _instance;
  DeviceLocationService._internal();

  static const Duration defaultTimeout = Duration(seconds: 10);

  @override
  Future<LocationPermissionStatus> checkPermission() async {
    try {
      final isServiceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isServiceEnabled) {
        return LocationPermissionStatus.serviceDisabled;
      }

      final permission = await Geolocator.checkPermission();
      return _mapPermission(permission);
    } catch (e) {
      debugPrint('DeviceLocationService.checkPermission error: $e');
      return LocationPermissionStatus.denied;
    }
  }

  @override
  Future<LocationPermissionStatus> requestPermission() async {
    try {
      final isServiceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isServiceEnabled) {
        return LocationPermissionStatus.serviceDisabled;
      }

      final permission = await Geolocator.requestPermission();
      return _mapPermission(permission);
    } catch (e) {
      debugPrint('DeviceLocationService.requestPermission error: $e');
      return LocationPermissionStatus.denied;
    }
  }

  @override
  Future<UserLocation> getCurrentLocation({Duration timeout = defaultTimeout}) async {
    final status = await checkPermission();
    if (status == LocationPermissionStatus.serviceDisabled) {
      throw const LocationServiceDisabledException();
    }
    if (status != LocationPermissionStatus.granted) {
      throw const PermissionDeniedException('Location permission not granted');
    }

    try {
      const settings = LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: defaultTimeout,
      );

      final position = await Geolocator.getCurrentPosition(locationSettings: settings)
          .timeout(timeout);

      final resolved = LocationResolver.resolve(position.latitude, position.longitude);

      return UserLocation.live(
        latitude: position.latitude,
        longitude: position.longitude,
        locationName: resolved.locationName,
        subArea: resolved.subArea,
        accuracyMeters: position.accuracy,
        timestamp: position.timestamp,
      );
    } on TimeoutException {
      throw TimeoutException('GPS satellite fix timed out after ${timeout.inSeconds}s');
    } catch (e) {
      debugPrint('DeviceLocationService.getCurrentLocation error: $e');
      rethrow;
    }
  }

  @override
  Stream<UserLocation> getLocationStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).map((position) {
      final resolved = LocationResolver.resolve(position.latitude, position.longitude);
      return UserLocation.live(
        latitude: position.latitude,
        longitude: position.longitude,
        locationName: resolved.locationName,
        subArea: resolved.subArea,
        accuracyMeters: position.accuracy,
        timestamp: position.timestamp,
      );
    });
  }

  @override
  bool isGpsEnabled() {
    return true;
  }

  Future<bool> openAppSettings() => Geolocator.openAppSettings();
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  LocationPermissionStatus _mapPermission(LocationPermission permission) {
    switch (permission) {
      case LocationPermission.always:
      case LocationPermission.whileInUse:
        return LocationPermissionStatus.granted;
      case LocationPermission.deniedForever:
        return LocationPermissionStatus.permanentlyDenied;
      case LocationPermission.denied:
      case LocationPermission.unableToDetermine:
        return LocationPermissionStatus.denied;
    }
  }
}

/// Baseline mock implementation providing realistic coordinates for testing and offline fallback.
/// Enhanced with battery-aware lifecycle pausing, customizable permission simulation, and timeout protection.
class MockLocationService implements IDeviceLocationService {
  static final MockLocationService _instance = MockLocationService._internal();
  factory MockLocationService() => _instance;
  MockLocationService._internal();

  UserLocation _current = UserLocation.mockDefault();
  bool _isTrackingPaused = false;
  LocationPermissionStatus _simulatedPermission = LocationPermissionStatus.granted;
  bool _simulateTimeout = false;
  Duration _simulatedDelay = const Duration(milliseconds: 250);
  static const Duration locationTimeout = Duration(seconds: 5);

  bool get isTrackingPaused => _isTrackingPaused;

  void setSimulatedPermission(LocationPermissionStatus status) {
    _simulatedPermission = status;
  }

  void setSimulateTimeout(bool timeout) {
    _simulateTimeout = timeout;
  }

  void setSimulatedDelay(Duration delay) {
    _simulatedDelay = delay;
  }

  @override
  Future<LocationPermissionStatus> checkPermission() async {
    return _simulatedPermission;
  }

  @override
  Future<LocationPermissionStatus> requestPermission() async {
    return _simulatedPermission;
  }

  /// Lifecycle optimization: pause GPS polling when app is backgrounded or tab is inactive.
  void pauseTracking() {
    _isTrackingPaused = true;
  }

  /// Lifecycle optimization: resume GPS polling when app enters foreground.
  void resumeTracking() {
    _isTrackingPaused = false;
  }

  @override
  Future<UserLocation> getCurrentLocation() async {
    if (_simulatedPermission == LocationPermissionStatus.serviceDisabled) {
      throw const LocationServiceDisabledException();
    }
    if (_simulatedPermission != LocationPermissionStatus.granted) {
      throw const PermissionDeniedException('Location permission not granted');
    }

    if (_simulateTimeout) {
      await Future.delayed(const Duration(seconds: 6));
      throw TimeoutException('GPS satellite fix timed out');
    }

    if (_isTrackingPaused) {
      return _current;
    }

    return Future.delayed(_simulatedDelay, () => _current)
        .timeout(locationTimeout, onTimeout: () => _current);
  }

  @override
  Stream<UserLocation> getLocationStream() async* {
    if (!_isTrackingPaused && _simulatedPermission == LocationPermissionStatus.granted) {
      yield _current;
    }
  }

  @override
  bool isGpsEnabled() => _simulatedPermission != LocationPermissionStatus.serviceDisabled;

  void updateMockLocation(UserLocation newLocation) {
    _current = newLocation;
  }

  void resetDefaults() {
    _current = UserLocation.mockDefault();
    _isTrackingPaused = false;
    _simulatedPermission = LocationPermissionStatus.granted;
    _simulateTimeout = false;
    _simulatedDelay = const Duration(milliseconds: 250);
  }
}

