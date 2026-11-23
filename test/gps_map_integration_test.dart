import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:surakshapath/core/constants/app_strings.dart';
import 'package:surakshapath/core/models/user_location.dart';
import 'package:surakshapath/core/services/locale_service.dart';
import 'package:surakshapath/core/services/user_profile_service.dart';
import 'package:surakshapath/core/widgets/app_header.dart';
import 'package:surakshapath/features/map/screens/map_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'user_locale': 'en',
    });
    await LocaleService.init();
    await UserProfileService.init();
    await UserProfileService.updateLocation(
      UserLocation(
        latitude: 16.9891,
        longitude: 82.2475,
        locationName: 'Kakinada Live Port',
        subArea: 'Kakinada District',
        provenance: LocationProvenance.liveGps,
        accuracyMeters: 4.5,
        timestamp: DateTime.now(),
        isGpsActive: true,
        isMock: false,
      ),
    );
  });

  group('GPS & MapScreen Integration Tests', () {
    testWidgets('1. MapScreen renders persistent AppHeader with Red SOS Pill', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MapScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify persistent AppHeader is present with navMap title and SOS action
      expect(find.byType(AppHeader), findsOneWidget);
      expect(find.text(AppStrings.navMap), findsOneWidget);
      expect(find.text('SOS'), findsOneWidget);
    });

    testWidgets('2. MapScreen renders connectivity indicator and honest location provenance', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MapScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify honest provenance label from UserProfileService (LIVE GPS)
      expect(find.textContaining('LIVE GPS'), findsOneWidget);
      expect(find.text('Online (OpenFreeMap)'), findsOneWidget);
      expect(find.text('OpenFreeMap © OpenStreetMap contributors'), findsOneWidget);
    });

    testWidgets('3. Filter chips render and toggle shelter categories', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MapScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('All'), findsOneWidget);
      expect(find.text('Pets Allowed'), findsOneWidget);
      expect(find.text('Accessible'), findsOneWidget);
      expect(find.text('High Ground'), findsOneWidget);

      // Tap 'Pets Allowed' chip
      await tester.tap(find.text('Pets Allowed'));
      await tester.pumpAndSettle();

      // Tap 'Accessible' chip
      await tester.tap(find.text('Accessible'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('4. Dynamic profile updates immediately reflect on MapScreen', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MapScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Update location dynamically to manual selection
      final newLoc = UserLocation(
        latitude: 17.6868,
        longitude: 83.2185,
        locationName: 'Visakhapatnam Harbor Sector',
        subArea: 'Visakhapatnam District',
        provenance: LocationProvenance.manualSelection,
        timestamp: DateTime.now(),
        isGpsActive: false,
        isMock: false,
      );
      await UserProfileService.updateLocation(newLoc);
      await tester.pumpAndSettle();

      // Verify the badge changed dynamically
      expect(find.text(LocationProvenance.manualSelection.label), findsOneWidget);
    });
  });
}
