import 'package:flutter/material.dart';

/// Supported disaster classifications in SurakshaPath.
enum DisasterType {
  all,
  cyclone,
  flood,
  earthquake,
  fire,
  landslide,
  tsunami,
  other;

  String get displayName {
    switch (this) {
      case DisasterType.all:
        return 'All Hazards';
      case DisasterType.cyclone:
        return 'Cyclone';
      case DisasterType.flood:
        return 'Flood';
      case DisasterType.earthquake:
        return 'Earthquake';
      case DisasterType.fire:
        return 'Fire';
      case DisasterType.landslide:
        return 'Landslide';
      case DisasterType.tsunami:
        return 'Tsunami';
      case DisasterType.other:
        return 'General';
    }
  }

  IconData get iconData {
    switch (this) {
      case DisasterType.all:
        return Icons.dashboard_outlined;
      case DisasterType.cyclone:
        return Icons.cyclone;
      case DisasterType.flood:
        return Icons.water_damage;
      case DisasterType.earthquake:
        return Icons.vibration;
      case DisasterType.fire:
        return Icons.local_fire_department;
      case DisasterType.landslide:
        return Icons.terrain;
      case DisasterType.tsunami:
        return Icons.tsunami;
      case DisasterType.other:
        return Icons.warning_amber_rounded;
    }
  }

  Color get accentColor {
    switch (this) {
      case DisasterType.all:
        return const Color(0xFF0F2744);
      case DisasterType.cyclone:
        return const Color(0xFF0284C7);
      case DisasterType.flood:
        return const Color(0xFF2563EB);
      case DisasterType.earthquake:
        return const Color(0xFF7C3AED);
      case DisasterType.fire:
        return const Color(0xFFDC2626);
      case DisasterType.landslide:
        return const Color(0xFFB45309);
      case DisasterType.tsunami:
        return const Color(0xFF0D9488);
      case DisasterType.other:
        return const Color(0xFFD97706);
    }
  }

  static DisasterType fromString(String? value) {
    if (value == null) return DisasterType.other;
    return DisasterType.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => DisasterType.other,
    );
  }
}
