import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/models/disaster_type.dart';
import '../../../core/models/evacuation_route.dart';
import '../../../core/models/shelter_model.dart';
import '../../../core/services/locale_service.dart';
import '../../../core/services/shelter_service.dart';
import '../../../core/services/user_profile_service.dart';
import '../../../core/widgets/app_header.dart';
import '../../../core/widgets/demo_badge.dart';
import '../../../core/widgets/status_badge.dart';
import '../../disaster/hazard_service.dart';
import '../../map/location_service.dart';
import '../route_model.dart';
import '../route_service.dart';
import '../widgets/evacuation_map_view.dart';

/// Module Screen: Evacuation Routing & Turn-by-Turn Navigation Support.
/// Integrates dynamic GPS user origin, nearest/selected shelter destination,
/// hazard-aware Dijkstra route calculations, honest safety provenance badges,
/// real interactive map visualization, and a complete in-app turn-by-turn navigation cockpit.
class RoutingScreen extends StatefulWidget {
  final String? shelterId;
  final String? shelterName;
  final DisasterType initialDisaster;

  const RoutingScreen({
    super.key,
    this.shelterId,
    this.shelterName,
    this.initialDisaster = DisasterType.flood,
  });

  @override
  State<RoutingScreen> createState() => _RoutingScreenState();
}

class _RoutingScreenState extends State<RoutingScreen> {
  final RouteService _routeService = RouteService();
  final MockShelterService _shelterService = MockShelterService();
  final LocationService _locationService = LocationService();
  final HazardService _hazardService = HazardService();

  int _selectedRouteIndex = 0; // 0 = Primary Route, 1 = Alternative Route
  bool _isLoading = true;
  RouteCalculationResult? _calculationResult;
  ShelterModel? _destinationShelter;
  List<HazardModel> _hazards = [];

  // ── Navigation State Machine ─────────────────────────────────────────────
  bool _isNavigating = false;
  int _activeStepIndex = 0;
  bool _isAutoSimulating = false;
  Timer? _simulationTimer;
  bool _isWalking = false; // false = Vehicle (25 km/h), true = Pedestrian (5 km/h)
  bool _isVoiceMuted = false;
  bool _isAcquiringLocation = false;
  double _userBearing = 45.0;
  GeoPoint? _currentNavPosition;

  @override
  void initState() {
    super.initState();
    _loadShelterAndComputeRoute();
    UserProfileService.profileNotifier.addListener(_onProfileUpdated);
  }

  @override
  void dispose() {
    _simulationTimer?.cancel();
    UserProfileService.profileNotifier.removeListener(_onProfileUpdated);
    super.dispose();
  }

  void _onProfileUpdated() {
    if (mounted && !_isNavigating) {
      _loadShelterAndComputeRoute();
    }
  }

  Future<void> _loadShelterAndComputeRoute() async {
    setState(() => _isLoading = true);

    // 1. Resolve origin from live/persisted user profile
    final userLoc = UserProfileService.currentLocation;
    final originPoint = GeoPoint.fromUserLocation(userLoc);

    // 2. Resolve destination shelter matching user proximity
    ShelterModel? target;
    if (widget.shelterId != null) {
      target = await _shelterService.getShelterById(widget.shelterId!);
    }
    target ??= await _shelterService.getClosestSafeShelter(userLoc.latitude, userLoc.longitude);
    if (target == null) {
      final all = await _shelterService.getAvailableShelters();
      if (all.isNotEmpty) target = all.first;
    }

    _destinationShelter = target;

    // Destination GeoPoint
    final shelterPoint = target != null
        ? GeoPoint.fromShelter(target)
        : GeoPoint(
            16.9604,
            82.2382,
            name: widget.shelterName ?? AppStrings.nearestShelterName,
          );

    // 3. Load active hazards for disaster type
    final hazards = await _hazardService.getHazardsForDisaster(widget.initialDisaster);
    _hazards = hazards;

    // 4. Compute dynamic evacuation corridor via RouteService
    final result = await _routeService.calculateEvacuationRoutes(
      userLocation: originPoint,
      shelterLocation: shelterPoint,
      disasterType: widget.initialDisaster,
      customHazards: hazards,
    );

    if (mounted) {
      setState(() {
        _calculationResult = result;
        _isLoading = false;
        if (_selectedRouteIndex >= result.allRoutes.length) {
          _selectedRouteIndex = 0;
        }
      });
    }
  }

