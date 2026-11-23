import 'user_location.dart';

/// User profile containing household headcount, assistance requirements,
/// persistent location provenance, and onboarding completion status.
class UserProfile {
  final String selectedLanguage;
  final UserLocation? location;
  final int? adults;
  final int? children;
  final int? seniors;
  final int? pets;
  final bool needsMobilityAssistance;
  final bool isHeadcountConfigured;
  final bool isOnboardingCompleted;

  const UserProfile({
    this.selectedLanguage = 'en',
    this.location,
    this.adults,
    this.children,
    this.seniors,
    this.pets,
    this.needsMobilityAssistance = false,
    this.isHeadcountConfigured = false,
    this.isOnboardingCompleted = false,
  });

  /// Factory for empty/unconfigured baseline profile on first app launch.
  factory UserProfile.unconfigured() {
    return const UserProfile(
      selectedLanguage: 'en',
      location: null,
      adults: null,
      children: null,
      seniors: null,
      pets: null,
      needsMobilityAssistance: false,
      isHeadcountConfigured: false,
      isOnboardingCompleted: false,
    );
  }

  /// Total count of human beings in the household (adults + children + seniors).
  /// Pets are deliberately tracked separately.
  int get totalPeople {
    if (!isHeadcountConfigured) return 0;
    return (adults ?? 0) + (children ?? 0) + (seniors ?? 0);
  }

  int get totalPets => pets ?? 0;

  /// Human-readable summary for SOS and shelter matching.
  String get headcountSummary {
    if (!isHeadcountConfigured) {
      return 'Headcount: Not provided (Profile unconfigured)';
    }
    return '$totalPeople people (${adults ?? 0} adults, ${children ?? 0} children, ${seniors ?? 0} seniors)';
  }

  UserProfile copyWith({
    String? selectedLanguage,
    UserLocation? location,
    int? adults,
    int? children,
    int? seniors,
    int? pets,
    bool? needsMobilityAssistance,
    bool? isHeadcountConfigured,
    bool? isOnboardingCompleted,
  }) {
    return UserProfile(
      selectedLanguage: selectedLanguage ?? this.selectedLanguage,
      location: location ?? this.location,
      adults: adults ?? this.adults,
      children: children ?? this.children,
      seniors: seniors ?? this.seniors,
      pets: pets ?? this.pets,
      needsMobilityAssistance: needsMobilityAssistance ?? this.needsMobilityAssistance,
      isHeadcountConfigured: isHeadcountConfigured ?? this.isHeadcountConfigured,
      isOnboardingCompleted: isOnboardingCompleted ?? this.isOnboardingCompleted,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'selectedLanguage': selectedLanguage,
      'location': location?.toJson(),
      'adults': adults,
      'children': children,
      'seniors': seniors,
      'pets': pets,
      'needsMobilityAssistance': needsMobilityAssistance,
      'isHeadcountConfigured': isHeadcountConfigured,
      'isOnboardingCompleted': isOnboardingCompleted,
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      selectedLanguage: json['selectedLanguage'] as String? ?? 'en',
      location: json['location'] != null
          ? UserLocation.fromJson(json['location'] as Map<String, dynamic>)
          : null,
      adults: json['adults'] as int?,
      children: json['children'] as int?,
      seniors: json['seniors'] as int?,
      pets: json['pets'] as int?,
      needsMobilityAssistance: json['needsMobilityAssistance'] as bool? ?? false,
      isHeadcountConfigured: json['isHeadcountConfigured'] as bool? ?? false,
      isOnboardingCompleted: json['isOnboardingCompleted'] as bool? ?? false,
    );
  }
}
