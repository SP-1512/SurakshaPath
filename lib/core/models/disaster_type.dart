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

  String get alertHeadline {
    switch (this) {
      case DisasterType.flood:
        return 'Krishna & Coastal River Basin Flood Advisory';
      case DisasterType.cyclone:
        return 'Severe Cyclonic Storm & Coastal Gale Advisory';
      case DisasterType.earthquake:
        return 'Post-Seismic Tremor & Debris Advisory';
      case DisasterType.tsunami:
        return 'Coastal Tsunami & Tidal Wave Warning';
      case DisasterType.fire:
        return 'Active Urban / Wildfire Hazard Advisory';
      case DisasterType.landslide:
        return 'Hill Slope Landslide & Rockfall Advisory';
      default:
        return 'Disaster Preparedness & Evacuation Advisory';
    }
  }

  String get description {
    switch (this) {
      case DisasterType.flood:
        return 'Waterlogging, canal breaches, and submerged arterial roads.';
      case DisasterType.cyclone:
        return 'Gale-force winds, uprooted trees, and falling structural hoardings.';
      case DisasterType.earthquake:
        return 'Structural collapses, road surface fissures, and debris obstacles.';
      case DisasterType.tsunami:
        return 'Rapid sea level fluctuations, tidal bore, and low-lying coastal flooding.';
      case DisasterType.fire:
        return 'Rapid thermal spread, heavy smoke inhalation hazard, and road closures.';
      case DisasterType.landslide:
        return 'Slope failure, mudslides, and blocked mountain passes.';
      default:
        return 'Active regional disaster condition. Follow verified evacuation guidance.';
    }
  }

  String get iconEmoji {
    switch (this) {
      case DisasterType.flood:
        return '🌊';
      case DisasterType.cyclone:
        return '🌀';
      case DisasterType.earthquake:
        return '🌋';
      case DisasterType.fire:
        return '🔥';
      case DisasterType.landslide:
        return '⛰️';
      case DisasterType.tsunami:
        return '🌊';
      default:
        return '⚠️';
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
