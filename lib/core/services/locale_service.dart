import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Metadata for supported languages in SurakshaPath.
class AppLanguage {
  final String code;
  final String englishName;
  final String nativeName;
  final String sampleSubtitle;
  final bool isAvailable;
  final String statusLabel;

  const AppLanguage({
    required this.code,
    required this.englishName,
    required this.nativeName,
    required this.sampleSubtitle,
    required this.isAvailable,
    required this.statusLabel,
  });

  String get displayName => '$nativeName ($englishName)';
}

/// Centralized locale controller with 11 Indic languages, SharedPreferences persistence,
/// and safe English fallback.
class LocaleService {
  LocaleService._();

  static const String defaultLocale = 'en';
  static const String preferenceKey = 'surakshapath_locale_code';

  static SharedPreferences? _prefs;

  /// All 11 supported languages cataloged for SurakshaPath.
  static const List<AppLanguage> supportedLanguages = [
    AppLanguage(
      code: 'en',
      englishName: 'English',
      nativeName: 'English',
      sampleSubtitle: 'Navigate to Safety',
      isAvailable: true,
      statusLabel: 'Active',
    ),
    AppLanguage(
      code: 'te',
      englishName: 'Telugu',
      nativeName: 'తెలుగు',
      sampleSubtitle: 'భద్రతకు మార్గం',
      isAvailable: true,
      statusLabel: 'Active',
    ),
    AppLanguage(
      code: 'hi',
      englishName: 'Hindi',
      nativeName: 'हिन्दी',
      sampleSubtitle: 'सुरक्षा का मार्ग',
      isAvailable: false,
      statusLabel: 'Translation in progress',
    ),
    AppLanguage(
      code: 'ta',
      englishName: 'Tamil',
      nativeName: 'தமிழ்',
      sampleSubtitle: 'பாதுகாப்பிற்கான வழி',
      isAvailable: false,
      statusLabel: 'Translation in progress',
    ),
    AppLanguage(
      code: 'kn',
      englishName: 'Kannada',
      nativeName: 'ಕನ್ನಡ',
      sampleSubtitle: 'ಸುರಕ್ಷತೆಯ ಹಾದಿ',
      isAvailable: false,
      statusLabel: 'Translation in progress',
    ),
    AppLanguage(
      code: 'ml',
      englishName: 'Malayalam',
      nativeName: 'മലയാളം',
      sampleSubtitle: 'സുരക്ഷా పాద',
      isAvailable: false,
      statusLabel: 'Translation in progress',
    ),
    AppLanguage(
      code: 'bn',
      englishName: 'Bengali',
      nativeName: 'বাংলা',
      sampleSubtitle: 'নিরাপত্তার পথ',
      isAvailable: false,
      statusLabel: 'Translation in progress',
    ),
    AppLanguage(
      code: 'mr',
      englishName: 'Marathi',
      nativeName: 'मराठी',
      sampleSubtitle: 'सुरक्षेचा मार्ग',
      isAvailable: false,
      statusLabel: 'Translation in progress',
    ),
    AppLanguage(
      code: 'gu',
      englishName: 'Gujarati',
      nativeName: 'ગુજરાતી',
      sampleSubtitle: 'સુરક્ષાનો માર્ગ',
      isAvailable: false,
      statusLabel: 'Translation in progress',
    ),
    AppLanguage(
      code: 'or',
      englishName: 'Odia',
      nativeName: 'ଓଡ଼ିଆ',
      sampleSubtitle: 'ସୁరକ୍ଷା ପଥ',
      isAvailable: false,
      statusLabel: 'Translation in progress',
    ),
    AppLanguage(
      code: 'pa',
      englishName: 'Punjabi',
      nativeName: 'ਪੰਜਾਬੀ',
      sampleSubtitle: 'ਸੁਰੱਖਿਆ ਦਾ ਮਾਰਗ',
      isAvailable: false,
      statusLabel: 'Translation in progress',
    ),
  ];

  static final List<String> supportedLocaleCodes =
      supportedLanguages.map((l) => l.code).toList(growable: false);

  /// ValueNotifier exposing the active locale code (e.g. 'en', 'te').
  static final ValueNotifier<String> currentLocale =
      ValueNotifier<String>(defaultLocale);

  /// Backwards-compatible Telugu check.
  static bool get isTelugu => currentLocale.value == 'te';

  /// Current active Locale instance.
  static Locale get currentLocaleInstance => Locale(currentLocale.value);

  /// Return Flutter Locales for all 11 supported languages.
  static List<Locale> get flutterSupportedLocales =>
      supportedLocaleCodes.map((code) => Locale(code)).toList();

  /// Initialize LocaleService, restoring persisted locale from SharedPreferences
  /// or falling back safely to default English.
  static Future<void> init({SharedPreferences? preferences}) async {
    try {
      _prefs = preferences ?? await SharedPreferences.getInstance();
      final savedCode = _prefs?.getString(preferenceKey)?.trim().toLowerCase();
      if (savedCode != null && isSupported(savedCode)) {
        currentLocale.value = savedCode;
      } else {
        currentLocale.value = defaultLocale;
      }
    } catch (e) {
      debugPrint('LocaleService init warning: $e');
      currentLocale.value = defaultLocale;
    }
  }

  /// Check whether a language code is supported among the 11 target locales.
  static bool isSupported(String? code) {
    if (code == null) return false;
    return supportedLocaleCodes.contains(code.toLowerCase());
  }

  /// Check whether fully approved translations exist for this locale (en, te).
  static bool isAvailable(String? code) {
    if (code == null) return false;
    final match = supportedLanguages.where((l) => l.code == code.toLowerCase());
    return match.isNotEmpty && match.first.isAvailable;
  }

  /// Set and persist the current locale to SharedPreferences.
  /// If [langCode] is invalid or unsupported, falls back safely to 'en'.
  static Future<void> setLocale(String langCode) async {
    final cleanCode = langCode.trim().toLowerCase();
    final targetCode = isSupported(cleanCode) ? cleanCode : defaultLocale;

    if (currentLocale.value != targetCode) {
      currentLocale.value = targetCode;
    }
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      _prefs = prefs;
      await prefs.setString(preferenceKey, targetCode);
    } catch (e) {
      debugPrint('LocaleService setLocale write warning: $e');
    }
  }

  /// Backwards-compatible toggle between English and Telugu.
  static void toggle() {
    setLocale(currentLocale.value == 'en' ? 'te' : 'en');
  }

  /// Reset to clean state (primarily for test cleanup).
  @visibleForTesting
  static void resetForTesting({SharedPreferences? preferences}) {
    _prefs = preferences;
    currentLocale.value = defaultLocale;
  }
}
