import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:surakshapath/core/models/disaster_type.dart';
import 'package:surakshapath/features/routing/route_model.dart';
import 'package:surakshapath/features/routing/route_service.dart';
import 'package:surakshapath/features/routing/screens/routing_screen.dart';
import 'package:surakshapath/features/routing/widgets/evacuation_map_view.dart';
import 'package:surakshapath/core/services/user_profile_service.dart';
import 'package:surakshapath/core/services/locale_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RouteService routeService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await UserProfileService.init();
    await LocaleService.init();
    routeService = RouteService();
  });

  group('SurakshaPath Road-Network Routing Engine Verification', () {
    test('1. Coastal Sector: Dijkstra calculates road-following route with genuine intermediate geometry', () async {
      const userOrigin = GeoPoint(16.9891, 82.2475, name: 'Suryaraopeta');
      const shelterDestination = GeoPoint(16.9604, 82.2382, name: 'Kakinada MPCS');

      final result = await routeService.calculateEvacuationRoutes(
        userLocation: userOrigin,
        shelterLocation: shelterDestination,
        disasterType: DisasterType.cyclone,
      );

      // Verify route was found
      expect(result.state, equals(RouteVerificationState.routeAvailable));
      expect(result.recommendedRoute, isNotNull);
      final route = result.recommendedRoute!;

      // Verify route has connected road segments (not 1 straight-line segment)
      expect(route.segments.length, greaterThanOrEqualTo(3));
      final roadNames = route.segments.map((s) => s.roadName).toList();
      debugPrint('[Test 1] Traversed road segments: $roadNames');

      // Verify avoidance of flooded Old Canal Causeway (K102)
      expect(roadNames.any((name) => name.contains('Old Canal Causeway')), isFalse);

      // Verify presence of intermediate road curvature coordinates
      expect(route.waypoints.length, greaterThanOrEqualTo(10));
      debugPrint('[Test 1] Waypoint coordinates count: ${route.waypoints.length}');

      // Verify road distance is strictly greater than straight-line Haversine distance
      final straightLineDist = userOrigin.distanceTo(shelterDestination);
      expect(route.totalDistanceKm, greaterThan(straightLineDist));
      debugPrint('[Test 1] Road distance: ${route.totalDistanceKm} km vs Straight-line: ${straightLineDist.toStringAsFixed(2)} km');

      // Verify turn instructions are genuine road maneuvers
      final turnInstructions = route.segments.map((s) => s.turnInstruction).whereType<String>().toList();
      expect(turnInstructions.any((t) => t.contains('Suryaraopeta') || t.contains('Main Road') || t.contains('Bypass')), isTrue);
      expect(turnInstructions.any((t) => t.contains('along bearing')), isFalse);
    });

    test('2. Urban Sector: Dijkstra calculates elevated bypass avoiding submerged Old Canal Road', () async {
      const userOrigin = GeoPoint(16.5062, 80.6480, name: 'Benz Circle');
      const shelterDestination = GeoPoint(16.5180, 80.6200, name: 'ZP High School Shelter');

      final result = await routeService.calculateEvacuationRoutes(
        userLocation: userOrigin,
        shelterLocation: shelterDestination,
        disasterType: DisasterType.flood,
      );

      expect(result.state, equals(RouteVerificationState.routeAvailable));
      expect(result.recommendedRoute, isNotNull);
      final route = result.recommendedRoute!;

      // Must avoid flooded Old Canal Road (R103)
      final roadNames = route.segments.map((s) => s.roadName).toList();
      expect(roadNames.any((name) => name.contains('Old Canal Road')), isFalse);

      // Must traverse elevated highway corridors (R201, R202, R203, R204)
      expect(roadNames.any((name) => name.contains('Elevated') || name.contains('Bypass')), isTrue);

      // Must have intermediate coordinates tracing road bends
      expect(route.waypoints.length, greaterThanOrEqualTo(8));

      // Road distance > Straight line
      final straightLineDist = userOrigin.distanceTo(shelterDestination);
      expect(route.totalDistanceKm, greaterThan(straightLineDist));
    });

    test('3. Safe Failure: Cross-district disconnected locations fail safely without straight lines', () async {
      // User in Vijayawada, Shelter in Kakinada (~176 km apart)
      const userOrigin = GeoPoint(16.5062, 80.6480, name: 'Benz Circle');
      const distantShelter = GeoPoint(16.9604, 82.2382, name: 'Kakinada MPCS');

      final result = await routeService.calculateEvacuationRoutes(
        userLocation: userOrigin,
        shelterLocation: distantShelter,
        disasterType: DisasterType.flood,
      );

      // MUST NOT return a fake straight-line route
      expect(result.state, equals(RouteVerificationState.noVerifiedRoute));
      expect(result.recommendedRoute, isNull);
      expect(result.allRoutes, isEmpty);

      // Status message must explain why
      expect(result.statusMessage.toLowerCase(), contains('no verified road route available'));
      debugPrint('[Test 3] Safe failure message: ${result.statusMessage}');
    });

    test('4. Safe Failure: Distant out-of-coverage coordinates fail safely', () async {
      // Hyderabad coordinate (>200 km from mapped coastal road graph)
      const distantOrigin = GeoPoint(17.3850, 78.4867, name: 'Hyderabad');
      const shelterDestination = GeoPoint(16.9604, 82.2382, name: 'Kakinada MPCS');

      final result = await routeService.calculateEvacuationRoutes(
        userLocation: distantOrigin,
        shelterLocation: shelterDestination,
        disasterType: DisasterType.flood,
      );

      expect(result.state, equals(RouteVerificationState.noVerifiedRoute));
      expect(result.recommendedRoute, isNull);
      expect(result.allRoutes, isEmpty);
    });

    test('5. Multi-Route: Safe alternative corridor discovered using connected road bypass', () async {
      const userOrigin = GeoPoint(16.9891, 82.2475, name: 'Suryaraopeta');
      const shelterDestination = GeoPoint(16.9604, 82.2382, name: 'Kakinada MPCS');

      final result = await routeService.calculateEvacuationRoutes(
        userLocation: userOrigin,
        shelterLocation: shelterDestination,
        disasterType: DisasterType.cyclone,
      );

      expect(result.allRoutes.length, greaterThanOrEqualTo(2));
      final altRoute = result.allRoutes[1];
      expect(altRoute.segments, isNotEmpty);
      expect(altRoute.waypoints.length, greaterThanOrEqualTo(8));
      expect(altRoute.isNavigableRoad, isTrue);
    });

    testWidgets('6. UI renders connected road graph and handles no-verified-route state gracefully',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: RoutingScreen()));
      await tester.pumpAndSettle();

      // Verify that map view is present
      expect(find.byType(EvacuationMapView), findsOneWidget);

      // Verify badge indicates ROAD NETWORK GRAPH
      expect(find.text('ROAD NETWORK GRAPH'), findsOneWidget);

      // Verify turn directives contain road names
      expect(find.text('Turn Directives'), findsOneWidget);
      expect(find.textContaining('Main Road'), findsWidgets);
    });
  });
}
