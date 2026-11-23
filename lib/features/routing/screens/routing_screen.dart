import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/models/evacuation_route.dart';
import '../../../core/services/locale_service.dart';
import '../../../core/widgets/app_header.dart';
import '../../../core/widgets/demo_badge.dart';
import '../../../core/widgets/status_badge.dart';

/// Module Screen: Evacuation Routing & Decision Support matching 19_Evacuate.png.
class RoutingScreen extends StatefulWidget {
  final String? shelterId;
  final String? shelterName;

  const RoutingScreen({
    super.key,
    this.shelterId,
    this.shelterName,
  });

  @override
  State<RoutingScreen> createState() => _RoutingScreenState();
}

class _RoutingScreenState extends State<RoutingScreen> {
  int _selectedRouteIndex = 0; // 0 = Primary High Ground Bypass, 1 = Alternate NH-16

  @override
  Widget build(BuildContext context) {
    final route = EvacuationRoute(
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

    return ValueListenableBuilder<String>(
      valueListenable: LocaleService.currentLocale,
      builder: (context, locale, _) {
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppHeader(
            customTitle: AppStrings.navEvacuate,
          ),
          body: SingleChildScrollView(
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
                          child: Text(
                            AppStrings.fromLocation,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
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
                    Row(
                      children: [
                        const Icon(Icons.location_on_rounded, size: 18, color: AppColors.emerald),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.shelterName ?? AppStrings.toDestination,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.emerald,
                            ),
                          ),
                        ),
                        const DemoBadge(label: 'SIMULATED CORRIDOR'),
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
                  child: CustomPaint(
                    painter: _ObstacleBypassPainter(isAlternate: _selectedRouteIndex == 1),
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
                            '${route.estimatedTimeMinutes} min',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primaryBlue),
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
                            label: _selectedRouteIndex == 0 ? AppStrings.moderateRisk : AppStrings.lowRisk,
                            severity: _selectedRouteIndex == 0 ? BadgeSeverity.moderate : BadgeSeverity.positive,
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
                  children: [
                    const Icon(Icons.shield_outlined, size: 20, color: AppColors.emerald),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        AppStrings.hazardAvoidanceNote,
                        style: const TextStyle(fontSize: 12, color: AppColors.ink, fontWeight: FontWeight.w500),
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
              _buildStepDirective(
                '1',
                'Depart Bandar Road Heading West',
                '0.0 km • Elevation 18m above sea level',
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
                'Arrive at Bhavani Island Relief Center',
                '2.4 km • Designated emergency shelter',
                Icons.check_circle_outline_rounded,
                false,
              ),
              const SizedBox(height: 18),

              // 6. Action Button: Start Guidance
              SizedBox(
                width: double.infinity,
                height: AppDimensions.buttonHeight,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.emerald,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                    ),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Evacuation guidance activated. Follow the high-ground corridor.'),
                        backgroundColor: AppColors.emerald,
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
        color: isWarning ? AppColors.high.withValues(alpha: 0.06) : AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(
          color: isWarning ? AppColors.high.withValues(alpha: 0.3) : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isWarning ? AppColors.high.withValues(alpha: 0.15) : AppColors.primaryBlue.withValues(alpha: 0.1),
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

  _ObstacleBypassPainter({required this.isAlternate});

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

    // 2. Submerged / Hazard Zone (Red circle in middle)
    final hazardCenter = Offset(size.width * 0.48, size.height * 0.52);
    final hazardRadius = size.height * 0.30;

    final hazardPaint = Paint()
      ..color = AppColors.critical.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(hazardCenter, hazardRadius, hazardPaint);

    final hazardBorderPaint = Paint()
      ..color = AppColors.critical.withValues(alpha: 0.8)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(hazardCenter, hazardRadius, hazardBorderPaint);

    // Hazard text label
    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'HAZARD: 1.2m FLOODING',
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

    final routePaint = Paint()
      ..color = AppColors.emerald
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(routePath, routePaint);

    // 5. Origin and Destination Pins
    // Start pin (Blue)
    final bluePin = Paint()..color = AppColors.secondaryBlue;
    canvas.drawCircle(startPt, 7, bluePin);
    canvas.drawCircle(startPt, 3, Paint()..color = Colors.white);

    // End pin (Green)
    final greenPin = Paint()..color = AppColors.emerald;
    canvas.drawCircle(endPt, 8, greenPin);
    canvas.drawCircle(endPt, 4, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _ObstacleBypassPainter oldDelegate) {
    return oldDelegate.isAlternate != isAlternate;
  }
}
