import 'package:flutter_test/flutter_test.dart';
import 'package:surakshapath/core/models/disaster_type.dart';
import 'package:surakshapath/core/services/alert_service.dart';
import 'package:surakshapath/core/services/location_service.dart';
import 'package:surakshapath/core/services/shelter_service.dart';

void main() {
  group('Phase 4 & 5 Service Optimization Tests', () {
    test('MockAlertService in-memory TTL caching and cache invalidation', () async {
      final service1 = MockAlertService();
      final service2 = MockAlertService();

      // Factory pattern guarantees singleton instance across components
      expect(identical(service1, service2), isTrue);

      service1.invalidateCache();
      expect(service1.isCacheValid, isFalse);

      final stopwatch = Stopwatch()..start();
      final alerts1 = await service1.getActiveAlerts();
      stopwatch.stop();

      expect(alerts1.isNotEmpty, isTrue);
      expect(service1.isCacheValid, isTrue);
      expect(service1.lastFetchTime, isNotNull);

      // Second call must resolve immediately via cache (0ms simulated latency)
      stopwatch.reset();
      stopwatch.start();
      final alerts2 = await service2.getActiveAlerts();
      stopwatch.stop();

      expect(alerts2.length, equals(alerts1.length));
      expect(stopwatch.elapsedMilliseconds, lessThan(50));

      // Filtering by disaster type reuses cache
      final floodAlerts = await service1.getAlertsByDisaster(DisasterType.flood);
      expect(floodAlerts.every((a) => a.disasterType == DisasterType.flood), isTrue);
    });

    test('MockShelterService in-memory TTL caching and query safety', () async {
      final shelterService = MockShelterService();
      shelterService.invalidateCache();

      final shelters = await shelterService.getAvailableShelters();
      expect(shelters.isNotEmpty, isTrue);
      expect(shelterService.isCacheValid, isTrue);

      final closest = await shelterService.getClosestSafeShelter();
      expect(closest, isNotNull);
      expect(closest!.name, anyOf(contains('Shelter'), contains('Relief')));
    });

    test('MockLocationService lifecycle pause/resume functionality', () async {
      final locationService = MockLocationService();
      expect(locationService.isTrackingPaused, isFalse);

      // Simulate app backgrounding
      locationService.pauseTracking();
      expect(locationService.isTrackingPaused, isTrue);

      // When paused, location fetch returns immediate cached coordinates without sensor polling
      final loc = await locationService.getCurrentLocation();
      expect(loc.latitude, isNotNull);
      expect(loc.longitude, isNotNull);

      // Stream yields nothing when paused to conserve battery
      final streamEvents = await locationService.getLocationStream().toList();
      expect(streamEvents.isEmpty, isTrue);

      // Simulate app foregrounding
      locationService.resumeTracking();
      expect(locationService.isTrackingPaused, isFalse);

      final activeStreamEvents = await locationService.getLocationStream().toList();
      expect(activeStreamEvents.isNotEmpty, isTrue);
    });
  });
}
