import '../services/locale_service.dart';

/// Centralized bilingual strings (English & Telugu) matching the official v2 specification.
class AppStrings {
  AppStrings._();

  static bool get _isTe => LocaleService.isTelugu;

  // App Identity
  static const String appName = 'SurakshaPath';
  static const String appNameTelugu = 'సురక్షాపథం';
  static String get appTagline => _isTe ? 'భద్రతకు మార్గం.' : 'Navigate to Safety.';
  static String get appShortDesc => _isTe ? 'విపత్తు సమయంలో సురక్షిత మార్గదర్శి' : 'Designated safe path during emergencies';

  // Navigation Items
  static String get navHome => _isTe ? 'హోమ్' : 'HOME';
  static String get navMap => _isTe ? 'మ్యాప్' : 'MAP';
  static String get navEvacuate => _isTe ? 'తరలింపు' : 'EVACUATE';
  static String get navShelters => _isTe ? 'ఆశ్రయాలు' : 'SHELTERS';
  static String get navAlerts => _isTe ? 'హెచ్చరికలు' : 'ALERTS';
  static String get navSos => _isTe ? 'ఎస్ఓఎస్' : 'SOS';

  // Header & Badges
  static const String demoScenario = 'SIMULATION';
  static const String demoData = 'ILLUSTRATIVE DATA';
  static String get languageLabel => _isTe ? 'తెలుగు' : 'EN';
  static String get switchLanguage => _isTe ? 'భాష మార్చండి' : 'Change Language';

  // Home Dashboard Headers & Legacy Constants
  static const String sectionLocation = 'Current Location';
  static const String sectionDisasterFilter = 'Select Disaster Context';
  static const String sectionShelterSpotlight = 'Closest Safe Shelter';
  static const String sectionActiveAlerts = 'Active Hazard Alerts';
  static const String sectionQuickActions = 'Emergency Quick Access';

  // Location Subtitles
  static String get locationSubtitle => _isTe ? '2 నిమిషాల క్రితం అప్‌డేట్ చేయబడింది' : 'Updated 2m ago';
  static String get currentCity => _isTe ? 'విజయవాడ సెంట్రల్' : 'Vijayawada Central';
  static String get currentDistrict => _isTe ? 'కృష్ణా జిల్లా, ఆంధ్రప్రదేశ్' : 'Krishna District, Andhra Pradesh';

  // Hero Card
  static String get heroAlertTitle => _isTe ? 'వరద హెచ్చరిక: ప్రకాశం బ్యారేజ్ ఉత్సర్గం' : 'Flood Warning: Prakasam Barrage Surge';
  static String get heroAlertDesc => _isTe 
      ? 'కృష్ణా నది ఉత్సర్గ నమూనా ప్రమాద స్థాయిని మించింది. లోతట్టు ప్రాంతాల తరలింపు సలహా అమలులో ఉంది.'
      : 'Krishna River discharge model exceeds danger threshold. Riparian zone evacuation guidance in effect for low-lying settlements.';
  static String get startEvacuationPlan => _isTe ? 'తరలింపు ప్రణాళిక ప్రారంభించండి' : 'Start evacuation plan';
  static String get highRisk => _isTe ? 'తీవ్ర ప్రమాదం' : 'High Risk';
  static String get moderateRisk => _isTe ? 'మధ్యస్థ ప్రమాదం' : 'Moderate Risk';
  static String get lowRisk => _isTe ? 'తక్కువ ప్రమాదం' : 'Low Risk';
  static String get criticalRisk => _isTe ? 'అత్యవసర ప్రమాదం' : 'Critical';

  // Preparedness Checklist
  static String get preparednessTitle => _isTe ? 'తయారీ పురోగతి' : 'Preparedness Progress';
  static String get preparednessProgress => _isTe ? '5 లో 3 అంశాలు పూర్తయ్యాయి' : '3 of 5 steps completed';
  static String get checklistItem1 => _isTe ? 'ఎమర్జెన్సీ బ్యాగ్ సిద్ధం' : 'Emergency Go-Bag packed';
  static String get checklistItem2 => _isTe ? 'ముఖ్యమైన పత్రాలు భద్రపరిచాం' : 'Essential documents waterproofed';
  static String get checklistItem3 => _isTe ? 'ఆఫ్‌లైన్ మ్యాప్ ప్యాక్ (డౌన్‌లోడ్ పెండింగ్‌లో ఉంది)' : 'Offline map pack (Download pending)';
  static String get checklistItem4 => _isTe ? 'మందులు మరియు ప్రథమ చికిత్స' : 'Prescription medicines packed';
  static String get checklistItem5 => _isTe ? 'కుటుంబ తరలింపు ప్రణాళిక నిర్ధారించబడింది' : 'Family meeting point confirmed';

  // Disaster Types
  static String get flood => _isTe ? 'వరద' : 'Flood';
  static String get cyclone => _isTe ? 'తుఫాను' : 'Cyclone';
  static String get earthquake => _isTe ? 'భూకంపం' : 'Earthquake';
  static String get fire => _isTe ? 'అగ్నిప్రమాదం' : 'Fire';
  static String get heatwave => _isTe ? 'వడగాల్పులు' : 'Heatwave';

