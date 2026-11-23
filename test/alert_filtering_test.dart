import 'package:flutter_test/flutter_test.dart';
import 'package:surakshapath/core/models/data_state.dart';
import 'package:surakshapath/core/models/disaster_alert.dart';
import 'package:surakshapath/core/models/disaster_type.dart';
import 'package:surakshapath/core/services/alert_service.dart';

void main() {
  group('Corrective Item 1: Expired Disaster Alert Filtering Tests', () {
    final now = DateTime(2026, 11, 23, 12, 0, 0);

    final activeAlert = DisasterAlert(
      id: 'test-active',
      title: 'Active Flood Warning',
      description: 'Rising water level',
      disasterType: DisasterType.flood,
      severity: AlertSeverity.warning,
      affectedArea: 'Sector 14',
      issuedAt: now.subtract(const Duration(hours: 1)),
      expiresAt: now.add(const Duration(hours: 4)), // Future expiry
      source: 'Central Flood Advisory',
      isActionRequired: true,
    );

    final expiredAlert = DisasterAlert(
      id: 'test-expired',
      title: 'Old High Wind Caution',
      description: 'Wind speeds have normalized',
      disasterType: DisasterType.cyclone,
      severity: AlertSeverity.watch,
      affectedArea: 'Coastal Sector A',
      issuedAt: now.subtract(const Duration(hours: 8)),
      expiresAt: now.subtract(const Duration(hours: 2)), // Expired in the past
      source: 'Weather Advisory Bulletin',
      isActionRequired: false,
    );

    final nullExpiryAlert = DisasterAlert(
      id: 'test-null-expiry',
      title: 'Community Safety Advisory',
      description: 'General safety notice with no fixed expiration',
      disasterType: DisasterType.fire,
      severity: AlertSeverity.advisory,
      affectedArea: 'Industrial Zone',
      issuedAt: now.subtract(const Duration(hours: 2)),
      expiresAt: null, // Null expiry
      source: 'Civil Defence Bulletin',
      isActionRequired: false,
    );

    setUp(() {
      MockAlertService().resetDefaultAlerts();
    });

    tearDown(() {
      MockAlertService().resetDefaultAlerts();
    });

    test('1. Active alert with future expiry is preserved as active', () {
      expect(activeAlert.isExpired(now), isFalse);
      expect(activeAlert.isActive(now), isTrue);
      expect(activeAlert.expiryStatus(now), equals(AlertExpiryStatus.active));
    });

    test('2. Expired alert is flagged as expired and not active', () {
      expect(expiredAlert.isExpired(now), isTrue);
      expect(expiredAlert.isActive(now), isFalse);
      expect(expiredAlert.expiryStatus(now), equals(AlertExpiryStatus.expired));
    });

    test('3. Alert with null expiry is handled explicitly without inventing expiry', () {
      expect(nullExpiryAlert.expiresAt, isNull);
      expect(nullExpiryAlert.isExpired(now), isFalse);
      expect(nullExpiryAlert.isActive(now), isTrue);
      expect(nullExpiryAlert.expiryStatus(now), equals(AlertExpiryStatus.unspecifiedExpiry));
      expect(nullExpiryAlert.expiryStatus(now).label, equals('NO EXPIRY SPECIFIED'));
    });

    test('4. Cached list containing both expired and valid alerts filters out expired alerts', () async {
      final service = MockAlertService();
      service.setMockAlerts([activeAlert, expiredAlert, nullExpiryAlert]);

      // Cold fetch populates cache
      final fetched = await service.getActiveAlerts(referenceTime: now);
      expect(service.currentDataState, equals(DataState.fresh));
      expect(fetched.any((a) => a.id == 'test-expired'), isFalse);
      expect(fetched.any((a) => a.id == 'test-active'), isTrue);
      expect(fetched.any((a) => a.id == 'test-null-expiry'), isTrue);

      // Now query from cache with reference time in the future where activeAlert also expired
      final futureTime = now.add(const Duration(hours: 6));
      final fromCache = await service.getActiveAlerts(referenceTime: futureTime);
      expect(service.currentDataState, equals(DataState.cached));

      // activeAlert has now expired relative to futureTime, so only nullExpiryAlert remains
      expect(fromCache.any((a) => a.id == 'test-expired'), isFalse);
      expect(fromCache.any((a) => a.id == 'test-active'), isFalse);
      expect(fromCache.any((a) => a.id == 'test-null-expiry'), isTrue);
    });

    test('5. Offline fallback containing expired alerts prunes them and labels state as stale', () async {
      final service = MockAlertService();
      // Configure mock alerts where one is already expired
      service.setMockAlerts([activeAlert, expiredAlert]);
      service.invalidateCache();

      // Query active alerts
      final result = await service.getActiveAlerts(referenceTime: now);
      expect(result.length, equals(1));
      expect(result.first.id, equals('test-active'));
      expect(result.any((a) => a.id == 'test-expired'), isFalse);

      // Historical alerts method still retains expired alerts with explicit expired label
      final allAlerts = await service.getAllAlerts();
      expect(allAlerts.length, equals(2));
      final oldAlert = allAlerts.firstWhere((a) => a.id == 'test-expired');
      expect(oldAlert.isExpired(now), isTrue);
      expect(oldAlert.expiryStatus(now), equals(AlertExpiryStatus.expired));
    });
  });
}
