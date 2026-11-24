import 'package:flutter/material.dart';
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
import '../../../navigation/app_router.dart';
import '../route_model.dart';
import '../route_service.dart';

/// Module Screen: Evacuation Routing & Decision Support matching 19_Evacuate.png.
/// Integrates dynamic GPS user origin, nearest/selected shelter destination,
/// hazard-aware Dijkstra route calculations, and honest safety provenance badges.
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

  int _selectedRouteIndex = 0; // 0 = Primary Route, 1 = Alternative Route
  bool _isLoading = true;
  RouteCalculationResult? _calculationResult;
  ShelterModel? _destinationShelter;

  @override
  void initState() {
    super.initState();
    _loadShelterAndComputeRoute();
    UserProfileService.profileNotifier.addListener(_onProfileUpdated);
  }

  @override
  void dispose() {
    UserProfileService.profileNotifier.removeListener(_onProfileUpdated);
    super.dispose();
  }

  void _onProfileUpdated() {
    if (mounted) {
      _loadShelterAndComputeRoute();
    }
  }

  Future<void> _loadShelterAndComputeRoute() async {
    setState(() => _isLoading = true);

    // 1. Resolve destination shelter
    ShelterModel? target;
    if (widget.shelterId != null) {
      target = await _shelterService.getShelterById(widget.shelterId!);
    }
    target ??= await _shelterService.getClosestSafeShelter();
    if (target == null) {
      final all = await _shelterService.getAvailableShelters();
      if (all.isNotEmpty) target = all.first;
    }

    _destinationShelter = target;

    // 2. Resolve origin from live/persisted user profile
    final userLoc = UserProfileService.currentLocation;
    final originPoint = GeoPoint.fromUserLocation(userLoc);

    // Destination GeoPoint
    final shelterPoint = target != null
        ? GeoPoint.fromShelter(target)
        : GeoPoint(
            16.9604,
            82.2382,
            name: widget.shelterName ?? AppStrings.nearestShelterName,
          );

    // 3. Compute dynamic evacuation corridor via RouteService
    final result = await _routeService.calculateEvacuationRoutes(
      userLocation: originPoint,
      shelterLocation: shelterPoint,
      disasterType: widget.initialDisaster,
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

  @override
  Widget build(BuildContext context) {
    final route = _getActiveRoute();
    final userLoc = UserProfileService.currentLocation;
    final destName = _destinationShelter?.name ?? widget.shelterName ?? AppStrings.toDestination;

    return ValueListenableBuilder<String>(
      valueListenable: LocaleService.currentLocale,
      builder: (context, locale, _) {
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppHeader(
            customTitle: AppStrings.navEvacuate,
          ),
          body: Column(
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
                // 1. Origin & Destination Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
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
                            label: route.isNavigableRoad ? 'DEMO ROAD GRAPH' : 'SIMULATED CORRIDOR',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 2. Cinematic Route Visual Canvas (Bypassing Hazard Zone)
                Container(
                  height: 190,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A), // Dark navy surface
                    borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
                    border: Border.all(color: const Color(0xFF1E293B)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _ObstacleBypassPainter(
                              isAlternate: _selectedRouteIndex == 1,
                              hasBlocked: route.hasBlockedRoads,
                              isNavigableRoad: route.isNavigableRoad,
                            ),
                          ),
                        ),
                        // Overlay: Interactive map switch button
                        Positioned(
                          right: 12,
                          bottom: 12,
                          child: Material(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(8),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () {
                                Navigator.pushNamed(context, AppRouter.map);
                              },
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.map_rounded, size: 14, color: Colors.white),
                                    SizedBox(width: 6),
                                    Text(
                                      'View on Full Map',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
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
                ),
                const SizedBox(height: 14),

                // 3. Metrics Telemetry Row (Distance, Time, Risk)
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
                              '~${route.estimatedTimeMinutes} min',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primaryBlue),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Approx @ 25 km/h',
                              style: TextStyle(fontSize: 10, color: AppColors.slate, fontWeight: FontWeight.w500),
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

                // 4. Hazard Avoidance Banner
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

                // 5. Turn-by-Turn Directives
                const Text(
                  'Turn Directives',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink),
                ),
                const SizedBox(height: 10),

                if (route.segments.isNotEmpty)
                  ...route.segments.asMap().entries.map((entry) {
                    final idx = entry.key + 1;
                    final seg = entry.value;
                    final isWarn = seg.riskLevel != RouteRiskLevel.low || seg.isBlocked;
                    return _buildStepDirective(
                      '$idx',
                      seg.turnInstruction ?? seg.roadName,
                      '${seg.distanceKm.toStringAsFixed(1)} km • ${seg.hazardNotes ?? "Verified evacuation section"}',
                      isWarn ? Icons.warning_amber_rounded : Icons.straight_rounded,
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

                // 6. Action Button: Start Guidance
                SizedBox(
                  width: double.infinity,
                  height: AppDimensions.buttonHeight,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: route.hasBlockedRoads ? AppColors.critical : AppColors.emerald,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                      ),
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            route.hasBlockedRoads
                                ? 'Active road hazards detected on this path. Use caution.'
                                : 'Evacuation guidance activated. Follow the high-ground corridor.',
                          ),
                          backgroundColor: route.hasBlockedRoads ? AppColors.critical : AppColors.emerald,
                        ),
                      );
                    },
                    icon: const Icon(Icons.navigation_rounded, size: 20),
                    label: Text(
                      AppStrings.startGuidance,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Alternate route toggle
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
    ),
  );
      },
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

/// Custom painter rendering the obstacle bypass curve and flood hazard zone.
class _ObstacleBypassPainter extends CustomPainter {
  final bool isAlternate;
  final bool hasBlocked;
  final bool isNavigableRoad;

  _ObstacleBypassPainter({
    required this.isAlternate,
    this.hasBlocked = false,
    this.isNavigableRoad = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Grid lines
    final gridPaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..strokeWidth = 1.0;
    for (double x = 0; x < size.width; x += 30) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += 30) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Top network status banner
    final modePainter = TextPainter(
      text: TextSpan(
        text: isNavigableRoad
            ? 'DEMO ROAD NETWORK (VIJAYAWADA)'
            : 'GEOMETRIC VECTOR (OFF-GRID)',
        style: TextStyle(
          color: isNavigableRoad ? AppColors.emerald.withOpacity(0.9) : const Color(0xFFF59E0B),
          fontSize: 8.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    modePainter.paint(canvas, Offset((size.width - modePainter.width) / 2, 8));

    // 2. Submerged / Hazard Zone (Red circle in middle)
    final hazardCenter = Offset(size.width * 0.48, size.height * 0.52);
    final hazardRadius = size.height * 0.30;

    final hazardPaint = Paint()
      ..color = AppColors.critical.withOpacity(0.3)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(hazardCenter, hazardRadius, hazardPaint);

    final hazardBorderPaint = Paint()
      ..color = AppColors.critical.withOpacity(0.8)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(hazardCenter, hazardRadius, hazardBorderPaint);

    // Hazard text label
    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'DEMO HAZARD: 1.2m FLOODING',
        style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, Offset(hazardCenter.dx - textPainter.width / 2, hazardCenter.dy - 6));

    // Blocked road red cross
    final xPaint = Paint()
      ..color = AppColors.critical
      ..strokeWidth = 2.5;
    canvas.drawLine(hazardCenter.translate(-8, -8), hazardCenter.translate(8, 8), xPaint);
    canvas.drawLine(hazardCenter.translate(8, -8), hazardCenter.translate(-8, 8), xPaint);

    // 3. Start Point (Bunder Road)
    final startPt = Offset(size.width * 0.12, size.height * 0.75);
    final endPt = Offset(size.width * 0.88, size.height * 0.25);

    // 4. Safe Bypass Route Path
    final routePath = Path();
    routePath.moveTo(startPt.dx, startPt.dy);

    if (isAlternate) {
      // Swings south
      routePath.cubicTo(
        size.width * 0.25, size.height * 0.95,
        size.width * 0.70, size.height * 0.85,
        endPt.dx, endPt.dy,
      );
    } else {
      // Swings north around hazard
      routePath.cubicTo(
        size.width * 0.25, size.height * 0.15,
        size.width * 0.70, size.height * 0.15,
        endPt.dx, endPt.dy,
      );
    }

    final Color pathColor = !isNavigableRoad
        ? const Color(0xFFF59E0B)
        : (hasBlocked ? AppColors.critical : AppColors.emerald);

    final routePaint = Paint()
      ..color = pathColor
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(routePath, routePaint);

    // 5. Origin and Destination Pins
    final bluePin = Paint()..color = AppColors.secondaryBlue;
    canvas.drawCircle(startPt, 7, bluePin);
    canvas.drawCircle(startPt, 3, Paint()..color = Colors.white);

    final greenPin = Paint()..color = AppColors.emerald;
    canvas.drawCircle(endPt, 8, greenPin);
    canvas.drawCircle(endPt, 4, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _ObstacleBypassPainter oldDelegate) {
    return oldDelegate.isAlternate != isAlternate ||
        oldDelegate.hasBlocked != hasBlocked ||
        oldDelegate.isNavigableRoad != isNavigableRoad;
  }
}
