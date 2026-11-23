import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/models/user_location.dart';
import '../../../core/services/locale_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/user_profile_service.dart';
import '../../../core/widgets/demo_badge.dart';
import '../../../navigation/main_navigation_shell.dart';

/// Complete Onboarding Flow matching screens 02 through 07 in the v2 design package.
/// Guides user through Language, Location Permission & Acquisition, Household Headcount,
/// and initial Hazard Briefing before entering the main dashboard.
class OnboardingScreen extends StatefulWidget {
  final ILocationService? locationService;
  final VoidCallback? onComplete;

  const OnboardingScreen({
    super.key,
    this.locationService,
    this.onComplete,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final ILocationService _locationService;
  final PageController _pageController = PageController();
  int _currentStep = 0;

  // Step 1: Language
  String _selectedLanguage = 'en';

  // Step 2 & 3: Location State Machine
  bool _isLocating = false;
  String? _locationErrorMessage;
  UserLocation? _detectedLocation;

  // Step 5: People With You
  int _adults = 0;
  int _children = 0;
  int _seniors = 0;
  int _pets = 0;
  bool _needsMobilityAssistance = false;

  bool get _isTe => LocaleService.isTelugu;

  @override
  void initState() {
    super.initState();
    _locationService = widget.locationService ?? DeviceLocationService();
    _selectedLanguage = LocaleService.currentLocale.value;

    // Load existing profile defaults if previously partially stored
    final existing = UserProfileService.currentProfile;
    if (existing.location != null) {
      _detectedLocation = existing.location;
    }
    if (existing.isHeadcountConfigured) {
      _adults = existing.adults ?? 0;
      _children = existing.children ?? 0;
      _seniors = existing.seniors ?? 0;
      _pets = existing.pets ?? 0;
      _needsMobilityAssistance = existing.needsMobilityAssistance;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToStep(int step) {
    setState(() => _currentStep = step);
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _nextPage() {
    if (_currentStep < 3) {
      _goToStep(_currentStep + 1);
    } else {
      _finishOnboarding();
    }
  }

  Future<void> _finishOnboarding() async {
    await UserProfileService.completeOnboarding();
    if (widget.onComplete != null) {
      widget.onComplete!();
    } else if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainNavigationShell()),
      );
    }
  }

  // --- LOCATION ACQUISITION LOGIC ---

  Future<void> _requestLocationAccess() async {
    setState(() {
      _isLocating = true;
      _locationErrorMessage = null;
    });

    try {
      final service = _locationService;
      final LocationPermissionStatus status;
      if (service is IDeviceLocationService) {
        status = await service.requestPermission();
      } else {
        status = LocationPermissionStatus.granted;
      }

      if (status == LocationPermissionStatus.granted) {
        // Attempt actual GPS fix acquisition
        await _acquireGpsFix();
      } else if (status == LocationPermissionStatus.serviceDisabled) {
        setState(() {
          _isLocating = false;
          _locationErrorMessage = _isTe
              ? 'మీ పరికరంలో లొకేషన్ సర్వీసులు నిలిపివేయబడ్డాయి. దయచేసి GPS ఆన్ చేయండి.'
              : 'Location services are disabled on this device. Please turn on GPS.';
        });
      } else if (status == LocationPermissionStatus.permanentlyDenied) {
        setState(() {
          _isLocating = false;
          _locationErrorMessage = _isTe
              ? 'లొకేషన్ అనుమతి శాశ్వతంగా నిరాకరించబడింది. యాప్ సెట్టింగ్స్‌లో అనుమతించండి.'
              : 'Location permission is permanently denied. Please enable it in App Settings.';
        });
      } else {
        setState(() {
          _isLocating = false;
          _locationErrorMessage = _isTe
              ? 'లొకేషన్ అనుమతి నిరాకరించబడింది. ఖచ్చితమైన భద్రతా మార్గాల కోసం అనుమతించండి.'
              : 'Location permission was denied. Allow access to receive local disaster guidance.';
        });
      }
    } catch (e) {
      setState(() {
        _isLocating = false;
        _locationErrorMessage = 'Error: $e';
      });
    }
  }

  Future<void> _acquireGpsFix() async {
    setState(() {
      _isLocating = true;
      _locationErrorMessage = null;
    });

    try {
      final location = await _locationService.getCurrentLocation();
      setState(() {
        _detectedLocation = location;
        _isLocating = false;
      });
      await UserProfileService.updateLocation(location);
    } on TimeoutException {
      setState(() {
        _isLocating = false;
        _locationErrorMessage = _isTe
            ? 'GPS సిగ్నల్ పొందడంలో సమయం ముగిసింది. దయచేసి మళ్లీ ప్రయత్నించండి లేదా మాన్యువల్‌గా ఎంచుకోండి.'
            : 'Acquiring GPS fix timed out. Please retry or choose your corridor manually.';
      });
    } catch (e) {
      setState(() {
        _isLocating = false;
        _locationErrorMessage = _isTe
            ? 'GPS స్థానం పొందడం సాధ్యం కాలేదు. దయచేసి మాన్యువల్‌గా ఎంచుకోండి.'
            : 'Unable to acquire GPS fix. Please select your corridor manually.';
      });
    }
  }

  void _selectManualLocation(UserLocation loc) {
    setState(() {
      _detectedLocation = loc;
      _locationErrorMessage = null;
      _isLocating = false;
    });
    UserProfileService.updateLocation(loc);
  }

  void _showManualLocationPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final options = [
          {
            'name': 'Kakinada Port Corridor',
            'district': 'Kakinada District, Andhra Pradesh',
            'lat': 16.9891,
            'lon': 82.2475,
          },
          {
            'name': 'Vijayawada Central',
            'district': 'Krishna District, Andhra Pradesh',
            'lat': 16.5062,
            'lon': 80.6480,
          },
          {
            'name': 'Visakhapatnam Harbor Sector',
            'district': 'Visakhapatnam District, Andhra Pradesh',
            'lat': 17.6868,
            'lon': 83.2185,
          },
          {
            'name': 'Machilipatnam Coastal Zone',
            'district': 'Krishna District, Andhra Pradesh',
            'lat': 16.1875,
            'lon': 81.1389,
          },
          {
            'name': 'Guntur Plain Sector',
            'district': 'Guntur District, Andhra Pradesh',
            'lat': 16.3067,
            'lon': 80.4365,
          },
          {
            'name': 'Bapatla Coastal Sector',
            'district': 'Bapatla District, Andhra Pradesh',
            'lat': 15.9042,
            'lon': 80.4674,
          },
          {
            'name': 'Ongole Coastal Sector',
            'district': 'Prakasam District, Andhra Pradesh',
            'lat': 15.5057,
            'lon': 80.0499,
          },
          {
            'name': 'Amalapuram Konaseema Sector',
            'district': 'Dr. B.R. Ambedkar Konaseema District, Andhra Pradesh',
            'lat': 16.5787,
            'lon': 82.0061,
          },
          {
            'name': 'SPSR Nellore Coastal Zone',
            'district': 'SPSR Nellore District, Andhra Pradesh',
            'lat': 14.4426,
            'lon': 79.9865,
          },
          {
            'name': 'Rajahmundry Godavari Basin',
            'district': 'East Godavari District, Andhra Pradesh',
            'lat': 17.0005,
            'lon': 81.8040,
          },
          {
            'name': 'Srikakulam Coastal Sector',
            'district': 'Srikakulam District, Andhra Pradesh',
            'lat': 18.2949,
            'lon': 83.8938,
          },
        ];

        return SafeArea(
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.75,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  _isTe ? 'మీ ప్రాంతాన్ని ఎంచుకోండి' : 'Choose your region manually',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink),
                ),
                const SizedBox(height: 4),
                Text(
                  _isTe
                      ? 'తీరప్రాంత ఆంధ్రప్రదేశ్ జిల్లాలు మరియు అత్యవసర కారిడార్లు (మాన్యువల్ ఎంపిక)'
                      : 'Coastal Andhra Pradesh districts & emergency corridors (Manual selection)',
                  style: const TextStyle(fontSize: 12, color: AppColors.slate),
                ),
                const Divider(height: 24, color: AppColors.border),
                Expanded(
                  child: ListView.separated(
                    itemCount: options.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
                    itemBuilder: (context, index) {
                      final item = options[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        leading: const Icon(Icons.location_on_outlined, color: AppColors.primaryBlue),
                        title: Text(
                          item['name'] as String,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        subtitle: Text(
                          item['district'] as String,
                          style: const TextStyle(fontSize: 12, color: AppColors.slate),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.slate),
                        onTap: () {
                          Navigator.pop(ctx);
                          _selectManualLocation(
                            UserLocation.manual(
                              latitude: item['lat'] as double,
                              longitude: item['lon'] as double,
                              locationName: item['name'] as String,
                              subArea: item['district'] as String,
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- BUILD METHOD ---

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: LocaleService.currentLocale,
      builder: (context, locale, _) {
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: _currentStep > 0
                ? IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: AppColors.ink),
                    onPressed: () => _goToStep(_currentStep - 1),
                  )
                : null,
            title: Row(
              children: [
                const Spacer(),
                Text(
                  'Step ${_currentStep + 1} of 4',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.slate,
                  ),
                ),
                const SizedBox(width: 8),
                const DemoBadge(label: 'SETUP'),
              ],
            ),
          ),
          body: PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            onPageChanged: (page) => setState(() => _currentStep = page),
            children: [
              _buildLanguageStep(),
              _buildLocationStep(),
              _buildPeopleStep(),
              _buildScenarioStep(),
            ],
          ),
        );
      },
    );
  }

  // --- STEP 1: CHOOSE LANGUAGE (02_1_Choose_language.png) ---
  Widget _buildLanguageStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isTe ? 'మీ భాషను ఎంచుకోండి' : 'Choose your language',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _isTe ? 'మీకు సౌకర్యంగా ఉండే భాషను ఎంచుకోండి' : 'Select your preferred language for emergency alerts',
            style: const TextStyle(fontSize: 15, color: AppColors.slate),
          ),
          const SizedBox(height: 32),