  EvacuationRoute _getActiveRoute() {
    if (_calculationResult != null && _calculationResult!.allRoutes.isNotEmpty) {
      final safeIndex = _selectedRouteIndex.clamp(0, _calculationResult!.allRoutes.length - 1);
      return _calculationResult!.allRoutes[safeIndex];
    }

    if (_calculationResult != null && _calculationResult!.state == RouteVerificationState.noVerifiedRoute) {
      return EvacuationRoute(
        id: 'no-route',
        title: 'No Verified Road Route Available',
        destinationShelterId: _destinationShelter?.id ?? 'none',
        destinationShelterName: _destinationShelter?.name ?? 'Unreachable Shelter',
        distanceKm: 0.0,
        estimatedTimeMinutes: 0,
        waypoints: const [],
        segments: const [],
        safetyStatus: RouteSafetyStatus.blocked,
        verificationState: RouteVerificationState.noVerifiedRoute,
        roadConditionSummary: _calculationResult!.statusMessage,
        warnings: [_calculationResult!.statusMessage],
      );
    }

    // Baseline fallback model
    return EvacuationRoute(
      id: 'route-01',
      title: _selectedRouteIndex == 0
          ? 'MG High-Ground Bypass Route'
          : 'NH-16 Ring Road Alternative',
      destinationShelterId: widget.shelterId ?? 'shelter-101',
      destinationShelterName: widget.shelterName ?? AppStrings.nearestShelterName,
      distanceKm: _selectedRouteIndex == 0 ? 2.4 : 3.8,
      estimatedTimeMinutes: _selectedRouteIndex == 0 ? 11 : 19,
      safetyStatus: RouteSafetyStatus.simulated,
      roadConditionSummary: _selectedRouteIndex == 0
          ? 'Demonstration model: MG Road high-elevation corridor selected; low-lying underpasses flagged.'
          : 'Demonstration model: Detour via NH-16 ring bypass avoiding simulated flood zone by 1.2km.',
      warnings: const [
        'Demonstration advisory: Low-Lying Underpass flagged as simulated hazard (1.2m water level)',
        'Speed limit 25 km/h advisory for flood emergency staging',
      ],
    );
  }

  // ── Navigation State Machine Controls ────────────────────────────────────

  void _startNavigation() {
    final route = _getActiveRoute();
    setState(() {
      _isNavigating = true;
      _activeStepIndex = 0;
      _isAutoSimulating = false;
      _simulationTimer?.cancel();
      if (route.waypoints.isNotEmpty) {
        _currentNavPosition = route.waypoints.first;
        if (route.waypoints.length > 1) {
          _userBearing = route.waypoints[0].bearingTo(route.waypoints[1]);
        }
      } else {
        final userLoc = UserProfileService.currentLocation;
        _currentNavPosition = GeoPoint.fromUserLocation(userLoc);
      }
    });

    final isTe = LocaleService.currentLocale.value == 'te';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isTe
              ? 'తరలింపు నావిగేషన్ ప్రారంభించబడింది. మలుపు సూచనలను అనుసరించండి.'
              : 'Evacuation navigation active. Follow turn directives.',
        ),
        backgroundColor: AppColors.emerald,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _stopNavigation() {
    _simulationTimer?.cancel();
    setState(() {
      _isNavigating = false;
      _isAutoSimulating = false;
      _activeStepIndex = 0;
    });
  }

  void _advanceNavigationStep() {
    final route = _getActiveRoute();
    final stepsCount = math.max(route.segments.length, 4);
    if (_activeStepIndex < stepsCount - 1) {
      setState(() {
        _activeStepIndex++;
        if (route.waypoints.length > _activeStepIndex) {
          _currentNavPosition = route.waypoints[_activeStepIndex];
          if (_activeStepIndex + 1 < route.waypoints.length) {
            _userBearing = route.waypoints[_activeStepIndex]
                .bearingTo(route.waypoints[_activeStepIndex + 1]);
          }
        }
      });
    } else {
      _simulationTimer?.cancel();
      setState(() => _isAutoSimulating = false);
      _showArrivalDialog();
    }
  }

  void _previousNavigationStep() {
    final route = _getActiveRoute();
    if (_activeStepIndex > 0) {
      setState(() {
        _activeStepIndex--;
        if (route.waypoints.length > _activeStepIndex) {
          _currentNavPosition = route.waypoints[_activeStepIndex];
          if (_activeStepIndex + 1 < route.waypoints.length) {
            _userBearing = route.waypoints[_activeStepIndex]
                .bearingTo(route.waypoints[_activeStepIndex + 1]);
          }
        }
      });
    }
  }

