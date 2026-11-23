// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'SurakshaPath';

  @override
  String get appTagline => 'Navigate to Safety.';

  @override
  String get appShortDesc => 'Designated safe path during emergencies';

  @override
  String get navHome => 'HOME';

  @override
  String get navMap => 'MAP';

  @override
  String get navEvacuate => 'EVACUATE';

  @override
  String get navShelters => 'SHELTERS';

  @override
  String get navAlerts => 'ALERTS';

  @override
  String get navSos => 'SOS';

  @override
  String get demoScenario => 'DEMO SCENARIO';

  @override
  String get demoData => 'DEMO DATA';

  @override
  String get languageLabel => 'EN';

  @override
  String get switchLanguage => 'Change Language';

  @override
  String get chooseLanguageTitle => 'Choose Language / భాషను ఎంచుకోండి';

  @override
  String get translationInProgress => 'Translation in progress';

  @override
  String get comingSoon => 'Coming Soon';

  @override
  String get sectionLocation => 'Current Location';

  @override
  String get sectionDisasterFilter => 'Select Disaster Context';

  @override
  String get sectionShelterSpotlight => 'Closest Safe Shelter';

  @override
  String get sectionActiveAlerts => 'Active Hazard Alerts';

  @override
  String get sectionQuickActions => 'Emergency Quick Access';

  @override
  String get locationSubtitle => 'Updated 2m ago';

  @override
  String get currentCity => 'Vijayawada Central';

  @override
  String get currentDistrict => 'Krishna District, Andhra Pradesh';

  @override
  String get heroAlertTitle => '[SIMULATION] Flood Warning: Prakasam Barrage';

  @override
  String get heroAlertDesc =>
      '[DEMO SCENARIO] Krishna River discharge model exceeding danger mark. Riparian zone evacuation demonstration advisory.';

  @override
  String get startEvacuationPlan => 'Start evacuation plan';

  @override
  String get highRisk => 'High Risk';

  @override
  String get moderateRisk => 'Moderate Risk';

  @override
  String get lowRisk => 'Low Risk';

  @override
  String get criticalRisk => 'Critical';

  @override
  String get preparednessTitle => 'Preparedness Progress';

  @override
  String get preparednessProgress => '3 of 5 steps completed';

  @override
  String get checklistItem1 => 'Emergency Go-Bag packed';

  @override
  String get checklistItem2 => 'Essential documents waterproofed';

  @override
  String get checklistItem3 => 'Offline map pack (Download pending)';

  @override
  String get checklistItem4 => 'Prescription medicines packed';

  @override
  String get checklistItem5 => 'Family meeting point confirmed';

  @override
  String get disasterFlood => 'Flood';

  @override
  String get disasterCyclone => 'Cyclone';

  @override
  String get disasterEarthquake => 'Earthquake';

  @override
  String get disasterFire => 'Fire';

  @override
  String get disasterHeatwave => 'Heatwave';

  @override
  String get nearestShelterTitle => 'Nearest Shelter';

  @override
  String get nearestShelterName => 'Bhavani Island Relief Center';

  @override
  String get nearestShelterDistance => '1.8 km • 7 mins away';

  @override
  String get nearestShelterCapacity => '240/400 spots available';

  @override
  String get viewShelter => 'View Shelter';

  @override
  String get searchSheltersHint => 'Search shelters by name or area...';

  @override
  String get allShelters => 'View All Shelters';

  @override
  String get findSafeShelter => 'Find Safe Shelter';

  @override
  String get navigateToShelter => 'Navigate to Shelter';

  @override
  String get shelterCapacity => 'Available Capacity';

  @override
  String get shelterVerifiedBadge => 'Community Relief Center (Unverified)';

  @override
  String get quickMap => 'Evac Map';

  @override
  String get quickRoute => 'Evacuate';

  @override
  String get quickShelters => 'Shelters';

  @override
  String get quickOffline => 'Offline Pack';

  @override
  String get emergencySosTitle => 'EMERGENCY SOS';

  @override
  String get emergencySosSubtitle =>
      'Local Emergency Guide • Quick Dial 112 • Share Coordinates';

  @override
  String get emergencySosAction => 'ACTIVATE SOS';

  @override
  String get sosConfirmTitle => 'Trigger Emergency SOS?';

  @override
  String get sosConfirmBody =>
      'Prepare emergency coordinates for sharing and launch direct call to National Emergency Helpline (112). No automated dispatch is active.';

  @override
  String get sosDialHelpline => 'Call National Emergency (112)';

  @override
  String get holdFor3Seconds => 'HOLD FOR 3 SECONDS';

  @override
  String get releaseToCancel => 'RELEASE TO CANCEL';

  @override
  String get sosActivated => 'SOS ACTIVATED!';

  @override
  String get call112 => 'Call 112 (National Emergency)';

  @override
  String get call108 => 'Call 108 (Ambulance)';

  @override
  String get sendLocationSms => 'Send Location SMS to Contacts';

  @override
  String get copyCoordinates => 'Copy GPS Coordinates';

  @override
  String get routeTitle => 'Evacuation Guidance';

  @override
  String get fromLocation => 'Current Location (Bunder Road)';

  @override
  String get toDestination => 'Destination: Bhavani Island Center';

  @override
  String get distanceTime => '2.4 km • 11 min';

  @override
  String get startGuidance => 'Start Guidance';

  @override
  String get hazardAvoidanceNote =>
      'Simulated Hazard Avoidance (Demo): Routing algorithm avoids waterlogged waypoints using sample elevation data.';

  @override
  String get offlineModeActive => 'Offline Demo (Cache Incomplete)';

  @override
  String get gpsActive => 'GPS Active (Simulated Fix)';

  @override
  String get openEvacMap => 'Open Evacuation Map';

  @override
  String get activeAlertsTitle => 'Active Hazard Alerts';

  @override
  String get earlierAlertsTitle => 'Earlier Advisories';

  @override
  String get allClear => 'All Clear: No active warnings in your immediate zone';

  @override
  String get refresh => 'Refresh';

  @override
  String get viewDetails => 'View Details';

  @override
  String get dismiss => 'Dismiss';

  @override
  String get safePathAdvice => 'Follow designated high-ground routes';

  @override
  String get unverifiedTranslationNotice =>
      'Unverified Translation: Showing approved English guidance.';
}
