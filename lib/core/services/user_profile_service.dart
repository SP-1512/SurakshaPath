import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_location.dart';
import '../models/user_profile.dart';
import 'locale_service.dart';

/// Central service for persistent user profile, household headcount,
/// detected/manual location provenance, and onboarding state.
class UserProfileService {
  UserProfileService._();

  static const String preferenceKey = 'surakshapath_user_profile_v1';
  static SharedPreferences? _prefs;

  static UserProfile _currentProfile = UserProfile.unconfigured();
  static final ValueNotifier<UserProfile> profileNotifier =
      ValueNotifier<UserProfile>(_currentProfile);

  /// Initializes profile service from SharedPreferences.
  static Future<void> init([SharedPreferences? preferences]) async {
    try {
      _prefs = preferences ?? await SharedPreferences.getInstance();
      final storedJson = _prefs?.getString(preferenceKey);
      if (storedJson != null && storedJson.isNotEmpty) {
        final Map<String, dynamic> decoded = jsonDecode(storedJson) as Map<String, dynamic>;
        _currentProfile = UserProfile.fromJson(decoded);
      } else {
        // Fallback default language from LocaleService if available
        _currentProfile = UserProfile(
          selectedLanguage: LocaleService.currentLocale.value,
          location: null,
          isHeadcountConfigured: false,
          isOnboardingCompleted: false,
        );
      }
      profileNotifier.value = _currentProfile;
    } catch (e) {
      debugPrint('UserProfileService.init error: $e. Falling back to default profile.');
      _currentProfile = UserProfile.unconfigured();
      profileNotifier.value = _currentProfile;
    }
  }

  static UserProfile get currentProfile => _currentProfile;

  static bool get isOnboardingCompleted => _currentProfile.isOnboardingCompleted;

  static UserLocation get currentLocation =>
      _currentProfile.location ?? UserLocation.mockDefault();

  /// Saves the complete profile to persistent storage.
  static Future<void> saveProfile(UserProfile profile) async {
    _currentProfile = profile;
    profileNotifier.value = _currentProfile;
    try {
      final jsonStr = jsonEncode(profile.toJson());
      await _prefs?.setString(preferenceKey, jsonStr);
    } catch (e) {
      debugPrint('UserProfileService.saveProfile error: $e');
    }
  }

  /// Updates language and syncs with LocaleService.
  static Future<void> updateLanguage(String code) async {
    await LocaleService.setLocale(code);
    final updated = _currentProfile.copyWith(selectedLanguage: code);
    await saveProfile(updated);
  }

  /// Updates and persists user location (live GPS, manual selection, or demo).
  static Future<void> updateLocation(UserLocation location) async {
    final updated = _currentProfile.copyWith(location: location);
    await saveProfile(updated);
  }

  /// Updates household headcount and mobility assistance needs.
  static Future<void> updateHeadcount({
    required int adults,
    required int children,
    required int seniors,
    required int pets,
    required bool needsMobilityAssistance,
  }) async {
    final safeAdults = adults < 0 ? 0 : adults;
    final safeChildren = children < 0 ? 0 : children;
    final safeSeniors = seniors < 0 ? 0 : seniors;
    final safePets = pets < 0 ? 0 : pets;

    final updated = _currentProfile.copyWith(
      adults: safeAdults,
      children: safeChildren,
      seniors: safeSeniors,
      pets: safePets,
      needsMobilityAssistance: needsMobilityAssistance,
      isHeadcountConfigured: true,
    );
    await saveProfile(updated);
  }

  /// Marks onboarding flow as completed.
  static Future<void> completeOnboarding() async {
    final updated = _currentProfile.copyWith(isOnboardingCompleted: true);
    await saveProfile(updated);
  }

  /// Resets profile for logout or test reset.
  static Future<void> reset() async {
    _currentProfile = UserProfile.unconfigured();
    profileNotifier.value = _currentProfile;
    try {
      await _prefs?.remove(preferenceKey);
    } catch (e) {
      debugPrint('UserProfileService.reset error: $e');
    }
  }
}
