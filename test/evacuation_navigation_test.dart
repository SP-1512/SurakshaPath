import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:surakshapath/core/constants/app_strings.dart';
import 'package:surakshapath/core/models/user_location.dart';
import 'package:surakshapath/core/models/user_profile.dart';
import 'package:surakshapath/core/services/locale_service.dart';
import 'package:surakshapath/core/services/user_profile_service.dart';
import 'package:surakshapath/features/routing/screens/routing_screen.dart';
import 'package:surakshapath/features/routing/widgets/evacuation_map_view.dart';
import 'package:surakshapath/app/app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await UserProfileService.init();
    await LocaleService.init();
    await UserProfileService.saveProfile(
      UserProfile(
        selectedLanguage: 'en',
        location: UserLocation.mockDefault(),
        isHeadcountConfigured: true,
        isOnboardingCompleted: true,
      ),
    );
  });

  group('SurakshaPath In-App Turn-by-Turn Navigation Tests', () {
    testWidgets('1. Evacuate tab displays real EvacuationMapView and route preview elements',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const SurakshaPathApp());
      await tester.pumpAndSettle();

      // Tap Evacuate Tab
      await tester.tap(find.text(AppStrings.navEvacuate));
      await tester.pumpAndSettle();

      // Verify EvacuationMapView is in tree
      expect(find.byType(EvacuationMapView), findsOneWidget);

      // Verify Origin and Destination cards
      expect(find.text(AppStrings.fromLocation), findsOneWidget);
      expect(find.text('TO SAFE SHELTER'), findsOneWidget);
      expect(find.text('Change'), findsOneWidget);

      // Verify Metrics Row
      expect(find.text('Distance'), findsOneWidget);
      expect(find.text('Est. Time'), findsOneWidget);
      expect(find.text('Route Risk'), findsOneWidget);

      // Verify Start Guidance CTA
      expect(find.text(AppStrings.startGuidance), findsOneWidget);
      expect(find.byIcon(Icons.navigation_rounded), findsOneWidget);
    });

    testWidgets('2. Tapping Start Guidance transitions into active Navigation HUD Cockpit',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: RoutingScreen()));
      await tester.pumpAndSettle();

      // Tap Start Guidance button
      final startBtn = find.text(AppStrings.startGuidance);
      expect(startBtn, findsOneWidget);
      await tester.ensureVisible(startBtn);
      await tester.pumpAndSettle();
      await tester.tap(startBtn);
      await tester.pumpAndSettle();

      // Verify transition to active navigation HUD
      expect(find.text('SIMULATOR'), findsOneWidget);
      expect(find.text('End'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsWidgets);

      // Verify HUD overlays
      expect(find.textContaining('PACE'), findsOneWidget);
      expect(find.byType(EvacuationMapView), findsOneWidget);

      // Advance navigation step
      final nextStepBtn = find.byTooltip('Next Step');
      expect(nextStepBtn, findsOneWidget);
      await tester.tap(nextStepBtn);
      await tester.pumpAndSettle();

      expect(find.textContaining('Step 2 of'), findsOneWidget);

      // Dismiss snackbar before tapping end
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      // Tap End Navigation button to return to route preview
      final endBtn = find.text('End');
      expect(endBtn, findsOneWidget);
      await tester.tap(endBtn);
      await tester.pumpAndSettle();

      // Verify returned to route preview
      expect(find.text(AppStrings.startGuidance), findsOneWidget);
    });

    testWidgets('3. Travel mode toggles between Vehicle and Walking pace',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: RoutingScreen()));
      await tester.pumpAndSettle();

      // Initial pace is Vehicle (25 km/h)
      expect(find.text('Approx @ 25 km/h'), findsOneWidget);

      // Tap Walking mode
      await tester.tap(find.text('Walking (5 km/h)'));
      await tester.pumpAndSettle();

      // Pace updates to Walking (5 km/h)
      expect(find.text('Pace @ 5 km/h'), findsOneWidget);
    });

    testWidgets('4. Bilingual Telugu switching renders localized navigation strings',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await LocaleService.setLocale('te');

      await tester.pumpWidget(const MaterialApp(home: RoutingScreen()));
      await tester.pumpAndSettle();

      // Localized Telugu Start Guidance button
      expect(find.text('మార్గదర్శకత్వం ప్రారంభించండి'), findsOneWidget);
      expect(find.text('మార్చండి'), findsOneWidget);

      // Reset to English
      await LocaleService.setLocale('en');
    });
  });
}
