// lib/features/disaster/hazard_service.dart
// Disaster hazard intelligence, zone proximity detection, and risk assessment for SurakshaPath.

import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/disaster_type.dart';
import '../routing/route_model.dart';

/// Hazard threat severity levels
enum HazardSeverity {
  low,
  medium,
  high,
  critical;

  String get label {
    switch (this) {
      case HazardSeverity.low:
        return 'Low Risk';
      case HazardSeverity.medium:
        return 'Moderate Risk';
      case HazardSeverity.high:
        return 'High Risk';
      case HazardSeverity.critical:
        return 'Critical Danger';
    }
  }

  Color get color {
    switch (this) {
      case HazardSeverity.low:
        return AppColors.safetyGreen;
      case HazardSeverity.medium:
        return AppColors.warningOrange;
      case HazardSeverity.high:
        return AppColors.critical;
      case HazardSeverity.critical:
        return AppColors.emergencyRed;
    }
  }

  /// Cost multiplier used by graph routing engine to penalize risky roads
  double get riskWeightMultiplier {
    switch (this) {
      case HazardSeverity.low:
        return 1.4;
      case HazardSeverity.medium:
        return 2.8;
      case HazardSeverity.high:
        return 6.0;
      case HazardSeverity.critical:
        return 999.0; // Impassable
    }
  }

  static HazardSeverity fromString(String? value) {
    if (value == null) return HazardSeverity.medium;
    final lower = value.toLowerCase().trim();
    if (lower.contains('crit') || lower.contains('severe')) {
      return HazardSeverity.critical;
    } else if (lower.contains('high') || lower.contains('danger')) {
      return HazardSeverity.high;
    } else if (lower.contains('low') || lower.contains('minor')) {
      return HazardSeverity.low;
    }
    return HazardSeverity.medium;
  }
}

/// Model representing a detected or reported hazard zone with explicit data provenance.
class HazardModel {
  final String id;
  final DisasterType disasterType;
  final String title;
  final String description;
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final HazardSeverity severity;
  final bool isBlocked;
  final String source;
  final bool isDemo;
  final DateTime issuedAt;
  final DateTime? validUntil;
  final String? roadNameAffected;
  final String? specificImpact;

  const HazardModel({
    required this.id,
    required this.disasterType,
    required this.title,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.severity,
    this.isBlocked = false,
    this.source = 'DEMO SCENARIO - Simulated Incident',
    this.isDemo = true,
    required this.issuedAt,
    this.validUntil,
    this.roadNameAffected,
    this.specificImpact,
  });

  /// Check whether this hazard advisory has expired
  bool isExpired([DateTime? now]) {
    if (validUntil == null) return false;
    final current = now ?? DateTime.now();
    return current.isAfter(validUntil!);
  }

  /// Check if a given coordinate falls inside this hazard zone or buffer perimeter
  bool containsPoint(double lat, double lng, {double bufferMeters = 0.0}) {
    final distance = distanceTo(lat, lng);
    return distance <= (radiusMeters + bufferMeters);
  }

