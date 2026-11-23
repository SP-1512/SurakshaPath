// lib/features/routing/route_model.dart
// Evacuation route and GIS geometric models for SurakshaPath.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:maplibre/maplibre.dart' as ml;
import '../../core/constants/app_colors.dart';
import '../../core/models/disaster_type.dart';
import '../../core/models/evacuation_route.dart' show RouteSafetyStatus;
import '../../core/models/shelter_model.dart';
import '../../core/models/user_location.dart';

export '../../core/models/evacuation_route.dart' show RouteSafetyStatus;

/// Geographical coordinate point supporting multi-model conversion across SurakshaPath.
class GeoPoint {
  final double latitude;
  final double longitude;
  final String? name;

  const GeoPoint(
    this.latitude,
    this.longitude, {
    this.name,
  });

  double get lat => latitude;
  double get lng => longitude;

  /// Calculate great-circle distance in kilometers using the Haversine formula
  double distanceTo(GeoPoint other) {
    const double earthRadiusKm = 6371.0;
    final dLat = _degToRad(other.latitude - latitude);
    final dLng = _degToRad(other.longitude - longitude);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(latitude)) *
            math.cos(_degToRad(other.latitude)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  /// Distance in meters
  double distanceMetersTo(GeoPoint other) => distanceTo(other) * 1000.0;

  /// Calculate compass bearing from this point to another point in degrees (0-360)
  double bearingTo(GeoPoint other) {
    final lat1 = _degToRad(latitude);
    final lat2 = _degToRad(other.latitude);
    final dLng = _degToRad(other.longitude - longitude);

    final y = math.sin(dLng) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLng);

    final brng = math.atan2(y, x);
    return (brng * (180.0 / math.pi) + 360.0) % 360.0;
  }

  static double _degToRad(double deg) => deg * (math.pi / 180.0);

  /// Convert to UserLocation model
  UserLocation toUserLocation({
    LocationProvenance provenance = LocationProvenance.manualSelection,
    String? subArea,
  }) {
    return UserLocation(
      latitude: latitude,
      longitude: longitude,
      locationName: name ?? 'Selected Location',
      subArea: subArea ?? 'Designated Location',
      provenance: provenance,
      timestamp: DateTime.now(),
      isGpsActive: provenance == LocationProvenance.liveGps,
    );
  }

  /// Factory from UserLocation
  factory GeoPoint.fromUserLocation(UserLocation loc) {
    return GeoPoint(
      loc.latitude,
      loc.longitude,
      name: loc.locationName,
    );
  }

  /// Factory from ShelterModel
  factory GeoPoint.fromShelter(ShelterModel shelter) {
    return GeoPoint(
      shelter.latitude,
      shelter.longitude,
      name: shelter.name,
    );
  }

  /// Convert to MapLibre Geographic coordinate (lon, lat)
  ml.Geographic toGeographic() => ml.Geographic(lon: longitude, lat: latitude);

  /// Factory from MapLibre Geographic coordinate
  factory GeoPoint.fromGeographic(ml.Geographic geo, [String? name]) {
    return GeoPoint(geo.lat.toDouble(), geo.lon.toDouble(), name: name);
  }

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        if (name != null) 'name': name,
      };

  factory GeoPoint.fromJson(Map<String, dynamic> json) => GeoPoint(
        (json['latitude'] ?? json['lat'] as num?)?.toDouble() ?? 0.0,
        (json['longitude'] ?? json['lng'] as num?)?.toDouble() ?? 0.0,
        name: json['name']?.toString(),
      );

  Map<String, double> toLatLngMap() => {'lat': latitude, 'lng': longitude};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GeoPoint &&
          (other.latitude - latitude).abs() < 0.00001 &&
          (other.longitude - longitude).abs() < 0.00001;

  @override
  int get hashCode => Object.hash((latitude * 10000).round(), (longitude * 10000).round());

  @override
  String toString() => name != null ? '$name ($latitude, $longitude)' : '($latitude, $longitude)';
}

/// Evacuation route risk classification
enum RouteRiskLevel {
  low,
  moderate,
  high,
  blocked;

