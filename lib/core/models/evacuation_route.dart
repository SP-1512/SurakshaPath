import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

enum RouteSafetyStatus {
  safe,
  caution,
  blocked,
  simulated;

  String get label {
    switch (this) {
      case RouteSafetyStatus.safe:
        return 'SAFE PATH';
      case RouteSafetyStatus.caution:
        return 'USE CAUTION';
      case RouteSafetyStatus.blocked:
        return 'HAZARD BLOCKED';
      case RouteSafetyStatus.simulated:
        return 'SIMULATED CORRIDOR (DEMO)';
    }
  }

  Color get color {
    switch (this) {
      case RouteSafetyStatus.safe:
        return AppColors.safetyGreen;
      case RouteSafetyStatus.caution:
        return AppColors.warningOrange;
      case RouteSafetyStatus.blocked:
        return AppColors.emergencyRed;
      case RouteSafetyStatus.simulated:
        return AppColors.primaryBlue;
    }
  }
}

/// Evacuation route data model for routing team integration.
class EvacuationRoute {
  final String id;
  final String title;
  final String destinationShelterId;
  final String destinationShelterName;
  final double distanceKm;
  final int estimatedTimeMinutes;
  final RouteSafetyStatus safetyStatus;
  final String roadConditionSummary;
  final List<String> warnings;

  const EvacuationRoute({
    required this.id,
    required this.title,
    required this.destinationShelterId,
    required this.destinationShelterName,
    required this.distanceKm,
    required this.estimatedTimeMinutes,
    required this.safetyStatus,
    required this.roadConditionSummary,
    this.warnings = const [],
  });
}