  /// Calculate distance in meters using the Haversine formula
  double distanceTo(double targetLat, double targetLng) {
    const double earthRadius = 6371000;
    final dLat = _degToRad(targetLat - latitude);
    final dLng = _degToRad(targetLng - longitude);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(latitude)) *
            math.cos(_degToRad(targetLat)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  static double _degToRad(double deg) => deg * (math.pi / 180.0);

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'disasterType': disasterType.name,
      'title': title,
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
      'radiusMeters': radiusMeters,
      'severity': severity.name,
      'isBlocked': isBlocked,
      'source': source,
      'isDemo': isDemo,
      'issuedAt': issuedAt.toIso8601String(),
      if (validUntil != null) 'validUntil': validUntil!.toIso8601String(),
      if (roadNameAffected != null) 'roadNameAffected': roadNameAffected,
      if (specificImpact != null) 'specificImpact': specificImpact,
    };
  }

  factory HazardModel.fromJson(Map<String, dynamic> json) {
    DateTime parseTime(dynamic val, DateTime fallback) {
      if (val == null) return fallback;
      try {
        return DateTime.parse(val.toString());
      } catch (_) {
        return fallback;
      }
    }

    final issued = parseTime(json['issuedAt'] ?? json['reportedTime'], DateTime.now());
    final valid = json['validUntil'] != null ? parseTime(json['validUntil'], DateTime.now().add(const Duration(hours: 24))) : null;

    return HazardModel(
      id: json['id']?.toString() ?? 'hazard_${DateTime.now().millisecondsSinceEpoch}',
      disasterType: DisasterType.fromString(
        json['disasterType']?.toString() ?? json['disaster_type']?.toString(),
      ),
      title: json['title']?.toString() ?? json['name']?.toString() ?? 'Active Hazard',
      description: json['description']?.toString() ?? 'Hazardous area reported.',
      latitude: (json['latitude'] ?? json['lat'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] ?? json['lng'] as num?)?.toDouble() ?? 0.0,
      radiusMeters: (json['radiusMeters'] ??
              json['radius_meters'] ??
              json['affected_radius'] as num?)
          ?.toDouble() ??
          500.0,
      severity: HazardSeverity.fromString(json['severity']?.toString()),
      isBlocked: json['isBlocked'] == true ||
          json['is_blocked'] == true ||
          json['status'] == 'blocked',
      source: json['source']?.toString() ?? 'DEMO SCENARIO - Simulated Incident',
      isDemo: json['isDemo'] as bool? ?? true,
      issuedAt: issued,
      validUntil: valid,
      roadNameAffected: json['roadNameAffected']?.toString() ?? json['road_name']?.toString(),
      specificImpact: json['specificImpact']?.toString() ?? json['impact']?.toString(),
    );
  }
}

/// Evaluation result for a coordinate or road segment against active hazards
class HazardRiskAssessment {
  final bool isDirectlyHit;
  final bool isBufferZone;
  final bool isBlocked;
  final HazardSeverity highestSeverity;
  final double riskMultiplier;
  final HazardModel? primaryHazard;
  final String explanation;

  const HazardRiskAssessment({
    required this.isDirectlyHit,
    required this.isBufferZone,
    required this.isBlocked,
    required this.highestSeverity,
    required this.riskMultiplier,
    this.primaryHazard,
    required this.explanation,
  });

  static const HazardRiskAssessment clear = HazardRiskAssessment(
    isDirectlyHit: false,
    isBufferZone: false,
    isBlocked: false,
    highestSeverity: HazardSeverity.low,
    riskMultiplier: 1.0,
    primaryHazard: null,
    explanation: 'Section is clear of known active hazard perimeters.',
  );
}

/// Abstract contract for hazard repository integration (IMD, SDMA, and local offline cache)
abstract class IHazardRepository {
  Future<List<HazardModel>> fetchHazards({bool forceRefresh = false});
  Future<List<HazardModel>> getHazardsForDisaster(DisasterType type);
}

/// Service that manages hazard data, detects unsafe roads, and interfaces with maps and routing
class HazardService implements IHazardRepository {
  static final HazardService _instance = HazardService._internal();
  factory HazardService() => _instance;
  HazardService._internal();

  final Map<DisasterType, List<HazardModel>> _cachedHazards = {};
  DateTime? _lastFetchTime;
  static const Duration _cacheTtl = Duration(minutes: 5);

  @override
  Future<List<HazardModel>> fetchHazards({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _lastFetchTime != null &&
        DateTime.now().difference(_lastFetchTime!) < _cacheTtl &&
        _cachedHazards.isNotEmpty) {
      return _cachedHazards.values.expand((list) => list).toList();
    }

    try {
      final jsonString = await rootBundle.loadString('assets/data/hazards.json');
      final dynamic decoded = jsonDecode(jsonString);
      final List<dynamic> list = decoded is List ? decoded : (decoded['hazards'] ?? []);

      final loaded = list
          .map((item) => HazardModel.fromJson(item as Map<String, dynamic>))
          .where((h) => !h.isExpired())
          .toList();

      if (loaded.isNotEmpty) {
        _cachedHazards.clear();
        for (final h in loaded) {
          _cachedHazards.putIfAbsent(h.disasterType, () => []).add(h);
        }
        _lastFetchTime = DateTime.now();
        return loaded;
      }
    } catch (e) {
      debugPrint('[HazardService] Asset load fallback: Using demo dataset ($e)');
    }

    final fallback = [
      ..._demoFloodHazards,
      ..._demoCycloneHazards,
      ..._demoEarthquakeHazards,
    ];
    _cachedHazards.clear();
    for (final h in fallback) {
      _cachedHazards.putIfAbsent(h.disasterType, () => []).add(h);
    }
    _lastFetchTime = DateTime.now();
    return fallback;
  }

