import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:surakshapath/features/map/location_service.dart';
import 'package:surakshapath/features/map/offline_map_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Initialize sqflite ffi for desktop/test runner
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('OfflineMapService Tests (MapLibre + OpenFreeMap)', () {
    late OfflineMapService offlineMapService;

    setUp(() {
      offlineMapService = OfflineMapService();
    });

    tearDown(() {
      offlineMapService.dispose();
    });

    test('1. Andhra Pradesh center and OpenFreeMap attribution are correctly configured', () {
      expect(OfflineMapService.apCenterLat, closeTo(15.9129, 0.001));
      expect(OfflineMapService.apCenterLon, closeTo(79.7400, 0.001));
      expect(OfflineMapService.apInitialZoom, equals(6.8));
      expect(OfflineMapService.openFreeMapStyleUrl, equals('https://tiles.openfreemap.org/styles/liberty'));
      expect(OfflineMapService.mapAttribution, contains('OpenFreeMap'));
      expect(OfflineMapService.mapAttribution, contains('OpenStreetMap'));
    });

    test('2. OpenFreeMap download limits strictly enforce <= 3,000 tiles limit', () {
      expect(OfflineMapService.maxPermittedTilesPerDownload, equals(3000));
      expect(OfflineMapService.maxPermittedMbPerDownload, equals(50.0));

      for (final region in OfflineMapService.predefinedRegions) {
        expect(
          region.estimatedTiles,
          lessThanOrEqualTo(OfflineMapService.maxPermittedTilesPerDownload),
          reason: '${region.name} exceeds permitted OpenFreeMap limit of 3000 tiles',
        );
      }
    });

    test('3. Tile estimator accurately calculates Web Mercator tile counts', () {
      final count = OfflineMapService.estimateTileCount(
        minLat: 16.48,
        maxLat: 16.55,
        minLon: 80.60,
        maxLon: 80.68,
        minZoom: 11.0,
        maxZoom: 13.0,
      );

      expect(count, greaterThan(0));
      expect(count, lessThanOrEqualTo(1000));
    });

    test('4. All saved demo shelters are explicitly marked as unverified placeholders', () async {
      final shelters = await offlineMapService.getSavedShelters();
      expect(shelters, isNotEmpty);
      expect(shelters.length, greaterThanOrEqualTo(2));

      for (final shelter in shelters) {
        expect(shelter.isVerified, isFalse,
            reason: '${shelter.name} must NOT be flagged as verified without official audit');
        expect(shelter.notes, contains('DEMO'),
            reason: '${shelter.name} must carry a prominent demo warning in notes');
        expect(shelter.latitude, isNotNull);
        expect(shelter.longitude, isNotNull);
      }
    });

    test('5. Reconciled shelter filters correctly filter by pets allowed and accessibility', () async {
      final allShelters = await offlineMapService.getSavedShelters();
      final petShelters = await offlineMapService.getSavedShelters(petsAllowed: true);
      final accessibleShelters = await offlineMapService.getSavedShelters(accessible: true);

      expect(allShelters.length, greaterThanOrEqualTo(petShelters.length));
      expect(allShelters.length, greaterThanOrEqualTo(accessibleShelters.length));

      for (final s in petShelters) {
        expect(s.hasPetsAllowed, isTrue);
      }
      for (final s in accessibleShelters) {
        expect(s.isAccessible, isTrue);
      }
    });

    test('6. Tile quota guard strictly rejects download requests over 3000 tiles', () async {
      const oversizedRegion = OfflineRegionDefinitionItem(
        id: 'oversized_test_region',
        name: 'Oversized Test Region',
        description: 'Exceeds quota',
        minLat: 12.0,
        maxLat: 20.0,
        minLon: 75.0,
        maxLon: 85.0,
        minZoom: 1.0,
        maxZoom: 15.0,
        estimatedTiles: 150000,
        estimatedSizeMb: 500.0,
      );

      final events = await offlineMapService.downloadRegion(oversizedRegion).toList();
      expect(events, isNotEmpty);
      expect(events.first.hasError, isTrue);
      expect(events.first.error, equals('Tile limit exceeded'));
      expect(events.first.isCompleted, isFalse);
    });

    test('7. Failed download does NOT create a downloaded region record in SQLite', () async {
      const failItem = OfflineRegionDefinitionItem(
        id: 'fail_test_item',
        name: 'Failure Test Sector',
        description: 'Should fail gracefully without fake records',
        minLat: 16.0,
        maxLat: 16.1,
        minLon: 80.0,
        maxLon: 80.1,
        minZoom: 11.0,
        maxZoom: 12.0,
        estimatedTiles: 50,
        estimatedSizeMb: 1.0,
      );

      final events = await offlineMapService.downloadRegion(failItem).toList();
      expect(events, isNotEmpty);

      // Verify no record was saved to SQLite
      final downloaded = await offlineMapService.getDownloadedRegions();
      expect(downloaded.any((d) => d.id == failItem.id), isFalse);
    });
  });

  group('LocationResult Model & Error Classification Tests', () {
    test('8. LocationResult.failure properly encapsulates error type and instructions', () {
      final result = LocationResult.failure(
        LocationErrorType.serviceDisabled,
        'GPS is turned off.',
      );

      expect(result.isSuccess, isFalse);
      expect(result.position, isNull);
      expect(result.errorType, equals(LocationErrorType.serviceDisabled));
      expect(result.errorMessage, equals('GPS is turned off.'));
    });
  });
}
