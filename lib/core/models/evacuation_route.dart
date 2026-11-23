import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

export '../../features/routing/route_model.dart' hide RouteSafetyStatus;

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