  @override
  Future<List<HazardModel>> getHazardsForDisaster(DisasterType type) async {
    if (type == DisasterType.all) {
      return fetchHazards();
    }

    if (_cachedHazards.containsKey(type) && _cachedHazards[type]!.isNotEmpty) {
      final valid = _cachedHazards[type]!.where((h) => !h.isExpired()).toList();
      if (valid.isNotEmpty) return valid;
    }

    final all = await fetchHazards();
    final matching = all.where((h) => h.disasterType == type).toList();
    if (matching.isNotEmpty) {
      _cachedHazards[type] = matching;
      return matching;
    }

    final demoList = getDemoHazards(type);
    _cachedHazards[type] = demoList;
    return demoList;
  }

  List<HazardModel> getDemoHazards(DisasterType type) {
    switch (type) {
      case DisasterType.flood:
        return _demoFloodHazards;
      case DisasterType.cyclone:
        return _demoCycloneHazards;
      case DisasterType.earthquake:
        return _demoEarthquakeHazards;
      default:
        return _demoFloodHazards;
    }
  }

  HazardRiskAssessment assessPointRisk(
    double lat,
    double lng,
    DisasterType disasterType, {
    List<HazardModel>? activeHazards,
  }) {
    final hazards = activeHazards ??
        _cachedHazards[disasterType] ??
        getDemoHazards(disasterType);

    HazardModel? worstHazard;
    bool directHit = false;
    bool bufferHit = false;
    bool blocked = false;
    HazardSeverity worstSeverity = HazardSeverity.low;
    double maxMultiplier = 1.0;

    for (final h in hazards) {
      final dist = h.distanceTo(lat, lng);
      final inDirect = dist <= h.radiusMeters;
      final inBuffer = dist <= (h.radiusMeters + 400.0);

      if (inDirect || inBuffer) {
        if (inDirect) directHit = true;
        if (inBuffer && !inDirect) bufferHit = true;
        if (h.isBlocked && inDirect) blocked = true;

        if (h.severity.index >= worstSeverity.index) {
          worstSeverity = h.severity;
          worstHazard = h;
          maxMultiplier = inDirect
              ? h.severity.riskWeightMultiplier
              : (h.severity.riskWeightMultiplier * 0.6).clamp(1.2, 3.5);
        }
      }
    }

    if (worstHazard == null) {
      return HazardRiskAssessment.clear;
    }

    final impactNote = worstHazard.specificImpact != null ? ' (${worstHazard.specificImpact})' : '';
    final reason = directHit
        ? '${worstHazard.title}: ${worstHazard.description}$impactNote. Severity: ${worstHazard.severity.label}.'
        : 'Within proximity buffer of ${worstHazard.title} (~400m perimeter). Proceed with caution.';

    return HazardRiskAssessment(
      isDirectlyHit: directHit,
      isBufferZone: bufferHit,
      isBlocked: blocked,
      highestSeverity: worstSeverity,
      riskMultiplier: maxMultiplier,
      primaryHazard: worstHazard,
      explanation: reason,
    );
  }