          _buildLanguageCard(
            code: 'en',
            name: 'English',
            subtitle: 'Default language • Navigate to Safety',
          ),
          const SizedBox(height: 16),
          _buildLanguageCard(
            code: 'te',
            name: 'తెలుగు (Telugu)',
            subtitle: 'స్థానిక భాష • భద్రతకు మార్గం',
          ),

          const SizedBox(height: 48),
          ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: double.infinity,
              minHeight: AppDimensions.buttonHeight,
            ),
            child: ElevatedButton(
              onPressed: () async {
                await UserProfileService.updateLanguage(_selectedLanguage);
                _nextPage();
              },
              child: Text(_isTe ? 'కొనసాగించండి' : 'Continue'),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildLanguageCard({required String code, required String name, required String subtitle}) {
    final isSelected = _selectedLanguage == code;
    return InkWell(
      onTap: () {
        setState(() => _selectedLanguage = code);
        LocaleService.setLocale(code);
        UserProfileService.updateLanguage(code);
      },
      borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryBlue.withValues(alpha: 0.04) : Colors.white,
          borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
          border: Border.all(
            color: isSelected ? AppColors.primaryBlue : AppColors.border,
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? AppColors.primaryBlue : AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 13, color: AppColors.slate),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
              color: isSelected ? AppColors.primaryBlue : AppColors.border,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  // --- STEP 2, 3, 4: LOCATION PERMISSION & CONFIRMATION ---
  Widget _buildLocationStep() {
    final hasFix = _detectedLocation != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isTe ? 'మీరు ఎక్కడ ఉన్నారు?' : 'Where are you?',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isTe
                ? 'స్థానిక ప్రమాదాలను గుర్తించడానికి, సమీప ఆశ్రయాలను చూపించడానికి మరియు సురక్షిత తరలింపు మార్గాలను అందించడానికి సురక్షపాత్‌కు మీ స్థానం అవసరం.'
                : 'SurakshaPath needs your location to identify active local hazards, map open shelters, and compute safe evacuation routes.',
            style: const TextStyle(fontSize: 15, color: AppColors.slate, height: 1.4),
          ),
          const SizedBox(height: 32),

          // Central Visual Indicator
          Center(
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: hasFix
                    ? AppColors.emerald.withValues(alpha: 0.1)
                    : (_isLocating
                        ? AppColors.primaryBlue.withValues(alpha: 0.1)
                        : (_locationErrorMessage != null
                            ? AppColors.critical.withValues(alpha: 0.08)
                            : AppColors.primaryBlue.withValues(alpha: 0.06))),
                shape: BoxShape.circle,
                border: Border.all(
                  color: hasFix
                      ? AppColors.emerald
                      : (_locationErrorMessage != null
                          ? AppColors.critical.withValues(alpha: 0.5)
                          : AppColors.primaryBlue.withValues(alpha: 0.2)),
                  width: 2.0,
                ),
              ),
              child: _isLocating
                  ? const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
                      ),
                    )
                  : Icon(
                      hasFix
                          ? Icons.check_circle_outline_rounded
                          : (_locationErrorMessage != null
                              ? Icons.location_off_rounded
                              : Icons.my_location_rounded),
                      size: 64,
                      color: hasFix
                          ? AppColors.emerald
                          : (_locationErrorMessage != null ? AppColors.critical : AppColors.primaryBlue),
                    ),
            ),
          ),
          const SizedBox(height: 20),

          // Status & Detected Location Card
          if (_isLocating) ...[
            Center(
              child: Column(
                children: [
                  Text(
                    _isTe ? 'GPS స్థానాన్ని గుర్తిస్తోంది...' : 'Acquiring GPS fix...',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.primaryBlue),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isTe
                        ? 'ఉపగ్రహ సిగ్నల్ మరియు ఖచ్చితమైన రీడింగ్ కోసం వేచి చూస్తోంది'
                        : 'Contacting device GPS satellites for authentic fix',
                    style: const TextStyle(fontSize: 12, color: AppColors.slate),
                  ),
                ],
              ),
            ),
          ] else if (hasFix) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _isTe ? 'గుర్తించబడిన స్థానం' : 'Location Detected',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.slate),
                        ),
                      ),
                      DemoBadge(label: _detectedLocation!.provenance.label),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _detectedLocation!.locationName,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _detectedLocation!.subArea,
                    style: const TextStyle(fontSize: 13, color: AppColors.slate),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _detectedLocation!.formattedCoordinates +
                        (_detectedLocation!.accuracyMeters != null
                            ? ' (±${_detectedLocation!.accuracyMeters!.toStringAsFixed(1)}m telemetry)'
                            : ' (No GPS telemetry)'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _detectedLocation!.isLiveFix ? AppColors.emerald : AppColors.slate,
                    ),
                  ),
                ],
              ),
            ),
          ] else if (_locationErrorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.critical.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                border: Border.all(color: AppColors.critical.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppColors.critical, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _locationErrorMessage!,
                      style: const TextStyle(fontSize: 13, color: AppColors.critical, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Center(
              child: Text(
                _isTe
                    ? 'ప్రత్యక్ష మార్గదర్శకత్వం కోసం GPS అనుమతి అవసరం'
                    : 'GPS permission required for authentic live guidance',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.slate),
              ),
            ),
          ],

          const SizedBox(height: 32),

          // Primary Action Button
          if (!hasFix) ...[
            ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: double.infinity,
                minHeight: AppDimensions.buttonHeight,
              ),
              child: ElevatedButton.icon(
                onPressed: _isLocating ? null : _requestLocationAccess,
                icon: const Icon(Icons.location_on_rounded, size: 20),
                label: Text(_isTe ? 'లొకేషన్ అనుమతించండి' : 'Allow Location Access'),
              ),
            ),
          ] else ...[
            ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: double.infinity,
                minHeight: AppDimensions.buttonHeight,
              ),
              child: ElevatedButton(
                onPressed: _nextPage,
                child: Text(_isTe ? 'నిర్ధారించి కొనసాగించండి' : 'Confirm & Continue'),
              ),
            ),
          ],
          const SizedBox(height: 12),

          // Manual and Demo Fallback Options
          Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: _showManualLocationPicker,
                  icon: const Icon(Icons.edit_location_alt_outlined, size: 16),
                  label: Text(
                    _isTe ? 'మాన్యువల్‌గా ఎంచుకోండి' : 'Choose manually',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    _selectManualLocation(UserLocation.mockDefault());
                  },
                  child: Text(
                    _isTe ? 'డెమో స్థానం (కాకినాడ)' : 'Use Demo Location',
                    style: const TextStyle(color: AppColors.slate, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // --- STEP 5: PEOPLE WITH YOU (06_5_People_with_you.png) ---
  Widget _buildPeopleStep() {
    final totalPeople = _adults + _children + _seniors;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isTe ? 'మీతో ఎవరు ఉన్నారు?' : 'Who is with you?',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _isTe
                ? 'సరిపోయే ఆశ్రయాలను సిఫార్సు చేయడానికి మరియు మీ SOS ప్యాకెట్‌ను సిద్ధం చేయడానికి సహాయపడుతుంది.'
                : 'Helps recommend suitable shelters and prepares your SOS broadcast package.',
            style: const TextStyle(fontSize: 14, color: AppColors.slate),
          ),
          const SizedBox(height: 20),

          // Household Summary Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _isTe
                        ? 'మొత్తం వ్యక్తులు: $totalPeople • జంతువులు: $_pets'
                        : 'Total People: $totalPeople • Pets: $_pets',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.ink),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  totalPeople == 0 ? (_isTe ? '(ధృవీకరించబడలేదు)' : '(Unset)') : (_isTe ? '(నిర్ధారించబడింది)' : '(Confirmed)'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: totalPeople == 0 ? AppColors.warningOrange : AppColors.emerald,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          _buildCounterRow(
            _isTe ? 'పెద్దలు' : 'Adults',
            _isTe ? 'వయస్సు 18-64' : 'Ages 18-64',
            _adults,
            (v) => setState(() => _adults = v),
          ),
          const Divider(height: 24, color: AppColors.border),
          _buildCounterRow(
            _isTe ? 'పిల్లలు' : 'Children',
            _isTe ? 'వయస్సు 0-17' : 'Ages 0-17',
            _children,
            (v) => setState(() => _children = v),
          ),
          const Divider(height: 24, color: AppColors.border),
          _buildCounterRow(
            _isTe ? 'వృద్ధులు' : 'Seniors',
            _isTe ? 'వయస్సు 65+' : 'Ages 65+',
            _seniors,
            (v) => setState(() => _seniors = v),
          ),
          const Divider(height: 24, color: AppColors.border),
          _buildCounterRow(
            _isTe ? 'పెంపుడు జంతువులు' : 'Pets / Animals',
            _isTe ? 'కుక్కలు, పిల్లులు, పశువులు' : 'Dogs, cats, livestock',
            _pets,
            (v) => setState(() => _pets = v),
          ),
          const Divider(height: 24, color: AppColors.border),

          // Mobility checkbox
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            activeColor: AppColors.primaryBlue,
            value: _needsMobilityAssistance,
            onChanged: (val) => setState(() => _needsMobilityAssistance = val ?? false),
            title: Text(
              _isTe ? 'వీల్‌చైర్ / మొబిలిటీ సహాయం అవసరం' : 'Wheelchair / Mobility Assistance Needed',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink),
            ),
            subtitle: Text(
              _isTe
                  ? 'వీల్‌చైర్ ర్యాంప్‌లు మరియు గ్రౌండ్-ఫ్లోర్ యాక్సెస్ ఉన్న ఆశ్రయాలను ఫిల్టర్ చేస్తుంది'
                  : 'Filters shelters for wheelchair ramps and ground-floor access',
              style: const TextStyle(fontSize: 12, color: AppColors.slate),
            ),
          ),

          const SizedBox(height: 32),
          ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: double.infinity,
              minHeight: AppDimensions.buttonHeight,
            ),
            child: ElevatedButton(
              onPressed: () async {
                await UserProfileService.updateHeadcount(
                  adults: _adults,
                  children: _children,
                  seniors: _seniors,
                  pets: _pets,
                  needsMobilityAssistance: _needsMobilityAssistance,
                );
                _nextPage();
              },
              child: Text(_isTe ? 'వివరాలను భద్రపరిచి కొనసాగించండి' : 'Save Headcount & Continue'),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildCounterRow(String title, String subtitle, int value, ValueChanged<int> onChanged) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink),
              ),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: AppColors.slate),
              ),
            ],
          ),
        ),
        Row(
          children: [
            _buildCircleButton(
              icon: Icons.remove,
              onTap: value > 0 ? () => onChanged(value - 1) : null,
            ),
            SizedBox(
              width: 36,
              child: Center(
                child: Text(
                  '$value',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.ink),
                ),
              ),
            ),
            _buildCircleButton(
              icon: Icons.add,
              onTap: () => onChanged(value + 1),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCircleButton({required IconData icon, VoidCallback? onTap}) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: enabled ? AppColors.surface : AppColors.surface.withValues(alpha: 0.5),
          shape: BoxShape.circle,
          border: Border.all(color: enabled ? AppColors.border : AppColors.border.withValues(alpha: 0.4)),
        ),
        child: Icon(
          icon,
          size: 18,
          color: enabled ? AppColors.ink : AppColors.slate.withValues(alpha: 0.4),
        ),
      ),
    );
  }

  // --- STEP 6: SCENARIO DETECTED & DASHBOARD TRANSITION (07_6_Scenario_detected.png) ---
  Widget _buildScenarioStep() {
    final locationName = _detectedLocation?.locationName ?? 'Coastal Andhra Pradesh';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.high.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.high.withValues(alpha: 0.4)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.high),
                SizedBox(width: 4),
                Text(
                  'HAZARD DETECTED IN YOUR ZONE',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.high),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _isTe
                ? 'వరద హెచ్చరిక: $locationName'
                : 'Emergency Advisory: $locationName Corridor',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: AppColors.ink,
              letterSpacing: -0.5,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isTe
                ? 'తీరప్రాంత వరద మరియు తుఫాను కారిడార్ క్రియాశీలంగా ఉంది. తక్కువ ఎత్తులో ఉన్న ప్రాంతాల నుండి అధిక ఎత్తు గల ఆశ్రయాలకు తరలింపు మార్గదర్శకాలు సిద్ధంగా ఉన్నాయి.'
                : 'Coastal surge and river water levels monitored. Evacuation routes and designated relief shelters are initialized for your detected sector.',
            style: const TextStyle(fontSize: 14, color: AppColors.slate, height: 1.45),
          ),
          const SizedBox(height: 24),

          // Simulation summary card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _isTe ? 'సిఫార్సు చేయబడిన ఆశ్రయ ప్రాంతం' : 'Recommended Shelter Sector',
                        style: const TextStyle(fontSize: 12, color: AppColors.slate),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const DemoBadge(label: 'DEMO DATA'),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.shield_outlined, color: AppColors.emerald, size: 24),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _detectedLocation?.locationName.contains('Kakinada') == true
                            ? 'Kakinada Multi-Purpose Cyclone Shelter'
                            : 'Bhavani Island Safe Zone (MG Road)',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.ink),
                      ),
                    ),
                    const Text(
                      '1.8 km',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.primaryBlue),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 48),
          ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: double.infinity,
              minHeight: AppDimensions.buttonHeight,
            ),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.emerald,
                foregroundColor: Colors.white,
              ),
              onPressed: _finishOnboarding,
              child: Text(
                _isTe
                    ? 'డ్యాష్‌బోర్డ్ చూడండి'
                    : 'View Evacuation Plan & Dashboard',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
