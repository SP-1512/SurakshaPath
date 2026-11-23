import 'package:flutter/material.dart';

/// Official design system colors specified in SurakshaPath UI Design (1).pdf (Page 1).
class AppColors {
  AppColors._();

  // Core Palette
  static const Color primaryBlue = Color(0xFF1E3A8A); // Primary Blue
  static const Color secondaryBlue = Color(0xFF3B82F6); // Secondary Blue
  static const Color emerald = Color(0xFF10B981); // Emerald (Go / Start)
  static const Color ink = Color(0xFF0F172A); // Primary text
  static const Color slate = Color(0xFF64748B); // Secondary text / metadata
  static const Color surface = Color(0xFFF8FAFC); // Quiet section and card surface
  static const Color border = Color(0xFFE2E8F0); // Hairline borders
  static const Color critical = Color(0xFFDC2626); // Critical / SOS Red
  static const Color high = Color(0xFFF97316); // High warning Orange
  static const Color moderate = Color(0xFFF59E0B); // Moderate risk Amber

  // Compatibility aliases
  static const Color primary = primaryBlue;
  static const Color primaryDark = Color(0xFF0F172A);
  static const Color primaryLight = secondaryBlue;
  static const Color brandBlueDeep = primaryBlue;
  static const Color brandBlueBright = secondaryBlue;
  static const Color secondary = secondaryBlue;
  static const Color emeraldGreen = emerald;
  static const Color emeraldGreenLight = Color(0xFFD1FAE5);
  static const Color emergencyRed = critical;
  static const Color emergencyRedDark = Color(0xFF991B1B);
  static const Color emergencyRedLight = Color(0xFFFEE2E2);
  static const Color warningOrange = high;
  static const Color warningAmber = moderate;
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color background = Colors.white;
  static const Color surfaceSoft = surface;
  static const Color surfaceMuted = Color(0xFFF1F5F9);
  static const Color surfaceNavy = Color(0xFF142C4C);
  static const Color surfaceDark = Color(0xFF0F172A);
  static const Color textPrimary = ink;
  static const Color textSecondary = slate;
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color textOnPrimary = Colors.white;
  static const Color textOnEmergency = Colors.white;
  static const Color safetyGreen = emerald;

  // Severity colors
  static const Color severityCritical = critical;
  static const Color severityWarning = high;
  static const Color severityWatch = moderate;
  static const Color severityAdvisory = secondaryBlue;

  // Status colors
  static const Color statusOpen = emerald;
  static const Color statusNearFull = moderate;
  static const Color statusFull = critical;
  static const Color statusClosed = slate;

  // Official Brand Gradient
  static const LinearGradient brandGradient = LinearGradient(
    colors: [primaryBlue, secondaryBlue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Dark Navy Hero Gradient for Top Header
  static const LinearGradient headerDarkGradient = LinearGradient(
    colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