  HazardRiskAssessment assessSegmentRisk(
    GeoPoint start,
    GeoPoint end,
    DisasterType disasterType, {
    List<HazardModel>? activeHazards,
  }) {
    const sampleSteps = 5;
    HazardRiskAssessment worstAssessment = HazardRiskAssessment.clear;

    for (int i = 0; i <= sampleSteps; i++) {
      final fraction = i / sampleSteps;
      final lat = start.latitude + (end.latitude - start.latitude) * fraction;
      final lng = start.longitude + (end.longitude - start.longitude) * fraction;

      final pointAssessment = assessPointRisk(
        lat,
        lng,
        disasterType,
        activeHazards: activeHazards,
      );

      if (pointAssessment.isBlocked) {
        return pointAssessment;
      }

      if (pointAssessment.riskMultiplier > worstAssessment.riskMultiplier) {
        worstAssessment = pointAssessment;
      }
    }

    return worstAssessment;
  }

  List<Map<String, dynamic>> getMapCircles(DisasterType type) {
    final list = _cachedHazards[type] ?? getDemoHazards(type);
    return list.map((h) {
      return {
        'latitude': h.latitude,
        'longitude': h.longitude,
        'radiusMeters': h.radiusMeters,
        'isBlocked': h.isBlocked,
        'severity': h.severity.name,
        'title': h.title,
        'isDemo': h.isDemo,
      };
    }).toList();
  }

  bool isShelterNearHazard(double shelterLat, double shelterLng, DisasterType type) {
    final assessment = assessPointRisk(shelterLat, shelterLng, type);
    return assessment.isDirectlyHit || assessment.isBufferZone;
  }

  static final List<HazardModel> _demoFloodHazards = [
    HazardModel(
      id: 'H-FLD-001',
      disasterType: DisasterType.flood,
      title: '[DEMO SCENARIO] Prakasam Barrage Flash Surge',
      description: 'DEMO SCENARIO: Simulated discharge spike. Barrage Bund road closed due to simulated water depth.',
      latitude: 16.5090,
      longitude: 80.6120,
      radiusMeters: 1200.0,
      severity: HazardSeverity.critical,
      isBlocked: true,
      source: 'DEMO SCENARIO - Simulated Hydrological Incident',
      isDemo: true,
      issuedAt: DateTime.now().subtract(const Duration(hours: 1)),
      validUntil: DateTime.now().add(const Duration(hours: 24)),
      roadNameAffected: 'Barrage Bund Road',
      specificImpact: 'Simulated water depth: 1.8m flowing',
    ),
    HazardModel(
      id: 'H-FLD-002',
      disasterType: DisasterType.flood,
      title: '[DEMO SCENARIO] Bandar Canal Embankment Breach',
      description: 'DEMO SCENARIO: Simulated breach reported along Canal Road between Governorpet and Old Bus Stand.',
      latitude: 16.5020,
      longitude: 80.6350,
      radiusMeters: 800.0,
      severity: HazardSeverity.critical,
      isBlocked: true,
      source: 'DEMO SCENARIO - Simulated Canal Breach',
      isDemo: true,
      issuedAt: DateTime.now().subtract(const Duration(minutes: 45)),
      validUntil: DateTime.now().add(const Duration(hours: 24)),
      roadNameAffected: 'Old Canal Road',
      specificImpact: 'Simulated water depth: 1.5m | Impassable',
    ),
    HazardModel(
      id: 'H-FLD-003',
      disasterType: DisasterType.flood,
      title: '[DEMO SCENARIO] MG Road Waterlogging',
      description: 'DEMO SCENARIO: Simulated stormwater accumulation along commercial stretch.',
      latitude: 16.5085,
      longitude: 80.6420,
      radiusMeters: 550.0,
      severity: HazardSeverity.medium,
      isBlocked: false,
      source: 'DEMO SCENARIO - Simulated Waterlogging',
      isDemo: true,
      issuedAt: DateTime.now().subtract(const Duration(minutes: 30)),
      validUntil: DateTime.now().add(const Duration(hours: 12)),
      roadNameAffected: 'MG Road Expressway',
      specificImpact: 'Simulated water depth: 0.35m | Slow traffic',
    ),
    HazardModel(
      id: 'H-FLD-004',
      disasterType: DisasterType.flood,
      title: '[DEMO SCENARIO] Budameru Rivulet Overflow',
      description: 'DEMO SCENARIO: Simulated northern railway underpass submergence.',
      latitude: 16.5360,
      longitude: 80.6280,
      radiusMeters: 900.0,
      severity: HazardSeverity.high,
      isBlocked: true,
      source: 'DEMO SCENARIO - Simulated Rivulet Breach',
      isDemo: true,
      issuedAt: DateTime.now().subtract(const Duration(hours: 2)),
      validUntil: DateTime.now().add(const Duration(hours: 20)),
      roadNameAffected: 'North Railway Underpass Road',
      specificImpact: 'Simulated water depth: 1.2m',
    ),
  ];

