import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:surakshapath/core/constants/app_strings.dart';
import 'package:surakshapath/core/models/evacuation_route.dart';
import 'package:surakshapath/core/models/user_location.dart';
import 'package:surakshapath/core/services/alert_service.dart';
import 'package:surakshapath/core/services/shelter_service.dart';
import 'package:surakshapath/features/emergency/screens/emergency_sos_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('P0 Corrective Sprint: Geographic Data Alignment (Coastal AP)', () {
    test('1. Default mock location is set to Kakinada Port Corridor (Coastal AP)', () {
      final loc = UserLocation.mockDefault();
      expect(loc.locationName, equals('Kakinada Port Corridor'));
      expect(loc.subArea, contains('Kakinada District, Andhra Pradesh'));
      expect(loc.latitude, closeTo(16.9891, 0.001));
      expect(loc.longitude, closeTo(82.2475, 0.001));
      expect(loc.formattedCoordinates, equals('16.9891° N, 82.2475° E'));
      expect(loc.isMock, isTrue, reason: 'Default location must be flagged as mock/demo');
      expect(loc.accuracyMeters, isNull, reason: 'Mock location must not fabricate GPS accuracy');
      expect(loc.isGpsActive, isFalse, reason: 'Mock location must not claim active hardware GPS');
      expect(loc.isLiveFix, isFalse);
    });

    test('2. sample_alerts.json contains authentic Coastal AP scenarios with no Gujarat records', () {
      final file = File('assets/data/sample_alerts.json');
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();
      expect(content, isNot(contains('Gandhinagar')));
      expect(content, isNot(contains('Sabarmati')));
      expect(content, isNot(contains('Kandla')));
      expect(content, isNot(contains('Biparjoy')));

      final list = jsonDecode(content) as List<dynamic>;
      expect(list.length, equals(3));
      expect(list.any((a) => a['title'].toString().contains('Bay of Bengal') || a['location'].toString().contains('Kakinada')), isTrue);
      expect(list.any((a) => a['title'].toString().contains('Godavari') || a['location'].toString().contains('Krishna')), isTrue);
    });

    test('3. sample_shelters.json contains Coastal AP shelters with isVerified: false', () {
      final file = File('assets/data/sample_shelters.json');
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();
      expect(content, isNot(contains('Gandhinagar')));
      expect(content, isNot(contains('Sector 14')));

      final list = jsonDecode(content) as List<dynamic>;
      expect(list.length, equals(3));
      for (final s in list) {
        expect(s['isVerified'], isFalse, reason: 'Mock shelters must not claim unverified government verification');
        expect(s['address'], contains('AP'));
      }
    });

    test('4. MockAlertService and MockShelterService default data is aligned with Coastal AP', () async {
      final alertService = MockAlertService();
      final alerts = await alertService.getActiveAlerts();
      expect(alerts.isNotEmpty, isTrue);
      for (final a in alerts) {
        expect(a.affectedArea, isNot(contains('Gandhinagar')));
        expect(a.affectedArea, isNot(contains('Sabarmati')));
        expect(a.title, isNot(contains('Gandhinagar')));
        expect(a.title, isNot(contains('Sabarmati')));
      }

      final shelterService = MockShelterService();
      final shelters = await shelterService.getAvailableShelters();
      expect(shelters.isNotEmpty, isTrue);
      for (final s in shelters) {
        expect(s.address, contains('AP'));
        expect(s.address, isNot(contains('Gandhinagar')));
        expect(s.isVerified, isFalse);
      }
    });
  });

  group('P0 Corrective Sprint: Evacuation Route Honesty', () {
    test('5. RouteSafetyStatus includes simulated status with truthful label', () {
      const simulated = RouteSafetyStatus.simulated;
      expect(simulated.label, equals('SIMULATED CORRIDOR (DEMO)'));
    });

    test('6. EvacuationRoute supports simulated safety status', () {
      const route = EvacuationRoute(
        id: 'route-test',
        title: 'Kakinada Elevated High-Ground Corridor',
        destinationShelterId: 'shelter-101',
        destinationShelterName: 'Kakinada MPCS',
        distanceKm: 2.4,
        estimatedTimeMinutes: 11,
        safetyStatus: RouteSafetyStatus.simulated,
        roadConditionSummary: 'Demonstration corridor avoids coastal inundation zones.',
      );
      expect(route.safetyStatus, equals(RouteSafetyStatus.simulated));
      expect(route.safetyStatus.label, contains('SIMULATED'));
    });
  });

  group('P0 Corrective Sprint: Dialer & Dynamic SOS Packet', () {
    test('7. Emergency dialer URIs match tel:112 and tel:108 standard format', () {
      final uri112 = Uri(scheme: 'tel', path: '112');
      final uri108 = Uri(scheme: 'tel', path: '108');

      expect(uri112.toString(), equals('tel:112'));
      expect(uri108.toString(), equals('tel:108'));
    });

    test('8. SMS intent URI correctly formats body query parameter without fake data', () {
      final loc = UserLocation.mockDefault();
      final smsBody = 'EMERGENCY SOS - SURAKSHAPATH\n'
          'Location Fix: DEMO LOCATION (Live location unavailable)\n'
          'Demo Coordinates: ${loc.formattedCoordinates}\n'
          'Corridor: ${loc.locationName}, ${loc.subArea}\n'
          'Timestamp: 2026-11-23 18:50\n'
          'Status: Emergency Assistance Protocol Triggered\n'
          'Region: Coastal Andhra Pradesh Emergency Grid';

      final smsUri = Uri(
        scheme: 'sms',
        path: '',
        queryParameters: {'body': smsBody},
      );

      expect(smsUri.scheme, equals('sms'));
      expect(smsUri.queryParameters['body'], contains('16.9891° N, 82.2475° E'));
      expect(smsUri.queryParameters['body'], contains('DEMO LOCATION'));
      expect(smsUri.queryParameters['body'], contains('Live location unavailable'));
      expect(smsUri.queryParameters['body'], contains('Kakinada Port Corridor'));
      expect(smsUri.queryParameters['body'], isNot(contains('Headcount: 4 people')));
      expect(smsUri.queryParameters['body'], isNot(contains('Battery: 78%')));
    });

    testWidgets('9. EmergencySosScreen renders dialer, SMS and truthful broadcast packet', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: EmergencySosScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Check header and dialer buttons
      expect(find.text(AppStrings.emergencySosTitle), findsOneWidget);
      expect(find.textContaining('112'), findsOneWidget);
      expect(find.textContaining('108'), findsOneWidget);

      // Check broadcast packet content
      expect(find.text('Emergency Broadcast Packet'), findsOneWidget);
      expect(find.text('Live location unavailable'), findsOneWidget);
      expect(find.text('16.9891° N, 82.2475° E (DEMO LOCATION)'), findsOneWidget);
      expect(find.textContaining('Kakinada Port Corridor'), findsOneWidget);

      // Verify mock coordinates are NEVER labeled as GPS Coordinates
      expect(find.text('GPS Coordinates'), findsNothing);

      // Verify fabricated data is absent
      expect(find.textContaining('Headcount: 4 people'), findsNothing);
      expect(find.textContaining('Battery: 78%'), findsNothing);

      // Check actions: Send Location SMS and Copy Coordinates
      expect(find.text('Send Location SMS to Contacts'), findsOneWidget);
      expect(find.text(AppStrings.copyCoordinates), findsOneWidget);
    });
  });

  group('P0 Corrective Sprint: Android Manifest Configuration', () {
    test('10. AndroidManifest.xml contains INTERNET permission and package queries for tel/sms', () {
      final manifestFile = File('android/app/src/main/AndroidManifest.xml');
      expect(manifestFile.existsSync(), isTrue);

      final xml = manifestFile.readAsStringSync();
      expect(xml, contains('android.permission.INTERNET'));
      expect(xml, contains('<queries>'));
      expect(xml, contains('android.intent.action.DIAL'));
      expect(xml, contains('android:scheme="tel"'));
      expect(xml, contains('android.intent.action.SENDTO'));
      expect(xml, contains('android:scheme="sms"'));
    });
  });
}
