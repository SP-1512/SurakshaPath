import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:surakshapath/app/app.dart';
import 'package:surakshapath/core/models/user_location.dart';
import 'package:surakshapath/core/models/user_profile.dart';
import 'package:surakshapath/core/services/locale_service.dart';
import 'package:surakshapath/core/services/location_service.dart';
import 'package:surakshapath/core/services/user_profile_service.dart';
import 'package:surakshapath/features/emergency/screens/emergency_sos_screen.dart';
import 'package:surakshapath/features/onboarding/screens/onboarding_screen.dart';
import 'package:surakshapath/features/onboarding/screens/splash_screen.dart';
import 'package:surakshapath/navigation/main_navigation_shell.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockLocationService mockLocationService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocaleService.init();
    await LocaleService.setLocale('en');
    await UserProfileService.init();
    mockLocationService = MockLocationService();
    mockLocationService.resetDefaults();
  });

  group('SurakshaPath Complete Onboarding Verification Tests', () {
    testWidgets('1. First launch with uncompleted onboarding shows Splash/Onboarding flow',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await UserProfileService.reset();
      expect(UserProfileService.isOnboardingCompleted, isFalse);

      await tester.pumpWidget(const SurakshaPathApp());
      await tester.pump();

      // On initial unconfigured launch, SplashScreen is rendered
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.byType(MainNavigationShell), findsNothing);

      // Advance past splash timer
      await tester.pump(const Duration(milliseconds: 2300));
      await tester.pumpAndSettle();

      // Transitions into OnboardingScreen
      expect(find.byType(OnboardingScreen), findsOneWidget);
    });

    testWidgets('2. Language selection persists across restarts', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: OnboardingScreen(locationService: mockLocationService),
        ),
      );
      await tester.pumpAndSettle();

      // Verify language options are visible
      expect(find.text('Choose your language'), findsOneWidget);
      expect(find.text('తెలుగు (Telugu)'), findsOneWidget);

      // Select Telugu
      await tester.tap(find.text('తెలుగు (Telugu)'));
      await tester.pumpAndSettle();

      expect(LocaleService.currentLocale.value, equals('te'));
      expect(UserProfileService.currentProfile.selectedLanguage, equals('te'));

      // Re-hydrate service simulating app restart
      await UserProfileService.init();
      expect(UserProfileService.currentProfile.selectedLanguage, equals('te'));
    });

    testWidgets('3. GPS permission granted acquires fix and renders Location Detected',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      mockLocationService.setSimulatedPermission(LocationPermissionStatus.granted);
      mockLocationService.updateMockLocation(
        UserLocation.live(
          latitude: 16.9891,
          longitude: 82.2475,
          locationName: 'Kakinada Port Corridor',
          subArea: 'Kakinada District, Andhra Pradesh',
          accuracyMeters: 5.5,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: OnboardingScreen(locationService: mockLocationService),
        ),
      );
      await tester.pumpAndSettle();

      // Advance from Language to Location step
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Where are you?'), findsOneWidget);
      expect(find.text('Allow Location Access'), findsOneWidget);

      // Tap Allow Location Access
      await tester.tap(find.text('Allow Location Access'));
      await tester.pump(const Duration(milliseconds: 100));

      // Verifies acquiring state
      expect(find.text('Acquiring GPS fix...'), findsOneWidget);

      await tester.pumpAndSettle();

      // Verifies location detected and provenance label
      expect(find.text('Location Detected'), findsOneWidget);
      expect(find.text('LIVE GPS FIX'), findsOneWidget);
      expect(find.text('Kakinada Port Corridor'), findsOneWidget);
      expect(find.textContaining('±5.5m telemetry'), findsOneWidget);
      expect(find.text('Confirm & Continue'), findsOneWidget);
    });

    testWidgets('4. GPS permission denied shows informative error and fallbacks without pretending access',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      mockLocationService.setSimulatedPermission(LocationPermissionStatus.denied);

      await tester.pumpWidget(
        MaterialApp(
          home: OnboardingScreen(locationService: mockLocationService),
        ),
      );
      await tester.pumpAndSettle();

      // Advance to Location step
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Tap Allow Location Access
      await tester.tap(find.text('Allow Location Access'));
      await tester.pumpAndSettle();

      // Never pretend access was granted
      expect(find.text('LIVE GPS FIX'), findsNothing);
      expect(find.text('Confirm & Continue'), findsNothing);
      expect(find.textContaining('Location permission was denied'), findsOneWidget);

      // Fallbacks are clearly available
      expect(find.text('Choose manually'), findsOneWidget);
      expect(find.text('Use Demo Location'), findsOneWidget);
    });

    testWidgets('5. GPS timeout handles error safely and prompts manual fallback', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      mockLocationService.setSimulatedPermission(LocationPermissionStatus.granted);
      mockLocationService.setSimulateTimeout(true);

      await tester.pumpWidget(
        MaterialApp(
          home: OnboardingScreen(locationService: mockLocationService),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Allow Location Access'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Acquiring GPS fix...'), findsOneWidget);

      // Let timeout trigger
      await tester.pump(const Duration(seconds: 7));
      await tester.pumpAndSettle();

      // Verifies timeout message displayed
      expect(find.textContaining('timed out'), findsOneWidget);
      expect(find.text('Choose manually'), findsOneWidget);
    });

    testWidgets('6. Manual location selection updates coordinates with MANUALLY SELECTED label',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: OnboardingScreen(locationService: mockLocationService),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Open manual picker
      await tester.tap(find.text('Choose manually'));
      await tester.pumpAndSettle();

      expect(find.text('Choose your region manually'), findsOneWidget);
      expect(find.text('Vijayawada Central'), findsOneWidget);

      // Select Vijayawada
      await tester.tap(find.text('Vijayawada Central'));
      await tester.pumpAndSettle();

      // Verify label is MANUALLY SELECTED, not GPS
      expect(find.text('MANUALLY SELECTED'), findsOneWidget);
      expect(find.text('Vijayawada Central'), findsOneWidget);
      expect(find.text('Confirm & Continue'), findsOneWidget);
    });

    testWidgets('7. Demo location is explicitly labelled with DEMO LOCATION', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: OnboardingScreen(locationService: mockLocationService),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Tap Use Demo Location
      await tester.tap(find.text('Use Demo Location'));
      await tester.pumpAndSettle();

      expect(find.text('DEMO LOCATION'), findsOneWidget);
      expect(find.text('Kakinada Port Corridor'), findsOneWidget);
      expect(find.text('Confirm & Continue'), findsOneWidget);
    });

    testWidgets('8. Headcount counters validation (non-negative, total calculation, separate pets)',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: OnboardingScreen(locationService: mockLocationService),
        ),
      );
      await tester.pumpAndSettle();

      // Step 1 -> Step 2
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Step 2: Use demo location -> Step 3
      await tester.tap(find.text('Use Demo Location'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm & Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Who is with you?'), findsOneWidget);

      // Verify initial unconfigured state distinguishes unfilled profile
      expect(find.text('Total People: 0 • Pets: 0'), findsOneWidget);

      // Find add buttons for Adults (first add icon)
      final addButtons = find.byIcon(Icons.add);
      expect(addButtons, findsNWidgets(4));

      // Add 2 Adults
      await tester.tap(addButtons.at(0));
      await tester.pumpAndSettle();
      await tester.tap(addButtons.at(0));
      await tester.pumpAndSettle();

      // Add 1 Child
      await tester.tap(addButtons.at(1));
      await tester.pumpAndSettle();

      // Add 1 Senior
      await tester.tap(addButtons.at(2));
      await tester.pumpAndSettle();

      // Add 2 Pets
      await tester.tap(addButtons.at(3));
      await tester.pumpAndSettle();
      await tester.tap(addButtons.at(3));
      await tester.pumpAndSettle();

      // Total must be 4 people (2 adults + 1 child + 1 senior) and pets tracked separately (2 pets)
      expect(find.text('Total People: 4 • Pets: 2'), findsOneWidget);

      // Decrement buttons cannot go negative
      final removeButtons = find.byIcon(Icons.remove);
      // Tap remove on Seniors once -> 0
      await tester.tap(removeButtons.at(2));
      await tester.pumpAndSettle();
      // Tap remove on Seniors again -> stays 0
      await tester.tap(removeButtons.at(2));
      await tester.pumpAndSettle();

      expect(find.text('Total People: 3 • Pets: 2'), findsOneWidget);
    });

    testWidgets('9. Mobility assistance selection toggles and persists', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: OnboardingScreen(locationService: mockLocationService),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to People step
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use Demo Location'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm & Continue'));
      await tester.pumpAndSettle();

      // Toggle mobility checkbox
      final checkbox = find.byType(CheckboxListTile);
      expect(checkbox, findsOneWidget);
      await tester.tap(checkbox);
      await tester.pumpAndSettle();

      // Save headcount
      await tester.tap(find.text('Save Headcount & Continue'));
      await tester.pumpAndSettle();

      expect(UserProfileService.currentProfile.needsMobilityAssistance, isTrue);
      expect(UserProfileService.currentProfile.isHeadcountConfigured, isTrue);
    });

    testWidgets('10. Headcount persistence after restart', (tester) async {
      await UserProfileService.updateHeadcount(
        adults: 3,
        children: 2,
        seniors: 1,
        pets: 1,
        needsMobilityAssistance: true,
      );

      expect(UserProfileService.currentProfile.totalPeople, equals(6));
      expect(UserProfileService.currentProfile.pets, equals(1));
      expect(UserProfileService.currentProfile.needsMobilityAssistance, isTrue);

      // Re-hydrate service simulating fresh app restart
      await UserProfileService.init();

      final rehydrated = UserProfileService.currentProfile;
      expect(rehydrated.adults, equals(3));
      expect(rehydrated.children, equals(2));
      expect(rehydrated.seniors, equals(1));
      expect(rehydrated.totalPeople, equals(6));
      expect(rehydrated.pets, equals(1));
      expect(rehydrated.needsMobilityAssistance, isTrue);
      expect(rehydrated.isHeadcountConfigured, isTrue);
    });

    testWidgets('11. SOS packet dynamically uses saved profile values', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await UserProfileService.updateLocation(
        UserLocation.live(
          latitude: 16.5062,
          longitude: 80.6480,
          locationName: 'Vijayawada Central',
          subArea: 'Krishna District, Andhra Pradesh',
          accuracyMeters: 4.2,
        ),
      );
      await UserProfileService.updateHeadcount(
        adults: 2,
        children: 1,
        seniors: 1,
        pets: 2,
        needsMobilityAssistance: true,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: EmergencySosScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Verifies SOS screen displays profile headcount
      expect(find.text('4 people (2A, 1C, 1S)'), findsOneWidget);
      expect(find.text('2'), findsOneWidget); // Pets
      expect(find.text('Required (Wheelchair)'), findsOneWidget);

      // Verifies live GPS telemetry is reflected
      expect(find.text('Vijayawada Central, Krishna District, Andhra Pradesh'), findsOneWidget);
      expect(find.text('±4.2m (Active Telemetry)'), findsOneWidget);
    });

    testWidgets('12. Completed onboarding routes to dashboard and does not repeat', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SharedPreferences.setMockInitialValues({
        UserProfileService.preferenceKey: jsonEncode(
          const UserProfile(
            selectedLanguage: 'en',
            isOnboardingCompleted: true,
          ).toJson(),
        ),
      });
      await UserProfileService.init();
      expect(UserProfileService.isOnboardingCompleted, isTrue);

      await tester.pumpWidget(const SurakshaPathApp());
      await tester.pumpAndSettle();

      // With onboarding completed, app launches directly onto MainNavigationShell
      expect(find.byType(MainNavigationShell), findsOneWidget);
      expect(find.byType(OnboardingScreen), findsNothing);
    });
  });
}
