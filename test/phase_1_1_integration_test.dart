import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:surakshapath/core/constants/app_strings.dart';
import 'package:surakshapath/core/models/user_location.dart';
import 'package:surakshapath/core/services/locale_service.dart';
import 'package:surakshapath/core/services/user_profile_service.dart';
import 'package:surakshapath/core/widgets/app_header.dart';
import 'package:surakshapath/features/emergency/screens/emergency_sos_screen.dart';
import 'package:surakshapath/features/home/screens/home_screen.dart';
import 'package:surakshapath/features/map/screens/map_screen.dart';
import 'package:surakshapath/features/shelters/screens/shelters_screen.dart';
import 'package:surakshapath/navigation/main_navigation_shell.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocaleService.init();
    await UserProfileService.init();
  });

  group('SurakshaPath Phase 1.1 Integration Tests', () {
    testWidgets('1. Persisted GPS location appears on Home without fabrication', (WidgetTester tester) async {
      // Setup verified live GPS location
      final liveGps = UserLocation.live(
        latitude: 17.6868,
        longitude: 83.2185,
        locationName: 'Visakhapatnam Harbor Sector',
        subArea: 'Visakhapatnam District, Andhra Pradesh',
        accuracyMeters: 8.5,
      );
      await UserProfileService.updateLocation(liveGps);

      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Home displays the live GPS location name and telemetry
      expect(find.text('Visakhapatnam Harbor Sector'), findsOneWidget);
      expect(find.textContaining('±8.5m'), findsOneWidget);
      expect(find.text('LIVE GPS FIX'), findsOneWidget);
    });

    testWidgets('2. Map screen receives the exact same saved location', (WidgetTester tester) async {
      // Setup manually selected location
      final manualLoc = UserLocation.manual(
        latitude: 16.5062,
        longitude: 80.6480,
        locationName: 'Vijayawada Central',
        subArea: 'Krishna District, Andhra Pradesh',
      );
      await UserProfileService.updateLocation(manualLoc);

      await tester.pumpWidget(
        const MaterialApp(
          home: MapScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Recenter FAB taps and reports the saved location
      final recenterFab = find.byType(FloatingActionButton);
      expect(recenterFab, findsOneWidget);
      await tester.tap(recenterFab);
      await tester.pump();

      // SnackBar reflects MANUALLY SELECTED and Vijayawada Central
      expect(find.textContaining('MANUALLY SELECTED: Vijayawada Central'), findsOneWidget);
    });

    testWidgets('3. Mock location does NOT overwrite live GPS on Home dashboard', (WidgetTester tester) async {
      // User acquired authentic satellite lock
      final liveGps = UserLocation.live(
        latitude: 16.9891,
        longitude: 82.2475,
        locationName: 'Kakinada Live Satellite Lock',
        subArea: 'Kakinada District, AP',
        accuracyMeters: 4.2,
      );
      await UserProfileService.updateLocation(liveGps);

      // Launch Home with no mock service override (production behavior)
      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // Live GPS must remain intact
      expect(find.text('Kakinada Live Satellite Lock'), findsOneWidget);
      expect(find.text('LIVE GPS FIX'), findsOneWidget);
      expect(UserProfileService.currentLocation.isLiveFix, isTrue);
    });

    testWidgets('4. Location provenance labels display honestly (live, manual, demo)', (WidgetTester tester) async {
      // Case A: Demo baseline
      await UserProfileService.updateLocation(UserLocation.mockDefault());
      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await tester.pumpAndSettle();
      expect(find.text('DEMO LOCATION'), findsOneWidget);

      // Case B: Manual corridor
      final manual = UserLocation.manual(
        latitude: 15.9042,
        longitude: 80.4674,
        locationName: 'Bapatla Coastal Sector',
        subArea: 'Bapatla District, AP',
      );
      await UserProfileService.updateLocation(manual);
      await tester.pumpAndSettle();
      expect(find.text('MANUALLY SELECTED'), findsOneWidget);

      // Case C: Live GPS Fix
      final live = UserLocation.live(
        latitude: 15.5057,
        longitude: 80.0499,
        locationName: 'Ongole Coastal Sector',
        subArea: 'Prakasam District, AP',
        accuracyMeters: 12.0,
      );
      await UserProfileService.updateLocation(live);
      await tester.pumpAndSettle();
      expect(find.text('LIVE GPS FIX'), findsOneWidget);
    });

    testWidgets('5. Profile edits survive simulated application restart', (WidgetTester tester) async {
      final initialPrefs = <String, Object>{};
      SharedPreferences.setMockInitialValues(initialPrefs);
      final prefs = await SharedPreferences.getInstance();
      await UserProfileService.init(prefs);

      // User updates profile
      await UserProfileService.updateHeadcount(
        adults: 3,
        children: 2,
        seniors: 1,
        pets: 2,
        needsMobilityAssistance: true,
      );
      final loc = UserLocation.manual(
        latitude: 14.4426,
        longitude: 79.9865,
        locationName: 'Nellore Coastal Zone',
        subArea: 'SPSR Nellore District, AP',
      );
      await UserProfileService.updateLocation(loc);

      // Simulate app kill & cold restart with persisted shared preferences
      final storedJson = prefs.getString(UserProfileService.preferenceKey);
      expect(storedJson, isNotNull);

      SharedPreferences.setMockInitialValues({
        UserProfileService.preferenceKey: storedJson!,
      });
      final restartPrefs = await SharedPreferences.getInstance();
      await UserProfileService.init(restartPrefs);

      final restored = UserProfileService.currentProfile;
      expect(restored.adults, equals(3));
      expect(restored.children, equals(2));
      expect(restored.seniors, equals(1));
      expect(restored.pets, equals(2));
      expect(restored.totalPeople, equals(6));
      expect(restored.needsMobilityAssistance, isTrue);
      expect(restored.location?.locationName, equals('Nellore Coastal Zone'));
      expect(restored.location?.provenance, equals(LocationProvenance.manualSelection));
    });

    testWidgets('6. Family headcount updates appear dynamically in Emergency SOS packet', (WidgetTester tester) async {
      await UserProfileService.updateHeadcount(
        adults: 4,
        children: 1,
        seniors: 2,
        pets: 3,
        needsMobilityAssistance: true,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: EmergencySosScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Assert broadcast details card contains dynamic headcount
      expect(find.textContaining('7 people (4A, 1C, 2S)'), findsOneWidget);
      expect(find.text('3'), findsOneWidget); // Pets
      expect(find.text('Required (Wheelchair)'), findsOneWidget);
    });

    testWidgets('7. Shelters filter by Pets Allowed and Accessible options', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SheltersScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Find Pets Allowed filter chip and tap it
      final petsChip = find.text('Pets Allowed');
      expect(petsChip, findsOneWidget);
      await tester.tap(petsChip);
      await tester.pumpAndSettle();

      // Only Uppada Center allows pets
      expect(find.text('Uppada Coastal Cyclone Relief Center'), findsOneWidget);
      expect(find.text('Kakinada Multi-Purpose Cyclone Shelter (MPCS)'), findsNothing);

      // Find Accessible filter chip and tap it
      final accessibleChip = find.text('Accessible');
      expect(accessibleChip, findsOneWidget);
      await tester.tap(accessibleChip);
      await tester.pumpAndSettle();

      // Kakinada and Bhavani Island are wheelchair accessible
      expect(find.text('Kakinada Multi-Purpose Cyclone Shelter (MPCS)'), findsOneWidget);
      expect(find.text('Bhavani Island Community Center'), findsOneWidget);
      expect(find.text('Uppada Coastal Cyclone Relief Center'), findsNothing);
    });

    testWidgets('8. Responsive layout verification at 320dp, 360dp, and 390dp widths', (WidgetTester tester) async {
      final widths = [320.0, 360.0, 390.0];

      for (final width in widths) {
        tester.view.physicalSize = Size(width * 2.0, 800.0 * 2.0);
        tester.view.devicePixelRatio = 2.0;

        await tester.pumpWidget(
          const MaterialApp(
            home: MainNavigationShell(),
          ),
        );
        await tester.pumpAndSettle();

        // Verify AppHeader branding renders with zero RenderFlex overflow
        expect(find.text(AppStrings.appName), findsOneWidget);
        expect(find.byIcon(Icons.person_outline_rounded), findsOneWidget);
        expect(find.text(AppStrings.navHome), findsOneWidget);
        expect(find.text(AppStrings.navMap), findsOneWidget);
        expect(find.text(AppStrings.navAlerts), findsOneWidget);
        expect(tester.takeException(), isNull);
      }

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });
}