  String get label {
    switch (this) {
      case RouteRiskLevel.low:
        return 'Low Reported Risk';
      case RouteRiskLevel.moderate:
        return 'Moderate Caution';
      case RouteRiskLevel.high:
        return 'High Risk';
      case RouteRiskLevel.blocked:
        return 'Road Blocked / Submerged';
    }
  }

  String get badgeText {
    switch (this) {
      case RouteRiskLevel.low:
        return 'RECOMMENDED';
      case RouteRiskLevel.moderate:
        return 'CAUTION';
      case RouteRiskLevel.high:
        return 'DANGEROUS';
      case RouteRiskLevel.blocked:
        return 'IMPASSABLE';
    }
  }

  Color get color {
    switch (this) {
      case RouteRiskLevel.low:
        return AppColors.safetyGreen;
      case RouteRiskLevel.moderate:
        return AppColors.warningOrange;
      case RouteRiskLevel.high:
        return AppColors.critical;
      case RouteRiskLevel.blocked:
        return AppColors.emergencyRed;
    }
  }
}

/// High-level verification state for UI routing cards and status indicators
enum RouteVerificationState {
  calculating,
  routeAvailable,
  routeSafetyUnverified,
  noVerifiedRoute,
  demoRoute;

  String get label {
    switch (this) {
      case RouteVerificationState.calculating:
        return 'CALCULATING ROUTE';
      case RouteVerificationState.routeAvailable:
        return 'ROUTE AVAILABLE';
      case RouteVerificationState.routeSafetyUnverified:
        return 'ROUTE SAFETY UNVERIFIED';
      case RouteVerificationState.noVerifiedRoute:
        return 'NO VERIFIED ROUTE AVAILABLE';
      case RouteVerificationState.demoRoute:
        return 'DEMO ROUTE';
    }
  }

  Color get color {
    switch (this) {
      case RouteVerificationState.calculating:
        return AppColors.primaryBlue;
      case RouteVerificationState.routeAvailable:
        return AppColors.safetyGreen;
      case RouteVerificationState.routeSafetyUnverified:
        return AppColors.warningOrange;
      case RouteVerificationState.noVerifiedRoute:
        return AppColors.emergencyRed;
      case RouteVerificationState.demoRoute:
        return AppColors.brandBlueBright;
    }
  }
}

/// Represents an individual road segment within the evacuation network
class RoadSegment {
  final String id;
  final GeoPoint start;
  final GeoPoint end;
  final String roadName;
  final double distanceKm;
  final bool isBlocked;
  final RouteRiskLevel riskLevel;
  final String? hazardNotes;
  final String? turnInstruction;

  const RoadSegment({
    required this.id,
    required this.start,
    required this.end,
    required this.roadName,
    required this.distanceKm,
    this.isBlocked = false,
    this.riskLevel = RouteRiskLevel.low,
    this.hazardNotes,
    this.turnInstruction,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'start': start.toJson(),
        'end': end.toJson(),
        'roadName': roadName,
        'distanceKm': distanceKm,
        'isBlocked': isBlocked,
        'riskLevel': riskLevel.name,
        if (hazardNotes != null) 'hazardNotes': hazardNotes,
        if (turnInstruction != null) 'turnInstruction': turnInstruction,
      };

  factory RoadSegment.fromJson(Map<String, dynamic> json) => RoadSegment(
        id: json['id']?.toString() ?? 'road_${DateTime.now().millisecondsSinceEpoch}',
        start: GeoPoint.fromJson(json['start'] as Map<String, dynamic>),
        end: GeoPoint.fromJson(json['end'] as Map<String, dynamic>),
        roadName: json['roadName']?.toString() ?? json['road_name']?.toString() ?? 'Connecting Road',
        distanceKm: (json['distanceKm'] ?? json['distance_km'] ?? json['distance'] as num?)?.toDouble() ?? 1.0,
        isBlocked: json['isBlocked'] == true || json['is_blocked'] == true,
        riskLevel: RouteRiskLevel.values.firstWhere(
          (r) => r.name == (json['riskLevel'] ?? json['risk_level']),
          orElse: () => RouteRiskLevel.low,
        ),
        hazardNotes: json['hazardNotes']?.toString() ?? json['hazard_notes']?.toString(),
        turnInstruction: json['turnInstruction']?.toString(),
      );
}

/// Complete calculated evacuation route from origin to destination shelter
class EvacuationRoute {
  final String id;
  final String name;
  final String destinationShelterId;
  final String destinationShelterName;
  final List<GeoPoint> waypoints;
  final List<RoadSegment> segments;
  final double totalDistanceKm;
  final int estimatedMinutes;
  final RouteRiskLevel riskLevel;
  final RouteSafetyStatus safetyStatus;
  final RouteVerificationState verificationState;
  final double riskScore;
  final String riskExplanation;
  final List<String> warnings;
  final bool isRecommended;
  final bool hasBlockedRoads;
  final String elevationProfile;
  final String disclaimer;
  final bool isDemo;

