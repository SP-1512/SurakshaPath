import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/models/user_location.dart';
import '../../../core/services/user_profile_service.dart';

/// Categories of GPS hardware acquisition failure.
enum LocationErrorType {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  timeout,
  unavailable,
  unknown,
}

/// Structured location result holding either a valid position fix
/// or error classification with user-facing diagnostic message.
class LocationResult {
  final Position? position;
  final LocationErrorType? errorType;
  final String? errorMessage;
  final bool isLastKnownFallback;

  const LocationResult._({
    this.position,
    this.errorType,
    this.errorMessage,
    this.isLastKnownFallback = false,
  });

  factory LocationResult.success(Position p, {bool isLastKnownFallback = false}) =>
      LocationResult._(position: p, isLastKnownFallback: isLastKnownFallback);

  factory LocationResult.failure(LocationErrorType type, String message) =>
      LocationResult._(errorType: type, errorMessage: message);

  bool get isSuccess => position != null;
  double? get latitude => position?.latitude;
  double? get longitude => position?.longitude;
  double? get accuracy => position?.accuracy;
}

/// Hardware GPS service communicating directly with GNSS satellite receiver chips.
/// Internet-independent; operates in Airplane Mode with GPS active.
/// Synchronizes directly with the application's shared [UserProfileService.profileNotifier].
class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  static const Duration defaultTimeout = Duration(seconds: 15);

  Future<bool> isLocationServiceEnabled() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (e) {
      debugPrint('[LocationService] isLocationServiceEnabled error: $e');
      return false;
    }
  }

  Future<LocationPermission> checkPermission() async {
    try {
      return await Geolocator.checkPermission();
    } catch (e) {
      debugPrint('[LocationService] checkPermission error: $e');
      return LocationPermission.denied;
    }
  }

  Future<LocationPermission> requestPermission() async {
    try {
      return await Geolocator.requestPermission();
    } catch (e) {
      debugPrint('[LocationService] requestPermission error: $e');
      return LocationPermission.denied;
    }
  }

  Future<bool> openLocationSettings() async {
    try {
      return await Geolocator.openLocationSettings();
    } catch (e) {
      debugPrint('[LocationService] openLocationSettings error: $e');
      return false;
    }
  }

  Future<bool> openAppSettings() async {
    try {
      return await Geolocator.openAppSettings();
    } catch (e) {
      debugPrint('[LocationService] openAppSettings error: $e');
      return false;
    }
  }

  /// Obtains the user's current hardware GPS/GNSS fix.
  /// Never returns a hardcoded mock position as a live fix.
  Future<LocationResult> getCurrentLocation({
    Duration timeout = defaultTimeout,
  }) async {
    try {
      if (!await isLocationServiceEnabled()) {
        return LocationResult.failure(
          LocationErrorType.serviceDisabled,
          'GPS is currently off. Turn on Location in device Settings to show your position.',
        );
      }

      LocationPermission perm = await checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await requestPermission();
        if (perm == LocationPermission.denied) {
          return LocationResult.failure(
            LocationErrorType.permissionDenied,
            'Location permission denied. SurakshaPath needs GPS to locate you during a disaster.',
          );
        }
      }
      if (perm == LocationPermission.deniedForever) {
        return LocationResult.failure(
          LocationErrorType.permissionDeniedForever,
          'Location permission permanently denied. Grant it in device Settings.',
        );
      }

      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: timeout,
          ),
        );
        return LocationResult.success(pos);
      } on TimeoutException {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) {
          return LocationResult.success(last, isLastKnownFallback: true);
        }
        return LocationResult.failure(
          LocationErrorType.timeout,
          'GPS satellite fix timed out. Move outdoors with a clear view of the sky.',
        );
      }
    } catch (e) {
      debugPrint('[LocationService] Error acquiring location: $e');
      return LocationResult.failure(
        LocationErrorType.unknown,
        'GPS error: ${e.toString()}',
      );
    }
  }

  /// Acquires a genuine GPS fix and synchronizes with [UserProfileService.profileNotifier].
  /// Preserves [LocationProvenance.liveGps] with authentic telemetry.
  Future<LocationResult> acquireAndSyncWithProfile({
    Duration timeout = defaultTimeout,
  }) async {
    final result = await getCurrentLocation(timeout: timeout);
    if (result.isSuccess && result.position != null) {
      final p = result.position!;
      final userLocation = UserLocation(
        latitude: p.latitude,
        longitude: p.longitude,
        locationName: result.isLastKnownFallback ? 'Last Known GPS Fix' : 'Current GPS Fix',
        subArea: 'Coastal Andhra Pradesh',
        accuracyMeters: p.accuracy,
        timestamp: p.timestamp,
        isGpsActive: true,
        isMock: false,
        provenance: LocationProvenance.liveGps,
      );
      await UserProfileService.updateLocation(userLocation);
    }
    return result;
  }

  /// Live position stream for continuous tracking.
  Stream<Position> getPositionStream({
    LocationAccuracy accuracy = LocationAccuracy.high,
    int distanceFilter = 5,
  }) =>
      Geolocator.getPositionStream(
        locationSettings: LocationSettings(
          accuracy: accuracy,
          distanceFilter: distanceFilter,
        ),
      );
}
