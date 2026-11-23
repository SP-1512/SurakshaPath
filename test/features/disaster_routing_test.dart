// test/features/disaster_routing_test.dart
// Comprehensive automated verification for Member 3 Disaster Intelligence & Evacuation Routing.

import 'package:flutter_test/flutter_test.dart';
import 'package:surakshapath/core/models/disaster_type.dart';
import 'package:surakshapath/core/models/shelter_model.dart';
import 'package:surakshapath/core/models/user_location.dart';
import 'package:surakshapath/features/disaster/hazard_service.dart';
import 'package:surakshapath/features/routing/route_model.dart';
import 'package:surakshapath/features/routing/route_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Member 3: GeoPoint & Geometric Calculations', () {
    test('1. GeoPoint Haversine distance is mathematically accurate', () {
      const p1 = GeoPoint(16.5062, 80.6480, name: 'Benz Circle');
      const p2 = GeoPoint(16.5180, 80.6200, name: 'ZP High School');

      final distanceKm = p1.distanceTo(p2);
      // Actual great-circle distance is ~3.25 km
      expect(distanceKm > 3.0 && distanceKm < 3.5, isTrue);
      expect(p1.distanceMetersTo(p2) > 3000 && p1.distanceMetersTo(p2) < 3500, isTrue);
    });

    test('2. GeoPoint bearing calculation gives correct compass direction', () {
      const start = GeoPoint(16.0, 80.0);
      const north = GeoPoint(17.0, 80.0);
      const east = GeoPoint(16.0, 81.0);

      expect(start.bearingTo(north), closeTo(0.0, 1.0));
      expect(start.bearingTo(east), closeTo(90.0, 1.0));
    });

    test('3. GeoPoint converts seamlessly to and from UserLocation & ShelterModel', () {
      const pt = GeoPoint(16.9891, 82.2475, name: 'Kakinada Center');
      final userLoc = pt.toUserLocation(provenance: LocationProvenance.liveGps);

      expect(userLoc.latitude, equals(16.9891));
      expect(userLoc.longitude, equals(82.2475));
      expect(userLoc.locationName, equals('Kakinada Center'));
      expect(userLoc.provenance, equals(LocationProvenance.liveGps));
      expect(userLoc.isGpsActive, isTrue);

      final convertedBack = GeoPoint.fromUserLocation(userLoc);
      expect(convertedBack.latitude, equals(pt.latitude));
      expect(convertedBack.longitude, equals(pt.longitude));
      expect(convertedBack.name, equals(pt.name));

      const shelter = ShelterModel(
        id: 'shelter-test',
        name: 'Relief Center Alpha',
        address: 'Coastal Road',
        latitude: 17.0,
        longitude: 82.0,
        distanceKm: 2.5,
        capacityTotal: 200,
        capacityOccupied: 50,
        status: ShelterStatus.open,
        contactNumber: '112',
      );

      final fromShelter = GeoPoint.fromShelter(shelter);
      expect(fromShelter.latitude, equals(17.0));
      expect(fromShelter.longitude, equals(82.0));
      expect(fromShelter.name, equals('Relief Center Alpha'));
    });
  });

  group('Member 3: Hazard Intelligence & Data Honesty', () {
    late HazardService hazardService;

    setUp(() {
      hazardService = HazardService();
    });

    test('4. Hazard detection identifies active hazards and respects boundaries', () {
      final floodHazards = hazardService.getDemoHazards(DisasterType.flood);
      expect(floodHazards.isNotEmpty, isTrue);

      // Verify explicit DEMO provenance on all demo records
      for (final h in floodHazards) {
        expect(h.isDemo, isTrue);
        expect(h.source, contains('DEMO SCENARIO'));
        expect(h.title, contains('[DEMO SCENARIO]'));
      }

      // Check Prakasam Barrage critical flood
      final barrageHazard = floodHazards.firstWhere((h) => h.id == 'H-FLD-001');
      expect(barrageHazard.severity, equals(HazardSeverity.critical));
      expect(barrageHazard.isBlocked, isTrue);
      expect(barrageHazard.radiusMeters, equals(1200.0));

      // Direct coordinate at barrage should be inside
      expect(barrageHazard.containsPoint(16.5090, 80.6120), isTrue);

      // Coordinate 15 km away must NOT be affected
      expect(barrageHazard.containsPoint(16.6500, 80.7500), isFalse);
    });

    test('5. HazardRiskAssessment distinguishes direct hit, buffer zone, and clear roads', () {
      // Coordinate directly at Prakasam Barrage (critical flood hazard)
      final directHit = hazardService.assessPointRisk(16.5090, 80.6120, DisasterType.flood);
      expect(directHit.isDirectlyHit, isTrue);
      expect(directHit.isBlocked, isTrue);
      expect(directHit.highestSeverity, equals(HazardSeverity.critical));

      // Coordinate just outside radius but within 400m buffer
      final bufferHit = hazardService.assessPointRisk(16.5090, 80.6250, DisasterType.flood);
      expect(bufferHit.isBufferZone, isTrue);

      // Coordinate far away (Kakinada coordinates tested against Vijayawada flood)
      final clearArea = hazardService.assessPointRisk(16.9891, 82.2475, DisasterType.flood);
      expect(clearArea.isDirectlyHit, isFalse);
      expect(clearArea.isBufferZone, isFalse);
      expect(clearArea.isBlocked, isFalse);
    });

    test('6. HazardModel expiration check prunes expired warnings', () {
      final activeHazard = HazardModel(
        id: 'h-active',
        disasterType: DisasterType.cyclone,
        title: 'Active Cyclone',
        description: 'Testing active',
        latitude: 16.5,
        longitude: 80.5,
        radiusMeters: 500,
        severity: HazardSeverity.high,
        issuedAt: DateTime.now().subtract(const Duration(hours: 1)),
        validUntil: DateTime.now().add(const Duration(hours: 4)),
      );
      expect(activeHazard.isExpired(), isFalse);

      final expiredHazard = HazardModel(
        id: 'h-expired',
        disasterType: DisasterType.cyclone,
        title: 'Expired Warning',
        description: 'Testing expired',
        latitude: 16.5,
        longitude: 80.5,
        radiusMeters: 500,
        severity: HazardSeverity.low,
        issuedAt: DateTime.now().subtract(const Duration(hours: 10)),
        validUntil: DateTime.now().subtract(const Duration(hours: 1)),
      );
      expect(expiredHazard.isExpired(), isTrue);
    });
  });

  group('Member 3: Route Calculation & Snapping Safety', () {
    late RouteService routeService;

    setUp(() {
      routeService = RouteService();
    });

    test('7. Route calculation outside graph bounds generates honest geometric corridor', () async {
      // User and shelter in Kakinada (>150 km from Vijayawada road network)
      const kakinadaUser = GeoPoint(16.9891, 82.2475, name: 'Kakinada Resident');
      const kakinadaShelter = GeoPoint(16.9604, 82.2382, name: 'Kakinada MPCS Shelter');

      final result = await routeService.calculateEvacuationRoutes(
        userLocation: kakinadaUser,
        shelterLocation: kakinadaShelter,
        disasterType: DisasterType.flood,
      );

      // Must NOT falsely snap to Vijayawada Benz Circle
      expect(result.recommendedRoute, isNotNull);
      final route = result.recommendedRoute!;
      expect(route.verificationState, equals(RouteVerificationState.routeSafetyUnverified));
      expect(route.disclaimer, contains('Detailed street network graph is not loaded'));
      // Distance between user and shelter is ~3.3 km
      expect(route.totalDistanceKm > 2.5 && route.totalDistanceKm < 4.5, isTrue);
      expect(route.waypoints.first, equals(kakinadaUser));
      expect(route.waypoints.last, equals(kakinadaShelter));
    });

    test('8. Dijkstra discovers genuine safe path in local graph avoiding blocked canal road', () async {
      // Vijayawada coordinates within graph envelope
      const start = GeoPoint(16.5062, 80.6480, name: 'Benz Circle');
      const shelter = GeoPoint(16.5180, 80.6200, name: 'ZP High School Shelter');

      final result = await routeService.calculateEvacuationRoutes(
        userLocation: start,
        shelterLocation: shelter,
        disasterType: DisasterType.flood,
      );

      expect(result.recommendedRoute, isNotNull);
      final safeRoute = result.recommendedRoute!;

      // Recommended route must be clear of blocked roads
      expect(safeRoute.hasBlockedRoads, isFalse);
      expect(safeRoute.isRecommended, isTrue);
      expect(safeRoute.riskLevel == RouteRiskLevel.low || safeRoute.riskLevel == RouteRiskLevel.moderate, isTrue);
      expect(safeRoute.totalDistanceKm > 4.0 && safeRoute.totalDistanceKm < 6.5, isTrue);

      // Verify that if a direct route traversing Old Canal Road was discovered, it is marked as blocked
      final blockedRoute = result.allRoutes.where((r) => r.hasBlockedRoads).firstOrNull;
      if (blockedRoute != null) {
        expect(blockedRoute.riskLevel, equals(RouteRiskLevel.blocked));
        expect(blockedRoute.riskScore >= 90.0, isTrue);
      }
    });

    test('9. Shelter safety ranking ranks accessible shelters ahead of impassable ones', () async {
      const start = GeoPoint(16.5062, 80.6480, name: 'Benz Circle');
      const candidates = [
        GeoPoint(16.5180, 80.6200, name: 'ZP High School Shelter'),
        GeoPoint(16.5280, 80.6450, name: 'Gunadala Community Hall'),
      ];

      final ranked = await routeService.rankSheltersBySafety(
        userLocation: start,
        candidateShelters: candidates,
        disasterType: DisasterType.flood,
      );

      expect(ranked.isNotEmpty, isTrue);
      expect(ranked.first.isAccessible, isTrue);
      expect(ranked.first.riskScore <= ranked.last.riskScore || ranked.first.isAccessible && !ranked.last.isAccessible, isTrue);
    });
  });
}