  const EvacuationRoute({
    required this.id,
    String? name,
    String? title,
    this.destinationShelterId = '',
    this.destinationShelterName = '',
    this.waypoints = const [],
    this.segments = const [],
    double? totalDistanceKm,
    double? distanceKm,
    int? estimatedMinutes,
    int? estimatedTimeMinutes,
    this.riskLevel = RouteRiskLevel.low,
    RouteSafetyStatus? safetyStatus,
    this.verificationState = RouteVerificationState.routeAvailable,
    this.riskScore = 15.0,
    String? riskExplanation,
    String? roadConditionSummary,
    this.warnings = const [],
    this.isRecommended = false,
    this.hasBlockedRoads = false,
    this.elevationProfile = 'Normal Elevation',
    this.disclaimer =
        'Illustrative demo data only. A route should not be called safe without reliable, current verification.',
    this.isDemo = true,
  })  : name = name ?? title ?? 'Evacuation Corridor',
        totalDistanceKm = totalDistanceKm ?? distanceKm ?? 0.0,
        estimatedMinutes = estimatedMinutes ?? estimatedTimeMinutes ?? 0,
        riskExplanation = riskExplanation ?? roadConditionSummary ?? '',
        safetyStatus = safetyStatus ??
            (hasBlockedRoads || riskLevel == RouteRiskLevel.blocked
                ? RouteSafetyStatus.blocked
                : (riskLevel == RouteRiskLevel.high || riskLevel == RouteRiskLevel.moderate
                    ? RouteSafetyStatus.caution
                    : (isDemo ? RouteSafetyStatus.simulated : RouteSafetyStatus.safe)));

  String get title => name;
  double get distanceKm => totalDistanceKm;
  int get estimatedTimeMinutes => estimatedMinutes;
  String get roadConditionSummary => riskExplanation;
  List<GeoPoint> get polylinePoints => waypoints;
  bool get isBlocked => hasBlockedRoads || riskLevel == RouteRiskLevel.blocked;
}

/// Container result holding both recommended safe route and alternative routes
class RouteCalculationResult {
  final EvacuationRoute? recommendedRoute;
  final EvacuationRoute? alternativeRoute;
  final List<EvacuationRoute> allRoutes;
  final GeoPoint startPoint;
  final GeoPoint destinationShelter;
  final DisasterType disasterType;
  final String statusMessage;
  final RouteVerificationState state;

  const RouteCalculationResult({
    required this.recommendedRoute,
    this.alternativeRoute,
    this.allRoutes = const [],
    required this.startPoint,
    required this.destinationShelter,
    required this.disasterType,
    required this.statusMessage,
    this.state = RouteVerificationState.routeAvailable,
  });

  bool get hasValidSafeRoute =>
      recommendedRoute != null && !recommendedRoute!.hasBlockedRoads && !recommendedRoute!.isBlocked;
}

/// Helper model for Shanmukh (Member 4): Shelter ranking based on evacuation route risk
class ShelterRouteAssessment {
  final String shelterId;
  final String shelterName;
  final GeoPoint shelterLocation;
  final EvacuationRoute? safestRoute;
  final double distanceKm;
  final int travelMinutes;
  final double riskScore;
  final bool isAccessible;
  final String recommendation;

  const ShelterRouteAssessment({
    required this.shelterId,
    required this.shelterName,
    required this.shelterLocation,
    required this.safestRoute,
    required this.distanceKm,
    required this.travelMinutes,
    required this.riskScore,
    required this.isAccessible,
    required this.recommendation,
  });
}
