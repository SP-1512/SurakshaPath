import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_te.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('te')
  ];

  /// The title of the application
  ///
  /// In en, this message translates to:
  /// **'SurakshaPath'**
  String get appName;

  /// App tagline displayed under brand title
  ///
  /// In en, this message translates to:
  /// **'Navigate to Safety.'**
  String get appTagline;

  /// Short description of the app service
  ///
  /// In en, this message translates to:
  /// **'Designated safe path during emergencies'**
  String get appShortDesc;

  /// Bottom navigation label for Home tab
  ///
  /// In en, this message translates to:
  /// **'HOME'**
  String get navHome;

  /// Bottom navigation label for Map tab
  ///
  /// In en, this message translates to:
  /// **'MAP'**
  String get navMap;

  /// Bottom navigation label for Evacuate tab
  ///
  /// In en, this message translates to:
  /// **'EVACUATE'**
  String get navEvacuate;

  /// Bottom navigation label for Shelters tab
  ///
  /// In en, this message translates to:
  /// **'SHELTERS'**
  String get navShelters;

  /// Bottom navigation label for Alerts tab
  ///
  /// In en, this message translates to:
  /// **'ALERTS'**
  String get navAlerts;

  /// Bottom navigation label for SOS action
  ///
  /// In en, this message translates to:
  /// **'SOS'**
  String get navSos;

  /// Badge indicating demo simulation scenario
  ///
  /// In en, this message translates to:
  /// **'DEMO SCENARIO'**
  String get demoScenario;

  /// Badge indicating unverified demo data
  ///
  /// In en, this message translates to:
  /// **'DEMO DATA'**
  String get demoData;

  /// Current language abbreviation
  ///
  /// In en, this message translates to:
  /// **'EN'**
  String get languageLabel;

  /// Action to change language
  ///
  /// In en, this message translates to:
  /// **'Change Language'**
  String get switchLanguage;

  /// Title of the language selection bottom sheet
  ///
  /// In en, this message translates to:
  /// **'Choose Language / భాషను ఎంచుకోండి'**
  String get chooseLanguageTitle;

  /// Label for languages undergoing translation
  ///
  /// In en, this message translates to:
  /// **'Translation in progress'**
  String get translationInProgress;

  /// Label for unreleased features or translations
  ///
  /// In en, this message translates to:
  /// **'Coming Soon'**
  String get comingSoon;

  /// Header for location section
  ///
  /// In en, this message translates to:
  /// **'Current Location'**
  String get sectionLocation;

  /// Header for disaster selection chips
  ///
  /// In en, this message translates to:
  /// **'Select Disaster Context'**
  String get sectionDisasterFilter;

  /// Header for shelter card
  ///
  /// In en, this message translates to:
  /// **'Closest Safe Shelter'**
  String get sectionShelterSpotlight;

  /// Header for active alerts
  ///
  /// In en, this message translates to:
  /// **'Active Hazard Alerts'**
  String get sectionActiveAlerts;

  /// Header for quick actions grid
  ///
  /// In en, this message translates to:
  /// **'Emergency Quick Access'**
  String get sectionQuickActions;

  /// Location timestamp subtitle
  ///
  /// In en, this message translates to:
  /// **'Updated 2m ago'**
  String get locationSubtitle;

  /// Current city location
  ///
  /// In en, this message translates to:
  /// **'Vijayawada Central'**
  String get currentCity;

  /// Current district location
  ///
  /// In en, this message translates to:
  /// **'Krishna District, Andhra Pradesh'**
  String get currentDistrict;

  /// Hero banner alert headline
  ///
  /// In en, this message translates to:
  /// **'[SIMULATION] Flood Warning: Prakasam Barrage'**
  String get heroAlertTitle;

  /// Hero banner alert advisory text
  ///
  /// In en, this message translates to:
  /// **'[DEMO SCENARIO] Krishna River discharge model exceeding danger mark. Riparian zone evacuation demonstration advisory.'**
  String get heroAlertDesc;

  /// Action button on hero alert
  ///
  /// In en, this message translates to:
  /// **'Start evacuation plan'**
  String get startEvacuationPlan;

  /// High risk severity badge
  ///
  /// In en, this message translates to:
  /// **'High Risk'**
  String get highRisk;

  /// Moderate risk severity badge
  ///
  /// In en, this message translates to:
  /// **'Moderate Risk'**
  String get moderateRisk;

  /// Low risk severity badge
  ///
  /// In en, this message translates to:
  /// **'Low Risk'**
  String get lowRisk;

  /// Critical risk severity badge
  ///
  /// In en, this message translates to:
  /// **'Critical'**
  String get criticalRisk;

  /// Preparedness card title
  ///
  /// In en, this message translates to:
  /// **'Preparedness Progress'**
  String get preparednessTitle;

  /// Preparedness steps count
  ///
  /// In en, this message translates to:
  /// **'3 of 5 steps completed'**
  String get preparednessProgress;

  /// Checklist item 1
  ///
  /// In en, this message translates to:
  /// **'Emergency Go-Bag packed'**
  String get checklistItem1;

  /// Checklist item 2
  ///
  /// In en, this message translates to:
  /// **'Essential documents waterproofed'**
  String get checklistItem2;

  /// Checklist item 3
  ///
  /// In en, this message translates to:
  /// **'Offline map pack (Download pending)'**
  String get checklistItem3;

  /// Checklist item 4
  ///
  /// In en, this message translates to:
  /// **'Prescription medicines packed'**
  String get checklistItem4;

  /// Checklist item 5
  ///
  /// In en, this message translates to:
  /// **'Family meeting point confirmed'**
  String get checklistItem5;

  /// Disaster type flood
  ///
  /// In en, this message translates to:
  /// **'Flood'**
  String get disasterFlood;

  /// Disaster type cyclone
  ///
  /// In en, this message translates to:
  /// **'Cyclone'**
  String get disasterCyclone;

  /// Disaster type earthquake
  ///
  /// In en, this message translates to:
  /// **'Earthquake'**
  String get disasterEarthquake;

  /// Disaster type fire
  ///
  /// In en, this message translates to:
  /// **'Fire'**
  String get disasterFire;

  /// Disaster type heatwave
  ///
  /// In en, this message translates to:
  /// **'Heatwave'**
  String get disasterHeatwave;

  /// Nearest shelter header
  ///
  /// In en, this message translates to:
  /// **'Nearest Shelter'**
  String get nearestShelterTitle;

  /// Nearest shelter sample name
  ///
  /// In en, this message translates to:
  /// **'Bhavani Island Relief Center'**
  String get nearestShelterName;

  /// Nearest shelter distance and ETA
  ///
  /// In en, this message translates to:
  /// **'1.8 km • 7 mins away'**
  String get nearestShelterDistance;

  /// Nearest shelter capacity info
  ///
  /// In en, this message translates to:
  /// **'240/400 spots available'**
  String get nearestShelterCapacity;

  /// Action to view shelter details
  ///
  /// In en, this message translates to:
  /// **'View Shelter'**
  String get viewShelter;

  /// Hint for shelter search field
  ///
  /// In en, this message translates to:
  /// **'Search shelters by name or area...'**
  String get searchSheltersHint;

  /// Button to view all shelters
  ///
  /// In en, this message translates to:
  /// **'View All Shelters'**
  String get allShelters;

  /// Find safe shelter title
  ///
  /// In en, this message translates to:
  /// **'Find Safe Shelter'**
  String get findSafeShelter;

  /// Navigate to shelter action button
  ///
  /// In en, this message translates to:
  /// **'Navigate to Shelter'**
  String get navigateToShelter;

  /// Shelter available capacity header
  ///
  /// In en, this message translates to:
  /// **'Available Capacity'**
  String get shelterCapacity;

  /// Designated relief center badge
  ///
  /// In en, this message translates to:
  /// **'Community Relief Center (Unverified)'**
  String get shelterVerifiedBadge;

  /// Quick action: Evac map
  ///
  /// In en, this message translates to:
  /// **'Evac Map'**
  String get quickMap;

  /// Quick action: Evacuate route
  ///
  /// In en, this message translates to:
  /// **'Evacuate'**
  String get quickRoute;

  /// Quick action: Shelters list
  ///
  /// In en, this message translates to:
  /// **'Shelters'**
  String get quickShelters;

  /// Quick action: Offline pack
  ///
  /// In en, this message translates to:
  /// **'Offline Pack'**
  String get quickOffline;

  /// SOS section title
  ///
  /// In en, this message translates to:
  /// **'EMERGENCY SOS'**
  String get emergencySosTitle;

  /// SOS subtitle instructions
  ///
  /// In en, this message translates to:
  /// **'Local Emergency Guide • Quick Dial 112 • Share Coordinates'**
  String get emergencySosSubtitle;

  /// SOS button action
  ///
  /// In en, this message translates to:
  /// **'ACTIVATE SOS'**
  String get emergencySosAction;

  /// Confirmation title for SOS
  ///
  /// In en, this message translates to:
  /// **'Trigger Emergency SOS?'**
  String get sosConfirmTitle;

  /// Confirmation body text for SOS
  ///
  /// In en, this message translates to:
  /// **'Prepare emergency coordinates for sharing and launch direct call to National Emergency Helpline (112). No automated dispatch is active.'**
  String get sosConfirmBody;

  /// Action to call national emergency 112
  ///
  /// In en, this message translates to:
  /// **'Call National Emergency (112)'**
  String get sosDialHelpline;

  /// Instruction to hold SOS button
  ///
  /// In en, this message translates to:
  /// **'HOLD FOR 3 SECONDS'**
  String get holdFor3Seconds;

  /// Instruction to cancel SOS hold
  ///
  /// In en, this message translates to:
  /// **'RELEASE TO CANCEL'**
  String get releaseToCancel;

  /// Confirmation when SOS is triggered
  ///
  /// In en, this message translates to:
  /// **'SOS ACTIVATED!'**
  String get sosActivated;

  /// Call 112 button label
  ///
  /// In en, this message translates to:
  /// **'Call 112 (National Emergency)'**
  String get call112;

  /// Call 108 button label
  ///
  /// In en, this message translates to:
  /// **'Call 108 (Ambulance)'**
  String get call108;

  /// Action to send SMS with coordinates
  ///
  /// In en, this message translates to:
  /// **'Send Location SMS to Contacts'**
  String get sendLocationSms;

  /// Action to copy coordinates to clipboard
  ///
  /// In en, this message translates to:
  /// **'Copy GPS Coordinates'**
  String get copyCoordinates;

  /// Evacuation route header
  ///
  /// In en, this message translates to:
  /// **'Evacuation Guidance'**
  String get routeTitle;

  /// Route start point
  ///
  /// In en, this message translates to:
  /// **'Current Location (Bunder Road)'**
  String get fromLocation;

  /// Route destination point
  ///
  /// In en, this message translates to:
  /// **'Destination: Bhavani Island Center'**
  String get toDestination;

  /// Route distance and duration
  ///
  /// In en, this message translates to:
  /// **'2.4 km • 11 min'**
  String get distanceTime;

  /// Button to begin turn-by-turn guidance
  ///
  /// In en, this message translates to:
  /// **'Start Guidance'**
  String get startGuidance;

  /// Note regarding hazard bypass
  ///
  /// In en, this message translates to:
  /// **'Simulated Hazard Avoidance (Demo): Routing algorithm avoids waterlogged waypoints using sample elevation data.'**
  String get hazardAvoidanceNote;

  /// Indicator that offline data is ready
  ///
  /// In en, this message translates to:
  /// **'Offline Demo (Cache Incomplete)'**
  String get offlineModeActive;

  /// GPS status note
  ///
  /// In en, this message translates to:
  /// **'GPS Active (Simulated Fix)'**
  String get gpsActive;

  /// Button to open evacuation map
  ///
  /// In en, this message translates to:
  /// **'Open Evacuation Map'**
  String get openEvacMap;

  /// Active alerts title
  ///
  /// In en, this message translates to:
  /// **'Active Hazard Alerts'**
  String get activeAlertsTitle;

  /// Earlier or expired alerts title
  ///
  /// In en, this message translates to:
  /// **'Earlier Advisories'**
  String get earlierAlertsTitle;

  /// Message when no active alerts exist
  ///
  /// In en, this message translates to:
  /// **'All Clear: No active warnings in your immediate zone'**
  String get allClear;

  /// Refresh button
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// View details button
  ///
  /// In en, this message translates to:
  /// **'View Details'**
  String get viewDetails;

  /// Dismiss button
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get dismiss;

  /// Advisory text for safe routing
  ///
  /// In en, this message translates to:
  /// **'Follow designated high-ground routes'**
  String get safePathAdvice;

  /// Disclaimer pill shown when safety instruction is in unverified translation
  ///
  /// In en, this message translates to:
  /// **'Unverified Translation: Showing approved English guidance.'**
  String get unverifiedTranslationNotice;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'te'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'te':
      return AppLocalizationsTe();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
