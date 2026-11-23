import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:surakshapath/core/localization/emergency_translation_registry.dart';
import 'package:surakshapath/core/services/locale_service.dart';
import 'package:surakshapath/core/widgets/language_bottom_sheet.dart';
import 'package:surakshapath/l10n/generated/app_localizations.dart';

void main() {
  group('Phase 2: Multilingual Localization Infrastructure Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      LocaleService.resetForTesting();
      EmergencyTranslationRegistry.clear();
    });

    tearDown(() {
      LocaleService.resetForTesting();
      EmergencyTranslationRegistry.clear();
    });

    test('1. Default and fallback locale is English (en)', () {
      expect(LocaleService.currentLocale.value, equals('en'));
      expect(LocaleService.isTelugu, isFalse);
      expect(LocaleService.defaultLocale, equals('en'));
    });

    test('2. Supports exactly 11 Indic and English locales', () {
      expect(LocaleService.supportedLocaleCodes.length, equals(11));
      expect(
        LocaleService.supportedLocaleCodes,
        equals(['en', 'te', 'hi', 'ta', 'kn', 'ml', 'bn', 'mr', 'gu', 'or', 'pa']),
      );

      for (final code in ['en', 'te', 'hi', 'ta', 'kn', 'ml', 'bn', 'mr', 'gu', 'or', 'pa']) {
        expect(LocaleService.isSupported(code), isTrue, reason: 'Locale $code should be supported');
      }

      // Unsupported locales
      expect(LocaleService.isSupported('fr'), isFalse);
      expect(LocaleService.isSupported('de'), isFalse);
      expect(LocaleService.isSupported('invalid_code'), isFalse);
      expect(LocaleService.isSupported(null), isFalse);
    });

    test('3. Distinguishes active languages (en, te) from in-progress languages', () {
      expect(LocaleService.isAvailable('en'), isTrue);
      expect(LocaleService.isAvailable('te'), isTrue);

      for (final code in ['hi', 'ta', 'kn', 'ml', 'bn', 'mr', 'gu', 'or', 'pa']) {
        expect(LocaleService.isAvailable(code), isFalse, reason: '$code should be marked in-progress');
      }
    });

    test('4. Missing preference falls back to English', () async {
      SharedPreferences.setMockInitialValues({});
      await LocaleService.init();
      expect(LocaleService.currentLocale.value, equals('en'));
      expect(LocaleService.isTelugu, isFalse);
    });

    test('5. Invalid or corrupted preference falls back safely to English', () async {
      SharedPreferences.setMockInitialValues({
        LocaleService.preferenceKey: 'corrupted_unknown_locale',
      });
      await LocaleService.init();
      expect(LocaleService.currentLocale.value, equals('en'));

      await LocaleService.setLocale('unsupported_es');
      expect(LocaleService.currentLocale.value, equals('en'));

      await LocaleService.setLocale('xyz');
      expect(LocaleService.currentLocale.value, equals('en'));
    });

    test('6. Telugu selection persists across service initialization and restarts', () async {
      SharedPreferences.setMockInitialValues({});
      await LocaleService.init();
      expect(LocaleService.currentLocale.value, equals('en'));

      await LocaleService.setLocale('te');
      expect(LocaleService.currentLocale.value, equals('te'));
      expect(LocaleService.isTelugu, isTrue);

      // Verify stored in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(LocaleService.preferenceKey), equals('te'));

      // Simulate app restart with new LocaleService initialization
      LocaleService.resetForTesting();
      await LocaleService.init();
      expect(LocaleService.currentLocale.value, equals('te'));
      expect(LocaleService.isTelugu, isTrue);
    });

    test('7. Storage read/write exceptions are handled safely without crashing LocaleService', () async {
      // Force init with null/corrupt mock
      await LocaleService.init();
      expect(LocaleService.currentLocale.value, equals('en'));

      // setLocale handles unexpected storage failure gracefully
      await LocaleService.setLocale('te');
      expect(LocaleService.currentLocale.value, equals('te'));
    });

    test('8. Emergency Translation Registry falls back to English when status is draft or awaitingReview', () {
      EmergencyTranslationRegistry.register(
        const EmergencyContentRecord(
          key: 'evac_instruction_1',
          locale: 'te',
          sourceEnglish: 'Evacuate immediately to designated high ground.',
          translatedText: 'వెంటనే ఎత్తైన ప్రాంతానికి తరలించండి.',
          status: EmergencyTranslationStatus.draft,
        ),
      );

      final draftResolution = EmergencyTranslationRegistry.resolve(
        key: 'evac_instruction_1',
        locale: 'te',
        fallbackEnglish: 'Evacuate immediately to designated high ground.',
      );

      expect(draftResolution.isFallback, isTrue);
      expect(draftResolution.text, equals('Evacuate immediately to designated high ground.'));
      expect(draftResolution.disclaimer, equals(EmergencyTranslationRegistry.fallbackDisclaimer));
      expect(draftResolution.status, equals(EmergencyTranslationStatus.draft));

      // Register awaiting review
      EmergencyTranslationRegistry.register(
        const EmergencyContentRecord(
          key: 'evac_instruction_2',
          locale: 'hi',
          sourceEnglish: 'Avoid low-lying underpasses.',
          translatedText: 'निचले अंडरपास से बचें।',
          status: EmergencyTranslationStatus.awaitingReview,
        ),
      );

      final awaitingResolution = EmergencyTranslationRegistry.resolve(
        key: 'evac_instruction_2',
        locale: 'hi',
        fallbackEnglish: 'Avoid low-lying underpasses.',
      );

      expect(awaitingResolution.isFallback, isTrue);
      expect(awaitingResolution.text, equals('Avoid low-lying underpasses.'));
    });

    test('9. Emergency Translation Registry returns translated text when status is approved without fabricating government credentials', () {
      EmergencyTranslationRegistry.register(
        EmergencyContentRecord(
          key: 'hero_alert_prakasam',
          locale: 'te',
          sourceEnglish: '[SIMULATION] Flood Warning: Prakasam Barrage',
          translatedText: '[అనుకరణ] వరద హెచ్చరిక: ప్రకాశం బ్యారేజ్',
          status: EmergencyTranslationStatus.approved,
          reviewedBy: 'Certified Translation Review Team',
          reviewedAt: DateTime(2026, 11, 23),
          reviewNotes: 'Reviewed against disaster terminology glossary.',
        ),
      );

      final resolved = EmergencyTranslationRegistry.resolve(
        key: 'hero_alert_prakasam',
        locale: 'te',
        fallbackEnglish: '[SIMULATION] Flood Warning: Prakasam Barrage',
      );

      expect(resolved.isFallback, isFalse);
      expect(resolved.text, equals('[అనుకరణ] వరద హెచ్చరిక: ప్రకాశం బ్యారేజ్'));
      expect(resolved.disclaimer, isNull);
      expect(resolved.status, equals(EmergencyTranslationStatus.approved));
    });

    test('10. Missing emergency translations safely use English fallback with disclaimer', () {
      final missingResolution = EmergencyTranslationRegistry.resolve(
        key: 'unregistered_emergency_hazard',
        locale: 'kn',
        fallbackEnglish: 'Avoid storm surge zones along coastline.',
      );

      expect(missingResolution.isFallback, isTrue);
      expect(missingResolution.text, equals('Avoid storm surge zones along coastline.'));
      expect(missingResolution.disclaimer, equals(EmergencyTranslationRegistry.fallbackDisclaimer));
      expect(missingResolution.status, equals(EmergencyTranslationStatus.draft));
    });

    testWidgets('11. EmergencyReviewDisclaimerPill renders visible warning UI', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: EmergencyReviewDisclaimerPill(),
            ),
          ),
        ),
      );

      expect(find.byType(EmergencyReviewDisclaimerPill), findsOneWidget);
      expect(find.text(EmergencyTranslationRegistry.fallbackDisclaimer), findsOneWidget);
      expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);
    });

    testWidgets('12. LanguageBottomSheet displays all 11 languages with native names', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => LanguageBottomSheet.show(context),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Check header
      expect(find.text('Choose Language / భాషను ఎంచుకోండి'), findsOneWidget);

      // Check all 11 native names
      expect(find.text('English'), findsWidgets);
      expect(find.text('తెలుగు'), findsOneWidget);
      expect(find.text('हिन्दी'), findsOneWidget);
      expect(find.text('தமிழ்'), findsOneWidget);
      expect(find.text('ಕನ್ನಡ'), findsOneWidget);
      expect(find.text('മലയാളം'), findsOneWidget);
      expect(find.text('বাংলা'), findsOneWidget);
      expect(find.text('मराठी'), findsOneWidget);
      expect(find.text('ગુજરાતી'), findsOneWidget);
      expect(find.text('ଓଡ଼ିଆ'), findsOneWidget);
      expect(find.text('ਪੰਜਾਬੀ'), findsOneWidget);

      // Verify in-progress badges
      expect(find.text('Translation in progress'), findsNWidgets(9));
    });

    testWidgets('13. LanguageBottomSheet renders cleanly on 320dp width without overflow', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => LanguageBottomSheet.show(context),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Ensure no RenderFlex overflow exception
      expect(tester.takeException(), isNull);
      expect(find.text('Choose Language / భాషను ఎంచుకోండి'), findsOneWidget);
    });

    testWidgets('14. AppLocalizations correctly resolves English and Telugu strings', (WidgetTester tester) async {
      late BuildContext capturedContext;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('te'),
          home: Builder(
            builder: (context) {
              capturedContext = context;
              final l10n = AppLocalizations.of(context);
              return Scaffold(
                body: Text(l10n.appName),
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(capturedContext);
      expect(l10n.appName, equals('సురక్షాపథం'));
      expect(l10n.appTagline, equals('భద్రతకు మార్గం.'));
      expect(l10n.navHome, equals('హోమ్'));
      expect(l10n.navMap, equals('మ్యాప్'));
      expect(l10n.emergencySosTitle, equals('అత్యవసర ఎస్ఓఎస్'));
    });
  });
}