  static final List<HazardModel> _demoCycloneHazards = [
    HazardModel(
      id: 'H-CYC-001',
      disasterType: DisasterType.cyclone,
      title: '[DEMO SCENARIO] NH-16 Coastal Gale Obstruction',
      description: 'DEMO SCENARIO: Simulated gale wind gusts exceeding 100 km/h. Fallen trees and live wire hazard.',
      latitude: 16.4950,
      longitude: 80.6650,
      radiusMeters: 1400.0,
      severity: HazardSeverity.critical,
      isBlocked: true,
      source: 'DEMO SCENARIO - Simulated Cyclone Incident',
      isDemo: true,
      issuedAt: DateTime.now().subtract(const Duration(hours: 1)),
      validUntil: DateTime.now().add(const Duration(hours: 18)),
      roadNameAffected: 'National Highway 16',
      specificImpact: 'Live wire hazard simulation',
    ),
    HazardModel(
      id: 'H-CYC-002',
      disasterType: DisasterType.cyclone,
      title: '[DEMO SCENARIO] Commercial Hoarding Collapse',
      description: 'DEMO SCENARIO: Simulated steel billboard scaffolding collapsed near Besant Road junction.',
      latitude: 16.5140,
      longitude: 80.6380,
      radiusMeters: 650.0,
      severity: HazardSeverity.high,
      isBlocked: true,
      source: 'DEMO SCENARIO - Simulated Wind Damage',
      isDemo: true,
      issuedAt: DateTime.now().subtract(const Duration(minutes: 50)),
      validUntil: DateTime.now().add(const Duration(hours: 14)),
      roadNameAffected: 'Besant Road',
      specificImpact: 'Structural debris simulation',
    ),
  ];

  static final List<HazardModel> _demoEarthquakeHazards = [
    HazardModel(
      id: 'H-EQ-001',
      disasterType: DisasterType.earthquake,
      title: '[DEMO SCENARIO] Old Town Masonry Collapse',
      description: 'DEMO SCENARIO: Simulated commercial building facade collapse. Heavy rubble blocks carriageway.',
      latitude: 16.5130,
      longitude: 80.6190,
      radiusMeters: 750.0,
      severity: HazardSeverity.critical,
      isBlocked: true,
      source: 'DEMO SCENARIO - Simulated Seismic Rubble',
      isDemo: true,
      issuedAt: DateTime.now().subtract(const Duration(minutes: 40)),
      validUntil: DateTime.now().add(const Duration(hours: 12)),
      roadNameAffected: 'One-Town Main Bazaar Street',
      specificImpact: 'Rubble barrier simulation',
    ),
    HazardModel(
      id: 'H-EQ-002',
      disasterType: DisasterType.earthquake,
      title: '[DEMO SCENARIO] Flyover Joint Fissure',
      description: 'DEMO SCENARIO: Simulated expansion joint fissure detected. Ramp closed for audit.',
      latitude: 16.5075,
      longitude: 80.6390,
      radiusMeters: 450.0,
      severity: HazardSeverity.high,
      isBlocked: true,
      source: 'DEMO SCENARIO - Simulated Structural Check',
      isDemo: true,
      issuedAt: DateTime.now().subtract(const Duration(minutes: 25)),
      validUntil: DateTime.now().add(const Duration(hours: 14)),
      roadNameAffected: 'City Center Elevated Flyover',
      specificImpact: 'Fissure detected simulation',
    ),
  ];
}