  void _toggleAutoSimulation() {
    if (_isAutoSimulating) {
      _simulationTimer?.cancel();
      setState(() => _isAutoSimulating = false);
    } else {
      setState(() => _isAutoSimulating = true);
      _simulationTimer?.cancel();
      _simulationTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
        if (!mounted || !_isNavigating) {
          timer.cancel();
          return;
        }
        _advanceNavigationStep();
      });
    }
  }

  void _recalculateCurrentRoute() {
    _loadShelterAndComputeRoute();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Recalculating safest corridor with latest hazard telemetry...'),
        backgroundColor: AppColors.primaryBlue,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _refreshGpsLocation() async {
    setState(() => _isAcquiringLocation = true);
    final res = await _locationService.acquireAndSyncWithProfile();
    if (mounted) {
      setState(() => _isAcquiringLocation = false);
      if (res.isSuccess) {
        _loadShelterAndComputeRoute();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              res.isLastKnownFallback
                  ? 'Last known GPS position updated.'
                  : 'Live GPS fix acquired (±${res.position?.accuracy.toStringAsFixed(1)}m).',
            ),
            backgroundColor: AppColors.emerald,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.errorMessage ?? 'Unable to acquire GPS fix.'),
            backgroundColor: AppColors.critical,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // ── Dialogs & Bottom Sheets ──────────────────────────────────────────────

  void _showArrivalDialog() {
    final isTe = LocaleService.currentLocale.value == 'te';
    final destName = _destinationShelter?.name ?? widget.shelterName ?? AppStrings.nearestShelterName;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: AppColors.emerald, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isTe ? 'గమ్యస్థానానికి చేరుకున్నారు!' : 'Arrived at Safe Shelter!',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isTe
                  ? 'మీరు విజయవంతంగా $destName సురక్షిత ప్రాంతానికి చేరుకున్నారు.'
                  : 'You have safely reached $destName. Proceed inside for emergency staging, check-in, and relief supplies.',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_user_rounded, color: AppColors.primaryBlue, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isTe
                          ? 'ఆశ్రయ కేంద్రంలో సహాయకులు మరియు వైద్య బృందం సిద్ధంగా ఉన్నారు.'
                          : 'Shelter command & emergency personnel active on-site.',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.emerald,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _stopNavigation();
            },
            child: Text(isTe ? 'సరే / ముగించు' : 'Complete Navigation'),
          ),
        ],
      ),
    );
  }

  Future<void> _showShelterSelector() async {
    final shelters = await _shelterService.getAvailableShelters();
    if (!mounted) return;
    final isTe = LocaleService.currentLocale.value == 'te';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              isTe ? 'తరలింపు ఆశ్రయాన్ని ఎంచుకోండి' : 'Select Destination Shelter',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.ink),
            ),
            const SizedBox(height: 4),
            Text(
              isTe
                  ? 'కొత్త ఆశ్రయానికి తరలింపు మార్గాన్ని లెక్కించండి.'
                  : 'Choose an authorized emergency relief shelter to recalculate the evacuation route.',
              style: const TextStyle(fontSize: 12, color: AppColors.slate),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: ListView.builder(
                itemCount: shelters.length,
                itemBuilder: (context, index) {
                  final s = shelters[index];
                  final isSelected = _destinationShelter?.id == s.id;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isSelected ? AppColors.emerald : AppColors.border,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    color: isSelected ? AppColors.emerald.withOpacity(0.04) : Colors.white,
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (isSelected ? AppColors.emerald : AppColors.primaryBlue).withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.home_work_rounded,
                          color: isSelected ? AppColors.emerald : AppColors.primaryBlue,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        s.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? AppColors.emerald : AppColors.ink,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 2),
                          Text(
                            '${s.distanceKm.toStringAsFixed(1)} km • ${s.address}',
                            style: const TextStyle(fontSize: 11, color: AppColors.slate),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 4,
                            children: s.facilities.take(3).map((f) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Text(
                                f,
                                style: const TextStyle(fontSize: 9, color: AppColors.slate, fontWeight: FontWeight.w600),
                              ),
                            )).toList(),
                          ),
                        ],
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle_rounded, color: AppColors.emerald)
                          : const Icon(Icons.chevron_right_rounded, color: AppColors.slate),
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() {
                          _destinationShelter = s;
                        });
                        _loadShelterAndComputeRoute();
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showStepsOverviewSheet() {
    final route = _getActiveRoute();
    final isTe = LocaleService.currentLocale.value == 'te';
    final userLoc = UserProfileService.currentLocation;
    final destName = _destinationShelter?.name ?? widget.shelterName ?? AppStrings.nearestShelterName;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.70,
        ),
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.alt_route_rounded, color: AppColors.primaryBlue),
                const SizedBox(width: 8),
                Text(
                  isTe ? 'మార్గ మలుపుల జాబితా' : 'Turn-by-Turn Route Steps',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.ink),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${route.distanceKm.toStringAsFixed(1)} km total • ~$travelTimeEstimated (${_isWalking ? "Walking" : "Vehicle"})',
              style: const TextStyle(fontSize: 12, color: AppColors.slate),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: ListView(
                children: [
                  if (route.segments.isNotEmpty)
                    ...route.segments.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final seg = entry.value;
                      final isCurrent = _isNavigating && _activeStepIndex == idx;
                      final isPassed = _isNavigating && _activeStepIndex > idx;
                      final isWarn = seg.riskLevel != RouteRiskLevel.low || seg.isBlocked;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? AppColors.emerald.withOpacity(0.08)
                              : (isPassed ? Colors.grey.shade100 : Colors.white),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isCurrent
                                ? AppColors.emerald
                                : (isWarn ? AppColors.critical.withOpacity(0.3) : AppColors.border),
                            width: isCurrent ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: isCurrent
                                    ? AppColors.emerald
                                    : (isWarn ? AppColors.critical.withOpacity(0.12) : AppColors.surface),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isPassed
                                    ? Icons.check_rounded
                                    : _getManeuverIcon(seg.turnInstruction ?? seg.roadName),
                                size: 18,
                                color: isCurrent
                                    ? Colors.white
                                    : (isWarn ? AppColors.critical : AppColors.primaryBlue),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    seg.turnInstruction ?? seg.roadName,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                                      color: isPassed ? AppColors.slate : AppColors.ink,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${seg.distanceKm.toStringAsFixed(1)} km • ${seg.hazardNotes ?? "Verified evacuation section"}',
                                    style: const TextStyle(fontSize: 11, color: AppColors.slate),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    })
                  else ...[
                    _buildStepDirective(
                      '1',
                      'Depart ${userLoc.locationName} Heading West',
                      '0.0 km • Local Corridor Origin',
                      Icons.straight_rounded,
                      false,
                    ),
                    _buildStepDirective(
                      '2',
                      'Turn Right onto MG High Ground Bypass',
                      '0.4 km • Avoids 1.2m submerged underpass',
                      Icons.turn_right_rounded,
                      true,
                    ),
                    _buildStepDirective(
                      '3',
                      'Continue over Prakasam Flyover',
                      '1.6 km • Elevated flood-safe corridor',
                      Icons.straight_rounded,
                      false,
                    ),
                    _buildStepDirective(
                      '4',
                      'Arrive at $destName',
                      '${route.distanceKm.toStringAsFixed(1)} km • Designated emergency shelter',
                      Icons.check_circle_outline_rounded,
                      false,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  int get travelTimeEstimated {
    final route = _getActiveRoute();
    if (_isWalking) {
      // 5 km/h pedestrian evacuation speed
      return math.max(((route.distanceKm / 5.0) * 60).round(), 1);
    }
    // 25 km/h vehicle staging pace
    return math.max(route.estimatedTimeMinutes, 1);
  }

  IconData _getManeuverIcon(String? instruction) {
    final text = (instruction ?? '').toLowerCase();
    if (text.contains('arrive') || text.contains('destination') || text.contains('shelter') || text.contains('gate')) {
      return Icons.flag_rounded;
    }
    if (text.contains('slight right') || text.contains('bear right') || text.contains('fork right')) {
      return Icons.fork_right_rounded;
    }
    if (text.contains('slight left') || text.contains('bear left') || text.contains('fork left')) {
      return Icons.fork_left_rounded;
    }
    if (text.contains('sharp right')) {
      return Icons.turn_sharp_right_rounded;
    }
    if (text.contains('sharp left')) {
      return Icons.turn_sharp_left_rounded;
    }
    if (text.contains('right')) {
      return Icons.turn_right_rounded;
    }
    if (text.contains('left')) {
      return Icons.turn_left_rounded;
    }
    if (text.contains('u-turn')) {
      return Icons.u_turn_left_rounded;
    }
    if (text.contains('flyover') || text.contains('elevated') || text.contains('ramp') || text.contains('ascend')) {
      return Icons.upgrade_rounded;
    }
    return Icons.straight_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final route = _getActiveRoute();
    final userLoc = UserProfileService.currentLocation;
    final destName = _destinationShelter?.name ?? widget.shelterName ?? AppStrings.toDestination;
    final originPoint = GeoPoint.fromUserLocation(userLoc);
    final shelterPoint = _destinationShelter != null
        ? GeoPoint.fromShelter(_destinationShelter!)
        : GeoPoint(16.9604, 82.2382, name: destName);

    return ValueListenableBuilder<String>(
      valueListenable: LocaleService.currentLocale,
      builder: (context, locale, _) {
        final isTe = locale == 'te';

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: _isNavigating
              ? null // In active navigation, top instruction cockpit replaces standard header
              : AppHeader(customTitle: AppStrings.navEvacuate),
          body: _isNavigating
              ? _buildActiveNavigationCockpit(route, originPoint, shelterPoint, destName, isTe)
              : _buildRoutePreviewView(route, userLoc, originPoint, shelterPoint, destName, isTe),
        );
      },
    );
  }

  // ── MODE A: Route Preview View ───────────────────────────────────────────

  Widget _buildRoutePreviewView(
    EvacuationRoute route,
    dynamic userLoc,
    GeoPoint originPoint,
    GeoPoint shelterPoint,
    String destName,
    bool isTe,
  ) {
    return Column(
      children: [
        if (_isLoading)
          const LinearProgressIndicator(
            color: AppColors.primaryBlue,
            minHeight: 2,
          ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Origin & Destination Selector Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      // Origin Row
                      Row(
                        children: [
                          const Icon(Icons.my_location_rounded, size: 18, color: AppColors.primaryBlue),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppStrings.fromLocation,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.slate,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  userLoc.locationName,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.ink,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          StatusBadge(
                            label: userLoc.provenance.label,
                            severity: userLoc.isLiveFix ? BadgeSeverity.positive : BadgeSeverity.neutral,
                          ),
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: _isAcquiringLocation ? null : _refreshGpsLocation,
                            borderRadius: BorderRadius.circular(6),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: _isAcquiringLocation
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.refresh_rounded, size: 16, color: AppColors.primaryBlue),
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          children: [
                            Container(width: 2, height: 16, color: AppColors.border),
                          ],
                        ),
                      ),
                      // Destination Shelter Row
                      Row(
                        children: [
                          const Icon(Icons.location_on_rounded, size: 18, color: AppColors.emerald),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'TO SAFE SHELTER',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.slate,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  destName,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.emerald,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          DemoBadge(
                            label: _calculationResult?.state == RouteVerificationState.noVerifiedRoute
                                ? 'NO ROAD ROUTE'
                                : (route.isNavigableRoad ? 'ROAD NETWORK GRAPH' : 'SIMULATED CORRIDOR'),
                          ),
                          const SizedBox(width: 6),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              side: const BorderSide(color: AppColors.border),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            onPressed: _showShelterSelector,
                            icon: const Icon(Icons.swap_vert_rounded, size: 13, color: AppColors.primaryBlue),
                            label: Text(
                              isTe ? 'మార్చండి' : 'Change',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primaryBlue),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                if (_calculationResult?.state == RouteVerificationState.noVerifiedRoute) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.critical),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                isTe ? 'ధృవీకరించబడిన రహదారి మార్గం అందుబాటులో లేదు' : 'NO VERIFIED ROAD ROUTE AVAILABLE',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.critical),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _calculationResult?.statusMessage ?? 'Outside verified road network coverage.',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF991B1B), height: 1.3),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _showShelterSelector,
                          icon: const Icon(Icons.near_me_rounded, size: 14),
                          label: Text(isTe ? 'సమీప ఆశ్రయాన్ని ఎంచుకోండి' : 'Select Nearby District Shelter'),
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            foregroundColor: AppColors.critical,
                            side: const BorderSide(color: AppColors.critical),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // 2. Real Interactive Evacuation Map
                Container(
                  height: 230,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
                    border: Border.all(color: const Color(0xFF1E293B)),
                  ),
                  child: EvacuationMapView(
                    origin: originPoint,
                    destination: shelterPoint,
                    routeWaypoints: route.waypoints,
                    segments: route.segments,
                    hazards: _hazards,
                    isNavigating: false,
                    isAlternateRoute: _selectedRouteIndex == 1,
                    hasBlockedRoads: route.hasBlockedRoads,
                    isNavigableRoad: route.isNavigableRoad,
                    destinationName: destName,
                  ),
                ),
                const SizedBox(height: 14),

                // 3. Travel Mode Selector (Vehicle 25 km/h vs Foot 5 km/h)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _isWalking = false),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: !_isWalking ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: !_isWalking
                                  ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4)]
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.directions_car_rounded,
                                  size: 15,
                                  color: !_isWalking ? AppColors.primaryBlue : AppColors.slate,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    isTe ? 'వాహనం (25 km/h)' : 'Vehicle (25 km/h)',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: !_isWalking ? FontWeight.w800 : FontWeight.w600,
                                      color: !_isWalking ? AppColors.ink : AppColors.slate,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _isWalking = true),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _isWalking ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: _isWalking
                                  ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4)]
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.directions_walk_rounded,
                                  size: 15,
                                  color: _isWalking ? AppColors.primaryBlue : AppColors.slate,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    isTe ? 'నడక (5 km/h)' : 'Walking (5 km/h)',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: _isWalking ? FontWeight.w800 : FontWeight.w600,
                                      color: _isWalking ? AppColors.ink : AppColors.slate,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 4. Metrics Telemetry Row (Distance, Time, Risk)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      // Distance
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Distance',
                              style: TextStyle(fontSize: 11, color: AppColors.slate, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${route.distanceKm.toStringAsFixed(1)} km',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink),
                            ),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 32, color: AppColors.border),
                      const SizedBox(width: 12),

                      // Time
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Est. Time',
                              style: TextStyle(fontSize: 11, color: AppColors.slate, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '~$travelTimeEstimated min',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primaryBlue),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _isWalking ? 'Pace @ 5 km/h' : 'Approx @ 25 km/h',
                              style: const TextStyle(fontSize: 10, color: AppColors.slate, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 32, color: AppColors.border),
                      const SizedBox(width: 12),

                      // Risk Badge
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Route Risk',
                              style: TextStyle(fontSize: 11, color: AppColors.slate, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 4),
                            StatusBadge(
                              label: route.hasBlockedRoads
                                  ? 'BLOCKED'
                                  : (_selectedRouteIndex == 0 ? AppStrings.moderateRisk : AppStrings.lowRisk),
                              severity: route.hasBlockedRoads
                                  ? BadgeSeverity.critical
                                  : (_selectedRouteIndex == 0 ? BadgeSeverity.moderate : BadgeSeverity.positive),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 5. Hazard Avoidance Banner
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.shield_outlined, size: 20, color: AppColors.emerald),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppStrings.hazardAvoidanceNote,
                              style: const TextStyle(fontSize: 12, color: AppColors.ink, fontWeight: FontWeight.w500),
                            ),
                            if (route.elevationProfile.isNotEmpty && route.elevationProfile != 'Normal Ground') ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.terrain_outlined, size: 14, color: AppColors.slate),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      'Elevation: ${route.elevationProfile}',
                                      style: const TextStyle(fontSize: 11, color: AppColors.slate, fontWeight: FontWeight.w600),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (route.roadConditionSummary.isNotEmpty &&
                                route.roadConditionSummary != AppStrings.hazardAvoidanceNote) ...[
                              const SizedBox(height: 4),
                              Text(
                                route.roadConditionSummary,
                                style: const TextStyle(fontSize: 11, color: AppColors.slate),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 6. Turn Directives Header & Expandable List
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'Turn Directives',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: _showStepsOverviewSheet,
                      icon: const Icon(Icons.format_list_bulleted_rounded, size: 15, color: AppColors.primaryBlue),
                      label: Text(
                        isTe ? 'అన్ని మలుపులు' : 'View All Steps',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primaryBlue),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                if (route.segments.isNotEmpty)
                  ...route.segments.take(4).toList().asMap().entries.map((entry) {
                    final idx = entry.key + 1;
                    final seg = entry.value;
                    final isWarn = seg.riskLevel != RouteRiskLevel.low || seg.isBlocked;
                    return _buildStepDirective(
                      '$idx',
                      seg.turnInstruction ?? seg.roadName,
                      '${seg.distanceKm.toStringAsFixed(1)} km • ${seg.hazardNotes ?? "Verified evacuation section"}',
                      isWarn ? Icons.warning_amber_rounded : _getManeuverIcon(seg.turnInstruction ?? seg.roadName),
                      isWarn,
                    );
                  })
                else ...[
                  _buildStepDirective(
                    '1',
                    'Depart ${userLoc.locationName} Heading West',
                    '0.0 km • Local Corridor Origin',
                    Icons.straight_rounded,
                    false,
                  ),
                  _buildStepDirective(
                    '2',
                    'Turn Right onto MG High Ground Bypass',
                    '0.4 km • Avoids 1.2m submerged underpass',
                    Icons.turn_right_rounded,
                    true,
                  ),
                  _buildStepDirective(
                    '3',
                    'Continue over Prakasam Flyover',
                    '1.6 km • Elevated flood-safe corridor',
                    Icons.straight_rounded,
                    false,
                  ),
                  _buildStepDirective(
                    '4',
                    'Arrive at $destName',
                    '${route.distanceKm.toStringAsFixed(1)} km • Designated emergency shelter',
                    Icons.check_circle_outline_rounded,
                    false,
                  ),
                ],

                const SizedBox(height: 18),

                // 7. Action Button: Start Navigation
                SizedBox(
                  width: double.infinity,
                  height: AppDimensions.buttonHeight,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _calculationResult?.state == RouteVerificationState.noVerifiedRoute
                          ? const Color(0xFF94A3B8)
                          : (route.hasBlockedRoads ? AppColors.critical : AppColors.emerald),
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                      ),
                    ),
                    onPressed: _calculationResult?.state == RouteVerificationState.noVerifiedRoute
                        ? null
                        : _startNavigation,
                    icon: Icon(
                      _calculationResult?.state == RouteVerificationState.noVerifiedRoute
                          ? Icons.block_rounded
                          : Icons.navigation_rounded,
                      size: 22,
                    ),
                    label: Text(
                      _calculationResult?.state == RouteVerificationState.noVerifiedRoute
                          ? (isTe ? 'రహదారి అందుబాటులో లేదు' : 'No Passable Road Route')
                          : AppStrings.startGuidance,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.3),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Alternate Route Toggle
                if (_calculationResult != null && _calculationResult!.allRoutes.length > 1)
                  Center(
                    child: TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _selectedRouteIndex = (_selectedRouteIndex + 1) % _calculationResult!.allRoutes.length;
                        });
                      },
                      icon: const Icon(Icons.alt_route_rounded, size: 18, color: AppColors.primaryBlue),
                      label: Text(
                        _selectedRouteIndex == 0
                            ? 'Switch to Alternate Route (${_calculationResult!.allRoutes[1].name} • ${_calculationResult!.allRoutes[1].distanceKm.toStringAsFixed(1)} km)'
                            : 'Switch back to Recommended Route (${_calculationResult!.allRoutes[0].name} • ${_calculationResult!.allRoutes[0].distanceKm.toStringAsFixed(1)} km)',
                        style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primaryBlue),
                      ),
                    ),
                  )
                else
                  Center(
                    child: TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _selectedRouteIndex = _selectedRouteIndex == 0 ? 1 : 0;
                        });
                      },
                      icon: const Icon(Icons.alt_route_rounded, size: 18, color: AppColors.primaryBlue),
                      label: Text(
                        _selectedRouteIndex == 0
                            ? 'Switch to Alternate Route (via NH-16 • 3.8 km)'
                            : 'Switch back to MG High Ground Bypass (2.4 km)',
                        style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primaryBlue),
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── MODE B: Active Turn-by-Turn Navigation Cockpit ───────────────────────

  Widget _buildActiveNavigationCockpit(
    EvacuationRoute route,
    GeoPoint originPoint,
    GeoPoint shelterPoint,
    String destName,
    bool isTe,
  ) {
    final activeSegment = (route.segments.isNotEmpty && _activeStepIndex < route.segments.length)
        ? route.segments[_activeStepIndex]
        : null;

    final nextSegment = (route.segments.isNotEmpty && _activeStepIndex + 1 < route.segments.length)
        ? route.segments[_activeStepIndex + 1]
        : null;

    final String instructionText = activeSegment?.turnInstruction ??
        activeSegment?.roadName ??
        (_activeStepIndex == 0
            ? 'Depart origin and proceed along high corridor'
            : 'Arrive at $destName evacuation shelter');

    final double stepDistKm = activeSegment?.distanceKm ?? (route.distanceKm / 4.0);
    final String stepDistLabel = stepDistKm < 1.0
        ? 'In ${(stepDistKm * 1000).round()} m'
        : 'In ${stepDistKm.toStringAsFixed(1)} km';

    final String nextUpcomingText = nextSegment != null
        ? 'Then: ${nextSegment.turnInstruction ?? nextSegment.roadName}'
        : 'Then: Arrive at $destName safe zone';

    final double remainingDistanceKm = math.max(
      route.distanceKm * (1.0 - (_activeStepIndex / math.max(route.segments.length, 4))),
      0.2,
    );
    final int remainingMinutes = math.max(
      (travelTimeEstimated * (1.0 - (_activeStepIndex / math.max(route.segments.length, 4)))).round(),
      1,
    );

    final etaTime = DateFormat('hh:mm a').format(DateTime.now().add(Duration(minutes: remainingMinutes)));

    return SafeArea(
      child: Column(
        children: [
          // 1. Top Turn-by-Turn Maneuver Cockpit Banner (Google Maps Inspired)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A), // Dark navy slate HUD
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Maneuver Icon
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.emerald,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getManeuverIcon(instructionText),
                        size: 28,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Direction text & distance
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stepDistLabel,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            instructionText,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFE2E8F0),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    // Voice Guidance Toggle
                    IconButton(
                      icon: Icon(
                        _isVoiceMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                        color: Colors.white70,
                        size: 22,
                      ),
                      onPressed: () {
                        setState(() => _isVoiceMuted = !_isVoiceMuted);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              _isVoiceMuted
                                  ? 'Audio evacuation guidance muted.'
                                  : 'Audio evacuation guidance active.',
                            ),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Mini preview bar: Next maneuver
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.turn_right_rounded, size: 14, color: AppColors.emerald),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          nextUpcomingText,
                          style: const TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2. Active Interactive Map View
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: EvacuationMapView(
                    origin: originPoint,
                    destination: shelterPoint,
                    routeWaypoints: route.waypoints,
                    segments: route.segments,
                    hazards: _hazards,
                    isNavigating: true,
                    activeSegmentIndex: _activeStepIndex,
                    userBearing: _userBearing,
                    currentUserLocation: _currentNavPosition,
                    isAlternateRoute: _selectedRouteIndex == 1,
                    hasBlockedRoads: route.hasBlockedRoads,
                    isNavigableRoad: route.isNavigableRoad,
                    destinationName: destName,
                  ),
                ),

                // Floating HUD Overlays
                // A. Live Speed Badge (Top Left)
                Positioned(
                  top: 14,
                  left: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.92),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _isWalking ? '4.8 km/h' : '23 km/h',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.ink),
                        ),
                        Text(
                          _isWalking ? 'WALKING PACE' : 'VEHICLE PACE',
                          style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: AppColors.slate),
                        ),
                      ],
                    ),
                  ),
                ),

                // B. Steps Sheet Floating Button (Bottom Left)
                Positioned(
                  left: 14,
                  bottom: 14,
                  child: FloatingActionButton.small(
                    heroTag: 'nav_steps_sheet_fab',
                    tooltip: 'All Route Steps',
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primaryBlue,
                    onPressed: _showStepsOverviewSheet,
                    child: const Icon(Icons.list_alt_rounded),
                  ),
                ),

                // C. Recalculate Route Button (Floating Top Right)
                Positioned(
                  top: 56,
                  right: 14,
                  child: Material(
                    color: Colors.white.withOpacity(0.92),
                    borderRadius: BorderRadius.circular(8),
                    elevation: 2,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: _recalculateCurrentRoute,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.alt_route_rounded, size: 14, color: AppColors.primaryBlue),
                            SizedBox(width: 4),
                            Text(
                              'Recalculate',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 3. Demonstration Step Simulator Controls (Honest Provenance)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            color: const Color(0xFFF1F5F9),
            child: Row(
              children: [
                const DemoBadge(label: 'SIMULATOR'),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Step ${_activeStepIndex + 1} of ${math.max(route.segments.length, 4)}',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.slate),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.skip_previous_rounded, size: 18),
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(),
                  tooltip: 'Previous Step',
                  onPressed: _activeStepIndex > 0 ? _previousNavigationStep : null,
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: _toggleAutoSimulation,
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: _isAutoSimulating ? AppColors.emerald : AppColors.primaryBlue,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isAutoSimulating ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          size: 12,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          _isAutoSimulating ? 'Pause' : 'Auto',
                          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.skip_next_rounded, size: 18),
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(),
                  tooltip: 'Next Step',
                  onPressed: _advanceNavigationStep,
                ),
              ],
            ),
          ),

          // 4. Bottom Navigation Control Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppColors.border)),
              boxShadow: [
                BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2)),
              ],
            ),
            child: Row(
              children: [
                // Remaining Metrics
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                '$remainingMinutes',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.emerald,
                                ),
                              ),
                              const SizedBox(width: 2),
                              const Text(
                                'min',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.emerald,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '${remainingDistanceKm.toStringAsFixed(1)} km',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                          Text(
                            'ETA $etaTime',
                            style: const TextStyle(fontSize: 11, color: AppColors.slate),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.emerald, shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              destName,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.slate,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Red End Navigation Button
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.critical,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _stopNavigation,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: Text(
                    isTe ? 'ముగించు' : 'End',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepDirective(
    String stepNum,
    String instruction,
    String detail,
    IconData icon,
    bool isWarning,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isWarning ? AppColors.high.withOpacity(0.06) : AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(
          color: isWarning ? AppColors.high.withOpacity(0.3) : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isWarning ? AppColors.high.withOpacity(0.15) : AppColors.primaryBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 18,
              color: isWarning ? AppColors.high : AppColors.primaryBlue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  instruction,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: isWarning ? AppColors.high : AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: const TextStyle(fontSize: 11, color: AppColors.slate),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
