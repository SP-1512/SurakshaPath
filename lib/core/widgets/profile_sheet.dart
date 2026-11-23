import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../models/user_location.dart';
import '../services/locale_service.dart';
import '../services/location_service.dart';
import '../services/user_profile_service.dart';

/// Modal bottom sheet for reviewing and updating the household profile,
/// family headcount, mobility aid preference, and geographic location.
/// Matches approved minimalist design with honest provenance indicators.
class ProfileSheet extends StatefulWidget {
  const ProfileSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ProfileSheet(),
    );
  }

  @override
  State<ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends State<ProfileSheet> {
  late int _adults;
  late int _children;
  late int _seniors;
  late int _pets;
  late bool _needsMobilityAssistance;
  late UserLocation _currentLocation;
  bool _isLocating = false;
  String? _locationStatusMessage;

  bool get _isTe => LocaleService.isTelugu;

  @override
  void initState() {
    super.initState();
    final profile = UserProfileService.currentProfile;
    _adults = profile.adults ?? 0;
    _children = profile.children ?? 0;
    _seniors = profile.seniors ?? 0;
    _pets = profile.pets ?? 0;
    _needsMobilityAssistance = profile.needsMobilityAssistance;
    _currentLocation = UserProfileService.currentLocation;
  }

  Future<void> _acquireLiveGps() async {
    setState(() {
      _isLocating = true;
      _locationStatusMessage = null;
    });

    try {
      final service = DeviceLocationService();
      final status = await service.requestPermission();

      if (status == LocationPermissionStatus.granted) {
        final loc = await service.getCurrentLocation();
        if (mounted) {
          setState(() {
            _currentLocation = loc;
            _isLocating = false;
            _locationStatusMessage = _isTe
                ? 'లైవ్ GPS ఖచ్చితత్వం నమోదు చేయబడింది (±${loc.accuracyMeters?.toStringAsFixed(1) ?? "0"}m)'
                : 'Live GPS fix acquired (±${loc.accuracyMeters?.toStringAsFixed(1) ?? "0"}m)';
          });
        }
      } else if (status == LocationPermissionStatus.serviceDisabled) {
        if (mounted) {
          setState(() {
            _isLocating = false;
            _locationStatusMessage = _isTe
                ? 'లొకేషన్ సర్వీసులు నిలిపివేయబడ్డాయి. పరికరంలో GPS ఆన్ చేయండి.'
                : 'Location services disabled. Please enable GPS on your device.';
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLocating = false;
            _locationStatusMessage = _isTe
                ? 'లొకేషన్ అనుమతి నిరాకరించబడింది.'
                : 'Location permission was denied.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLocating = false;
          _locationStatusMessage = 'Error: $e';
        });
      }
    }
  }

  void _showManualCorridorPicker() {
    final hubs = [
      {'name': 'Kakinada Port Corridor', 'district': 'Kakinada District, Andhra Pradesh', 'lat': 16.9891, 'lon': 82.2475},
      {'name': 'Vijayawada Central', 'district': 'Krishna District, Andhra Pradesh', 'lat': 16.5062, 'lon': 80.6480},
      {'name': 'Visakhapatnam Harbor Sector', 'district': 'Visakhapatnam District, Andhra Pradesh', 'lat': 17.6868, 'lon': 83.2185},
      {'name': 'Machilipatnam Coastal Zone', 'district': 'Krishna District, Andhra Pradesh', 'lat': 16.1875, 'lon': 81.1389},
      {'name': 'Bapatla Coastal Sector', 'district': 'Bapatla District, Andhra Pradesh', 'lat': 15.9042, 'lon': 80.4674},
      {'name': 'Ongole Coastal Sector', 'district': 'Prakasam District, Andhra Pradesh', 'lat': 15.5057, 'lon': 80.0499},
      {'name': 'Nellore Coastal Zone', 'district': 'SPSR Nellore District, Andhra Pradesh', 'lat': 14.4426, 'lon': 79.9865},
      {'name': 'Amalapuram Konaseema Sector', 'district': 'Dr. B.R. Ambedkar Konaseema District, Andhra Pradesh', 'lat': 16.5787, 'lon': 82.0061},
      {'name': 'Rajahmundry Godavari Basin', 'district': 'East Godavari District, Andhra Pradesh', 'lat': 17.0005, 'lon': 81.8040},
      {'name': 'Srikakulam Coastal Sector', 'district': 'Srikakulam District, Andhra Pradesh', 'lat': 18.2949, 'lon': 83.8938},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusLarge)),
      ),
      builder: (ctx) => SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _isTe ? 'తీరప్రాంత కారిడార్ ఎంచుకోండి' : 'Select Coastal Corridor',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 16),
              Expanded(
                child: ListView.separated(
                  itemCount: hubs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, indent: 20, endIndent: 20),
                  itemBuilder: (ctx, idx) {
                    final hub = hubs[idx];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                      leading: const Icon(Icons.location_on_outlined, color: AppColors.primaryBlue),
                      title: Text(hub['name'] as String, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(hub['district'] as String, style: const TextStyle(fontSize: 12, color: AppColors.slate)),
                      onTap: () {
                        final manualLoc = UserLocation.manual(
                          latitude: hub['lat'] as double,
                          longitude: hub['lon'] as double,
                          locationName: hub['name'] as String,
                          subArea: hub['district'] as String,
                        );
                        setState(() {
                          _currentLocation = manualLoc;
                          _locationStatusMessage = _isTe
                              ? 'మాన్యువల్ స్థానం ఎంచుకోబడింది: ${manualLoc.locationName}'
                              : 'Manually selected: ${manualLoc.locationName}';
                        });
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _useDemoBaseline() {
    final demoLoc = UserLocation.mockDefault();
    setState(() {
      _currentLocation = demoLoc;
      _locationStatusMessage = _isTe
          ? 'డెమో స్థానం ఎంచుకోబడింది (కాకినాడ పోర్ట్ కారిడార్)'
          : 'Demo baseline set (Kakinada Port Corridor)';
    });
  }

  Future<void> _saveAllChanges() async {
    await UserProfileService.updateHeadcount(
      adults: _adults,
      children: _children,
      seniors: _seniors,
      pets: _pets,
      needsMobilityAssistance: _needsMobilityAssistance,
    );
    await UserProfileService.updateLocation(_currentLocation);

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isTe ? 'ప్రొఫైల్ విజయవంతంగా భద్రపరచబడింది.' : 'Profile updated successfully.',
          ),
          backgroundColor: AppColors.primaryBlue,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalPeople = _adults + _children + _seniors;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusXLarge)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isTe ? 'గృహ ప్రొఫైల్ & స్థానం' : 'Household Profile & Location',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                      letterSpacing: -0.3,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 22),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section 1: Location & Provenance
                    Text(
                      _isTe ? 'ప్రస్తుత స్థానం & GPS మూలం' : 'Location & GPS Provenance',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.slate),
                    ),
                    const SizedBox(height: 10),

                    Container(
                      padding: const EdgeInsets.all(14),
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
                                  _currentLocation.locationName,
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _currentLocation.provenance == LocationProvenance.liveGps
                                      ? AppColors.emerald.withValues(alpha: 0.12)
                                      : (_currentLocation.provenance == LocationProvenance.manualSelection
                                          ? AppColors.primaryBlue.withValues(alpha: 0.12)
                                          : AppColors.slate.withValues(alpha: 0.12)),
                                  borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                                  border: Border.all(
                                    color: _currentLocation.provenance == LocationProvenance.liveGps
                                        ? AppColors.emerald.withValues(alpha: 0.4)
                                        : (_currentLocation.provenance == LocationProvenance.manualSelection
                                            ? AppColors.primaryBlue.withValues(alpha: 0.4)
                                            : AppColors.border),
                                  ),
                                ),
                                child: Text(
                                  _currentLocation.provenance.label,
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: _currentLocation.provenance == LocationProvenance.liveGps
                                        ? AppColors.emerald
                                        : (_currentLocation.provenance == LocationProvenance.manualSelection
                                            ? AppColors.primaryBlue
                                            : AppColors.slate),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(_currentLocation.subArea, style: const TextStyle(fontSize: 13, color: AppColors.slate)),
                          const SizedBox(height: 6),
                          Text(
                            _currentLocation.formattedCoordinates +
                                (_currentLocation.accuracyMeters != null
                                    ? ' (±${_currentLocation.accuracyMeters!.toStringAsFixed(1)}m telemetry)'
                                    : ' (No satellite telemetry)'),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _currentLocation.isLiveFix ? AppColors.emerald : AppColors.slate,
                            ),
                          ),
                          if (_locationStatusMessage != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              _locationStatusMessage!,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primaryBlue),
                            ),
                          ],
                          const SizedBox(height: 12),

                          // Location Action Buttons
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                                onPressed: _isLocating ? null : _acquireLiveGps,
                                icon: _isLocating
                                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                    : const Icon(Icons.my_location, size: 16),
                                label: Text(_isTe ? 'GPS రీ-లాక్' : 'Acquire GPS Fix'),
                              ),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                                onPressed: _showManualCorridorPicker,
                                icon: const Icon(Icons.edit_location_alt_outlined, size: 16),
                                label: Text(_isTe ? 'మాన్యువల్ కారిడార్' : 'Choose Corridor'),
                              ),
                              TextButton(
                                onPressed: _useDemoBaseline,
                                child: Text(_isTe ? 'డెమో స్థానం' : 'Use Demo Location', style: const TextStyle(fontSize: 12, color: AppColors.slate)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Section 2: Headcount Steppers
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _isTe ? 'కుటుంబ సభ్యుల వివరాలు' : 'Household Headcount',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.slate),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            _isTe ? 'మొత్తం: $totalPeople • జంతువులు: $_pets' : 'Total: $totalPeople • Pets: $_pets',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.ink),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    _buildStepperRow(
                      _isTe ? 'పెద్దలు (18-64)' : 'Adults (18–64)',
                      _isTe ? 'కార్యాచరణ చేయగల సభ్యులు' : 'Able-bodied household members',
                      _adults,
                      (val) => setState(() => _adults = val),
                    ),
                    const Divider(height: 16, color: AppColors.border),

                    _buildStepperRow(
                      _isTe ? 'పిల్లలు (0-17)' : 'Children (0–17)',
                      _isTe ? 'శిశువులు మరియు పిల్లలు' : 'Infants, toddlers and youth',
                      _children,
                      (val) => setState(() => _children = val),
                    ),
                    const Divider(height: 16, color: AppColors.border),

                    _buildStepperRow(
                      _isTe ? 'వృద్ధులు (65+)' : 'Seniors (65+)',
                      _isTe ? 'ప్రత్యేక శ్రద్ధ అవసరమైన వృద్ధులు' : 'Elderly family members',
                      _seniors,
                      (val) => setState(() => _seniors = val),
                    ),
                    const Divider(height: 16, color: AppColors.border),

                    _buildStepperRow(
                      _isTe ? 'పెంపుడు జంతువులు' : 'Pets / Animals',
                      _isTe ? 'కుక్కలు, పిల్లులు, పశువులు' : 'Domestic animals / livestock',
                      _pets,
                      (val) => setState(() => _pets = val),
                    ),
                    const SizedBox(height: 20),

                    // Section 3: Mobility Assistance
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: CheckboxListTile(
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
                              ? 'ర్యాంప్‌లు మరియు గ్రౌండ్-ఫ్లోర్ యాక్సెస్ ఉన్న ఆశ్రయాలను ఫిల్టర్ చేయడానికి సహాయపడుతుంది'
                              : 'Recommends wheelchair accessible shelters and alerts rescue responders in SOS',
                          style: const TextStyle(fontSize: 12, color: AppColors.slate),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: AppDimensions.buttonHeight,
                      child: ElevatedButton(
                        onPressed: _saveAllChanges,
                        child: Text(
                          _isTe ? 'వివరాలను భద్రపరచండి' : 'Save Changes',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepperRow(String title, String subtitle, int value, ValueChanged<int> onChanged) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.ink)),
              Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.slate)),
            ],
          ),
        ),
        Row(
          children: [
            InkWell(
              onTap: value > 0 ? () => onChanged(value - 1) : null,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: value > 0 ? AppColors.surface : AppColors.surface.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                  border: Border.all(color: value > 0 ? AppColors.border : AppColors.border.withValues(alpha: 0.4)),
                ),
                child: const Icon(Icons.remove, size: 18, color: AppColors.ink),
              ),
            ),
            SizedBox(
              width: 36,
              child: Center(
                child: Text('$value', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink)),
              ),
            ),
            InkWell(
              onTap: () => onChanged(value + 1),
              borderRadius: BorderRadius.circular(18),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border),
                ),
                child: const Icon(Icons.add, size: 18, color: AppColors.ink),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
