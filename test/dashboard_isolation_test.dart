import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:surakshapath/core/models/disaster_alert.dart';
import 'package:surakshapath/core/models/disaster_type.dart';
import 'package:surakshapath/core/models/shelter_model.dart';
import 'package:surakshapath/core/models/user_location.dart';
import 'package:surakshapath/core/services/alert_service.dart';
import 'package:surakshapath/core/services/location_service.dart';
import 'package:surakshapath/core/services/shelter_service.dart';
import 'package:surakshapath/features/home/screens/home_screen.dart';

// --- MOCK SERVICES FOR TESTING ISOLATION ---

class FailingLocationService implements ILocationService {
  @override
  Future<UserLocation> getCurrentLocation() async {
    throw Exception('Simulated GPS hardware failure');
  }

  @override
  Stream<UserLocation> getLocationStream() async* {
    throw Exception('Simulated GPS stream failure');
  }

  @override
  bool isGpsEnabled() => false;
}

class FailingAlertService implements IAlertService {
  @override
  Future<List<DisasterAlert>> getActiveAlerts({
    bool forceRefresh = false,
    DateTime? referenceTime,
  }) async {
    throw Exception('Simulated Alert API timeout');
  }

  @override
  Future<List<DisasterAlert>> getAlertsByDisaster(DisasterType type) async {
    throw Exception('Simulated Alert API error');
  }

  @override
  Future<DisasterAlert?> getHighestSeverityAlert() async {
    throw Exception('Simulated Alert API error');
  }
}

class FailingShelterService implements IShelterService {
  @override
  Future<List<ShelterModel>> getAvailableShelters({bool forceRefresh = false}) async {
    throw Exception('Simulated Shelter DB offline');
  }

  @override
  Future<ShelterModel?> getClosestSafeShelter([double? userLat, double? userLng]) async {
    throw Exception('Simulated Shelter query error');
  }

  @override
  Future<ShelterModel?> getShelterById(String id) async {
    throw Exception('Simulated Shelter query error');
  }
}

class WorkingLocationService implements ILocationService {
  @override
  Future<UserLocation> getCurrentLocation() async {
    return UserLocation(
      latitude: 16.5062,
      longitude: 80.6480,
      locationName: 'Benz Circle Corridor',
      subArea: 'Krishna District, AP',
      accuracyMeters: 5.0,
      timestamp: DateTime.now(),
      isGpsActive: true,
    );
  }

  @override
  Stream<UserLocation> getLocationStream() async* {}

  @override
  bool isGpsEnabled() => true;
}

class WorkingAlertService implements IAlertService {
  @override
  Future<List<DisasterAlert>> getActiveAlerts({
    bool forceRefresh = false,
    DateTime? referenceTime,
  }) async {
    return [
      DisasterAlert(
        id: 'mock-alert-1',
        title: 'Working Flood Warning Test',
        description: 'Test flood warning description',
        disasterType: DisasterType.flood,
        severity: AlertSeverity.warning,
        affectedArea: 'Sector 14',
        issuedAt: DateTime.now().subtract(const Duration(minutes: 10)),
        expiresAt: DateTime.now().add(const Duration(hours: 6)),
        source: 'Test Disaster Source',
        isActionRequired: true,
      ),
    ];
  }

  @override
  Future<List<DisasterAlert>> getAlertsByDisaster(DisasterType type) async => [];

  @override
  Future<DisasterAlert?> getHighestSeverityAlert() async => null;
}

class WorkingShelterService implements IShelterService {
  @override
  Future<List<ShelterModel>> getAvailableShelters({bool forceRefresh = false}) async => [];

  @override
  Future<ShelterModel?> getClosestSafeShelter([double? userLat, double? userLng]) async {
    return const ShelterModel(
      id: 'shelter-working',
      name: 'Working Safe Shelter Camp',
      address: 'Civil Lines, Near Clock Tower',
      latitude: 16.5100,
      longitude: 80.6500,
      distanceKm: 1.4,
      capacityTotal: 300,
      capacityOccupied: 110,
      status: ShelterStatus.open,
      isVerified: true,
      contactNumber: '+91 79 1234 5678',
      facilities: ['Drinking Water', 'First Aid'],
    );
  }

  @override
  Future<ShelterModel?> getShelterById(String id) async => null;
}

void main() {
  Widget buildTestableWidget({
    ILocationService? locationService,
    IAlertService? alertService,
    IShelterService? shelterService,
  }) {
    return MaterialApp(
      home: HomeScreen(
        locationService: locationService ?? WorkingLocationService(),
        alertService: alertService ?? WorkingAlertService(),
        shelterService: shelterService ?? WorkingShelterService(),
      ),
    );
  }

  group('Corrective Item 2: Dashboard Failure Isolation Tests', () {
    testWidgets('Location failure does NOT prevent alerts and shelters from rendering',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableWidget(
        locationService: FailingLocationService(),
        alertService: WorkingAlertService(),
        shelterService: WorkingShelterService(),
      ));
      await tester.pumpAndSettle();

      // Location displays explicit failure without hiding behind misleading normal data
      expect(find.text('Location Unavailable'), findsOneWidget);
      expect(find.text('GPS fix failed • Tap refresh icon to retry'), findsOneWidget);

      // Shelters still successfully loaded and displayed
      expect(find.text('Working Safe Shelter Camp'), findsOneWidget);

      // Alerts still successfully loaded and displayed
      expect(find.text('Working Flood Warning Test'), findsOneWidget);
    });

    testWidgets('Alert failure does NOT prevent location and shelters from rendering',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableWidget(
        locationService: WorkingLocationService(),
        alertService: FailingAlertService(),
        shelterService: WorkingShelterService(),
      ));
      await tester.pumpAndSettle();

      // Alerts displays honest error message
      expect(find.text('Unable to load emergency alerts. Pull to retry.'), findsOneWidget);

      // Location still successfully loaded
      expect(find.text('Benz Circle Corridor'), findsWidgets);

      // Shelter still successfully loaded
      expect(find.text('Working Safe Shelter Camp'), findsOneWidget);
    });

    testWidgets('Shelter failure does NOT prevent location and alerts from rendering',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableWidget(
        locationService: WorkingLocationService(),
        alertService: WorkingAlertService(),
        shelterService: FailingShelterService(),
      ));
      await tester.pumpAndSettle();

      // Shelter displays explicit unavailable state
      expect(
        find.text('Shelter directory currently unavailable. Pull to retry.'),
        findsOneWidget,
      );

      // Location still successfully loaded
      expect(find.text('Benz Circle Corridor'), findsWidgets);

      // Alerts still successfully loaded
      expect(find.text('Working Flood Warning Test'), findsOneWidget);
    });

    testWidgets('All services working properly renders complete dashboard',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableWidget(
        locationService: WorkingLocationService(),
        alertService: WorkingAlertService(),
        shelterService: WorkingShelterService(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Location Unavailable'), findsNothing);
      expect(find.text('Unable to load emergency alerts. Pull to retry.'), findsNothing);
      expect(find.text('Shelter directory currently unavailable. Pull to retry.'), findsNothing);

      expect(find.text('Working Safe Shelter Camp'), findsOneWidget);
      expect(find.text('Working Flood Warning Test'), findsOneWidget);
    });
  });
}