  // Shelter Section
  static String get nearestShelterTitle => _isTe ? 'సమీప ఆశ్రయం' : 'Nearest Shelter';
  static String get nearestShelterName => _isTe ? 'భవాని ద్వీపం సహాయ కేంద్రం' : 'Bhavani Island Relief Center';
  static String get nearestShelterDistance => _isTe ? '1.8 కి.మీ • 7 నిమిషాలు' : '1.8 km • 7 mins away';
  static String get nearestShelterCapacity => _isTe ? 'సామర్థ్యం: ధృవీకరించబడలేదు (డెమో)' : 'Capacity: Unverified (Demo)';
  static String get viewShelter => _isTe ? 'ఆశ్రయాన్ని చూడండి' : 'View Shelter';
  static String get searchSheltersHint => _isTe ? 'పేరు లేదా ప్రాంతం ద్వారా వెతకండి...' : 'Search shelters by name or area...';
  static const String allShelters = 'View All Shelters';
  static const String findSafeShelter = 'Find Safe Shelter';
  static const String navigateToShelter = 'Navigate to Shelter';
  static String get shelterCapacity => _isTe ? 'ఆశ్రయ సామర్థ్యం (ధృవీకరించబడలేదు)' : 'Shelter Capacity (Unverified)';
  static const String shelterVerifiedBadge = 'Community Relief Center (Unverified)';

  // Quick Actions
  static String get quickMap => _isTe ? 'మ్యాప్' : 'Evac Map';
  static String get quickRoute => _isTe ? 'తరలింపు' : 'Evacuate';
  static String get quickShelters => _isTe ? 'ఆశ్రయాలు' : 'Shelters';
  static String get quickOffline => _isTe ? 'ఆఫ్‌లైన్ ప్యాక్' : 'Offline Pack';

  // Emergency SOS
  static String get emergencySosTitle => _isTe ? 'అత్యవసర SOS' : 'Emergency SOS';
  static String get emergencySosSubtitle => _isTe ? 'ఎమర్జెన్సీ గైడ్ • క్విక్ డయల్ 112 • కోఆర్డినేట్లు' : 'Local Guide • Quick Dial 112 • Share Details';
  static const String emergencySosAction = 'ACTIVATE SOS';
  static const String sosConfirmTitle = 'Trigger Emergency SOS?';
  static const String sosConfirmBody =
      'Prepare emergency coordinates for sharing and launch direct call to National Emergency Helpline (112). No automated dispatch is active.';
  static const String sosDialHelpline = 'Call National Emergency (112)';
  static String get holdFor3Seconds => _isTe ? '3 సెకన్ల పాటు నొక్కి ఉంచండి' : 'HOLD FOR 3 SECONDS';
  static String get releaseToCancel => _isTe ? 'రద్దు చేయడానికి విడుదల చేయండి' : 'RELEASE TO CANCEL';
  static String get sosActivated => _isTe ? 'ఎస్ఓఎస్ సక్రియం చేయబడింది!' : 'SOS ACTIVATED!';
  static String get call112 => _isTe ? '112 కాల్ చేయండి (జాతీయ అత్యవసర)' : 'Call 112 (National Emergency)';
  static String get call108 => _isTe ? '108 కాల్ చేయండి (అంబులెన్స్)' : 'Call 108 (Ambulance)';
  static String get sendLocationSms => _isTe ? 'పరిచయాలకు లొకేషన్ SMS పంపండి' : 'Send Location SMS to Contacts';
  static String get copyCoordinates => _isTe ? 'కోఆర్డినేట్‌లను కాపీ చేయండి' : 'Copy Coordinates';

  // Evacuate / Routing
  static String get routeTitle => _isTe ? 'తరలింపు మార్గదర్శకత్వం' : 'Evacuation Guidance';
  static String get fromLocation => _isTe ? 'ప్రస్తుత స్థానం (బందరు రోడ్డు)' : 'Current Location (Bunder Road)';
  static String get toDestination => _isTe ? 'గమ్యం: భవాని ద్వీపం కేంద్రం' : 'Destination: Bhavani Island Center';
  static String get distanceTime => _isTe ? '2.4 కి.మీ • 11 నిమిషాలు' : '2.4 km • 11 min';
  static String get startGuidance => _isTe ? 'మార్గదర్శకత్వం ప్రారంభించండి' : 'Start Guidance';
  static String get hazardAvoidanceNote => _isTe 
      ? 'అనుకరణ ప్రమాద నివారణ (డెమో): నమూనా ఎలివేషన్ డేటాను ఉపయోగించి నీటి ఎద్దడి ఉన్న మార్గాలను నివారించే ప్రదర్శన మార్గం. రోడ్డు భద్రత ప్రత్యక్షంగా ధృవీకరించబడలేదు.'
      : 'Simulated Hazard Avoidance (Demo): Routing algorithm avoids sample waterlogged waypoints using synthetic elevation model. Road clearance not physically verified.';

  // Map & Offline
  static const String offlineModeActive = 'Offline Mode (Planned Capability)';
  static const String gpsActive = 'GPS Active (Simulated Fix)';
  static const String openEvacMap = 'Open Evacuation Map';

  // Alerts
  static String get activeAlertsTitle => _isTe ? 'క్రియాశీల హెచ్చరికలు' : 'Active Hazard Alerts';
  static String get earlierAlertsTitle => _isTe ? 'మునుపటి హెచ్చరికలు' : 'Earlier Advisories';
  static String get allClear => _isTe ? 'మీ ప్రాంతంలో ప్రస్తుతం ఎలాంటి హెచ్చరికలు లేవు' : 'All Clear: No active warnings in your immediate zone';

  // Actions
  static const String refresh = 'Refresh';
  static const String viewDetails = 'View Details';
  static const String dismiss = 'Dismiss';
  static const String safePathAdvice = 'Follow designated high-ground routes';
}
