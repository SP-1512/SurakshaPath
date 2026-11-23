/// Centralized layout metrics and accessibility guidelines from SurakshaPath UI Design (1).pdf (Page 1).
class AppDimensions {
  AppDimensions._();

  // Spacing (4 pt grid)
  static const double space4 = 4.0;
  static const double space8 = 8.0;
  static const double space12 = 12.0;
  static const double space16 = 16.0;
  static const double space20 = 20.0;
  static const double space24 = 24.0;
  static const double space32 = 32.0;
  static const double space48 = 48.0;

  // Aliases for compatibility
  static const double space2 = 2.0;
  static const double space6 = 6.0;
  static const double space10 = 10.0;
  static const double space14 = 14.0;
  static const double space40 = 40.0;
  static const double space64 = 64.0;

  // Radii from PDF (8, 16, 24, pill)
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 14.0; // Button & Input radius
  static const double radiusLarge = 16.0; // Card radius
  static const double radiusXLarge = 24.0; // Hero card radius
  static const double radiusPill = 999.0; // Header SOS pill & chips

  // Heights from PDF
  static const double buttonHeight = 52.0;
  static const double inputHeight = 48.0;
  static const double chipHeight = 36.0;
  static const double bottomNavHeight = 80.0;
  static const double headerSosPillHeight = 44.0;

  // Touch Target Minimums
  static const double minTouchTarget = 48.0;
  static const double iconSizeSmall = 18.0;
  static const double iconSizeMedium = 24.0;
  static const double iconSizeLarge = 32.0;
}
