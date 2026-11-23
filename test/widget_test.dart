import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:surakshapath/app/app.dart';
import 'package:surakshapath/core/constants/app_strings.dart';
import 'package:surakshapath/core/models/user_profile.dart';
import 'package:surakshapath/core/services/locale_service.dart';
import 'package:surakshapath/core/services/user_profile_service.dart';
import 'package:surakshapath/features/emergency/screens/emergency_sos_screen.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      UserProfileService.preferenceKey: jsonEncode(
        const UserProfile(
          selectedLanguage: 'en',
          isOnboardingCompleted: true,
        ).toJson(),
      ),
      LocaleService.preferenceKey: 'en',
    });
    await LocaleService.init();
    await LocaleService.setLocale('en');
    await UserProfileService.init();
  });
  testWidgets('SurakshaPath dashboard renders branding, location and emergency SOS',
      (WidgetTester tester) async {
    // Set a realistic modern mobile viewport (1080x2400 @ 2.5x -> 432x960 dp)
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Build our app and trigger frames including async mock latency
    await tester.pumpWidget(const SurakshaPathApp());
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    // Verify app branding header
    expect(find.text(AppStrings.appName), findsOneWidget);

    // Verify Current Location section
    expect(find.text(AppStrings.sectionLocation), findsOneWidget);

    // Verify Emergency SOS card
    expect(find.text(AppStrings.emergencySosTitle), findsOneWidget);

    // Verify Shelter Spotlight section
    expect(find.text(AppStrings.sectionShelterSpotlight), findsOneWidget);

    // Verify Disaster context selector
    final mainScrollable = find.byType(Scrollable).first;
    final disasterFinder = find.text(AppStrings.sectionDisasterFilter);
    await tester.scrollUntilVisible(
      disasterFinder,
      200,
      scrollable: mainScrollable,
    );
    expect(disasterFinder, findsOneWidget);

    // Verify Quick Navigation cards
    final safeSheltersFinder = find.text('Safe Shelters');
    await tester.scrollUntilVisible(
      safeSheltersFinder,
      200,
      scrollable: mainScrollable,
    );
    expect(safeSheltersFinder, findsOneWidget);

    // Verify Evac Map appears
    expect(find.text('Evac Map'), findsWidgets);
  });

  testWidgets('SurakshaPath bilingual switching and Telugu rendering test',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const SurakshaPathApp());
    await tester.pumpAndSettle();

    // Switch to Telugu
    LocaleService.setLocale('te');
    await tester.pumpAndSettle();

    // Verify Telugu action button on Home screen
    expect(find.text(AppStrings.startEvacuationPlan), findsWidgets);

    // Switch back to English
    LocaleService.setLocale('en');
    await tester.pumpAndSettle();
    expect(find.text('Start evacuation plan'), findsWidgets);
  });

  testWidgets('SurakshaPath lazy tab loading and state retention test',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const SurakshaPathApp());
    await tester.pumpAndSettle();

    // On cold launch, Tab 0 (Home) is active
    expect(find.text(AppStrings.appName), findsOneWidget);

    // Tab 3 (SHELTERS) label is present on bottom navigation bar
    final sheltersTab = find.text(AppStrings.navShelters);
    expect(sheltersTab, findsOneWidget);

    // Tap Tab 3 to lazily initialize SheltersScreen
    await tester.tap(sheltersTab);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    // Shelters search hint or title is now initialized and rendered
    expect(find.text('Search by shelter name or area...'), findsOneWidget);

    // Switch back to Tab 0 (Home)
    final homeTab = find.text(AppStrings.navHome);
    await tester.tap(homeTab);
    await tester.pumpAndSettle();

    // Verify Home Screen state was preserved
    expect(find.text(AppStrings.appName), findsOneWidget);
    expect(find.text(AppStrings.sectionLocation), findsOneWidget);
  });

  testWidgets('SurakshaPath evacuation screen displays simulated corridor demo badge and disclaimer',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const SurakshaPathApp());
    await tester.pumpAndSettle();

    // Tap Evacuate Tab
    final evacTab = find.text(AppStrings.navEvacuate);
    expect(evacTab, findsOneWidget);
    await tester.tap(evacTab);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    // Verify Simulated Corridor Demo Badge is present
    expect(find.text('SIMULATED CORRIDOR'), findsOneWidget);

    // Verify explicit hazard avoidance disclaimer is present
    expect(find.textContaining('Simulated Hazard Avoidance (Demo)'), findsOneWidget);
    expect(find.textContaining('not physically verified'), findsOneWidget);

    // Verify metrics row renders
    expect(find.text('Distance'), findsOneWidget);
    expect(find.text('Est. Time'), findsOneWidget);
  });

  testWidgets('SurakshaPath emergency SOS screen displays demo location and direct dialer triggers',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: EmergencySosScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Emergency SOS screen header
    expect(find.text(AppStrings.emergencySosTitle), findsOneWidget);

    // Verify direct dialers
    expect(find.textContaining('112'), findsOneWidget);
    expect(find.textContaining('108'), findsOneWidget);

    // Verify location authenticity: mock coordinates must NOT be called GPS Coordinates
    expect(find.text('Live location unavailable'), findsOneWidget);
    expect(find.textContaining('DEMO LOCATION'), findsOneWidget);
    expect(find.text('GPS Coordinates'), findsNothing);

    // Verify SMS and Clipboard buttons
    expect(find.text('Send Location SMS to Contacts'), findsOneWidget);
    expect(find.text(AppStrings.copyCoordinates), findsOneWidget);
  });

  testWidgets('SurakshaPath shelter discovery renders unverified demo badge and facility details',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const SurakshaPathApp());
    await tester.pumpAndSettle();

    // Navigate to Shelters Tab
    final sheltersTab = find.text(AppStrings.navShelters);
    await tester.tap(sheltersTab);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    // Verify shelter list items show Demo data
    expect(find.text('Demo data'), findsWidgets);
    expect(find.textContaining('Kakinada Multi-Purpose Cyclone Shelter'), findsOneWidget);

    // Tap the Kakinada shelter to open bottom sheet
    await tester.tap(find.textContaining('Kakinada Multi-Purpose Cyclone Shelter').first);
    await tester.pumpAndSettle();

    // Verify unverified sample banner in bottom sheet
    expect(find.textContaining('Unverified sample record for demonstration'), findsOneWidget);
    expect(find.text('Reported Facilities (Unverified Demo):'), findsOneWidget);
  });
}
