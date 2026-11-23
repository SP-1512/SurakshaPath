import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/services/locale_service.dart';
import '../../../core/services/user_profile_service.dart';
import '../../../core/widgets/app_header.dart';
import '../../../navigation/app_router.dart';

/// Full-screen interactive emergency evacuation map.
/// Google Maps & Apple Maps inspired visual design with hazard layers,
/// evacuation corridors, and shelter telemetry bottom sheet.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  bool _showHazards = true;
  bool _showCorridors = true;
  final String _selectedShelter = 'Bhavani Island Relief Center';
  final String _shelterDistance = '1.8 km away';

  @override
  Widget build(BuildContext context) {
    final location = UserProfileService.currentLocation;

    return ValueListenableBuilder<String>(
      valueListenable: LocaleService.currentLocale,
      builder: (context, locale, _) {
        return Scaffold(
          appBar: AppHeader(customTitle: AppStrings.navMap),
          body: Stack(
            children: [
          // 1. Dominant Vector Navigation Map Canvas
          Positioned.fill(
            child: CustomPaint(
              painter: _MapCanvasPainter(
                showHazards: _showHazards,
                showCorridors: _showCorridors,
              ),
            ),
          ),

          // 2. Top Floating Search & Telemetry Bar (Apple Maps Style)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.space16,
                vertical: AppDimensions.space8,
              ),
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                      border: Border.all(color: AppColors.border, width: 1.0),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Row(
                      children: [
                        const FlaticonView(
                          assetPath: AppIcons.search,
                          size: 18,
                          color: AppColors.brandBlueDeep,
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Search safe shelters, relief camps...',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceMuted,
                            borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FlaticonView(
                                assetPath: AppIcons.offline,
                                size: 12,
                                color: AppColors.textMuted,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'SIMULATED MAP',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textSecondary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Floating Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        FilterChip(
                          avatar: const FlaticonView(
                            assetPath: AppIcons.shelter,
                            size: 14,
                            color: AppColors.emeraldGreen,
                          ),
                          label: const Text('Safe Shelters (4)'),
                          selected: true,
                          onSelected: (_) {},
                          selectedColor: Colors.white,
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                            side: const BorderSide(color: AppColors.border),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          avatar: const FlaticonView(
                            assetPath: AppIcons.warning,
                            size: 14,
                            color: AppColors.warningOrange,
                          ),
                          label: const Text('Flood Perimeter'),
                          selected: _showHazards,
                          onSelected: (val) => setState(() => _showHazards = val),
                          selectedColor: Colors.white,
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                            side: const BorderSide(color: AppColors.border),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          avatar: const FlaticonView(
                            assetPath: AppIcons.evacuate,
                            size: 14,
                            color: AppColors.brandBlueDeep,
                          ),
                          label: const Text('Evac Corridor'),
                          selected: _showCorridors,
                          onSelected: (val) => setState(() => _showCorridors = val),
                          selectedColor: Colors.white,
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                            side: const BorderSide(color: AppColors.border),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          avatar: const FlaticonView(
                            assetPath: AppIcons.pin,
                            size: 14,
                            color: AppColors.brandBlueDeep,
                          ),
                          label: const Text('GPS ±8m'),
                          selected: true,
                          onSelected: (_) {},
                          selectedColor: Colors.white,
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                            side: const BorderSide(color: AppColors.border),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Map Legend Indicator
          Positioned(
            left: 16,
            bottom: 160,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.92),
                borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
                border: Border.all(color: AppColors.border, width: 1.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _LegendItem(color: AppColors.emeraldGreen, label: 'Designated Shelter'),
                  SizedBox(height: 4),
                  _LegendItem(color: AppColors.warningOrange, label: 'Flood Hazard Zone'),
                  SizedBox(height: 4),
                  _LegendItem(color: AppColors.brandBlueBright, label: 'Evac Corridor'),
                ],
              ),
            ),
          ),

          // 4. Floating GPS Recenter Button
          Positioned(
            right: 16,
            bottom: 160,
            child: FloatingActionButton.small(
              heroTag: 'recenter_gps_fab',
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      location.isLiveFix
                          ? 'GPS Fix: ${location.locationName} (±${location.accuracyMeters!.toStringAsFixed(1)}m)'
                          : '${location.provenance.label}: ${location.locationName}',
                    ),
                    duration: const Duration(seconds: 2),
                    backgroundColor: AppColors.brandBlueDeep,
                  ),
                );
              },
              backgroundColor: Colors.white,
              foregroundColor: AppColors.brandBlueDeep,
              child: const Icon(Icons.my_location),
            ),
          ),

          // 5. Bottom Peek Shelter Card (PlayStation & Tesla Inset Panel)
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Container(
              padding: const EdgeInsets.all(AppDimensions.space16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
                border: Border.all(color: AppColors.border, width: 1.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.emeraldGreenLight,
                          borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
                        ),
                        child: const FlaticonView(
                          assetPath: AppIcons.shelter,
                          size: 22,
                          color: AppColors.emeraldGreen,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedShelter,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$_shelterDistance • Capacity Unverified (Demo)',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.warningOrange,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pushNamed(
                              context,
                              AppRouter.routing,
                              arguments: {
                                'shelterId': 'shelter-101',
                                'shelterName': _selectedShelter,
                              },
                            );
                          },
                          icon: const FlaticonView(
                            assetPath: AppIcons.evacuate,
                            size: 16,
                            color: Colors.white,
                          ),
                          label: const Text(
                            'View route',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.brandBlueDeep,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 48),
                            shape: const StadiumBorder(),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
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
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _MapCanvasPainter extends CustomPainter {
  final bool showHazards;
  final bool showCorridors;

  _MapCanvasPainter({
    required this.showHazards,
    required this.showCorridors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Soft map background canvas
    final bgPaint = Paint()..color = const Color(0xFFEAF0F6);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // 2. City block polygons (Urban layout)
    final blockPaint = Paint()..color = const Color(0xFFF3F6FA);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.05, size.height * 0.12, size.width * 0.25, size.height * 0.28),
        const Radius.circular(8),
      ),
      blockPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.38, size.height * 0.12, size.width * 0.28, size.height * 0.28),
        const Radius.circular(8),
      ),
      blockPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.72, size.height * 0.12, size.width * 0.24, size.height * 0.28),
        const Radius.circular(8),
      ),
      blockPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.05, size.height * 0.48, size.width * 0.40, size.height * 0.22),
        const Radius.circular(8),
      ),
      blockPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.55, size.height * 0.48, size.width * 0.40, size.height * 0.22),
        const Radius.circular(8),
      ),
      blockPaint,
    );

    // 3. Road casings (Dark hairline borders for roads)
    final roadCasingPaint = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..strokeWidth = 9.0;
    final roadFillPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 7.0;

    // Major Arterial 1: Horizontal Boulevard
    final hRoadOffset1 = Offset(0, size.height * 0.44);
    final hRoadOffset2 = Offset(size.width, size.height * 0.44);
    canvas.drawLine(hRoadOffset1, hRoadOffset2, roadCasingPaint);
    canvas.drawLine(hRoadOffset1, hRoadOffset2, roadFillPaint);

    // Major Arterial 2: Vertical Avenues
    final vRoad1Start = Offset(size.width * 0.34, 0);
    final vRoad1End = Offset(size.width * 0.34, size.height);
    canvas.drawLine(vRoad1Start, vRoad1End, roadCasingPaint);
    canvas.drawLine(vRoad1Start, vRoad1End, roadFillPaint);

    final vRoad2Start = Offset(size.width * 0.70, 0);
    final vRoad2End = Offset(size.width * 0.70, size.height);
    canvas.drawLine(vRoad2Start, vRoad2End, roadCasingPaint);
    canvas.drawLine(vRoad2Start, vRoad2End, roadFillPaint);

    // Highway Curve (Ring Road Highway)
    final ringRoadCasing = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..strokeWidth = 10.0
      ..style = PaintingStyle.stroke;
    final ringRoadFill = Paint()
      ..color = Colors.white
      ..strokeWidth = 8.0
      ..style = PaintingStyle.stroke;

    final ringPath = Path()
      ..moveTo(0, size.height * 0.20)
      ..cubicTo(size.width * 0.4, size.height * 0.16, size.width * 0.8, size.height * 0.28, size.width, size.height * 0.22);
    canvas.drawPath(ringPath, ringRoadCasing);
    canvas.drawPath(ringPath, ringRoadFill);

    // 4. Coastal Waterway / Estuary Canal
    final riverPaint = Paint()
      ..color = const Color(0xFF93C5FD)
      ..style = PaintingStyle.fill;
    final riverPath = Path()
      ..moveTo(0, size.height * 0.75)
      ..cubicTo(size.width * 0.3, size.height * 0.70, size.width * 0.6, size.height * 0.85, size.width, size.height * 0.80)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(riverPath, riverPaint);

    // Bridge crossway across river
    final bridgePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 10.0;
    canvas.drawLine(
      Offset(size.width * 0.70, size.height * 0.78),
      Offset(size.width * 0.70, size.height * 0.84),
      bridgePaint,
    );

    // 5. Flood Hazard Zone (Translucent orange/red with boundary)
    if (showHazards) {
      final hazardGlow = Paint()
        ..color = AppColors.warningOrange.withOpacity(0.28)
        ..style = PaintingStyle.fill;
      final hazardBorder = Paint()
        ..color = AppColors.warningOrange
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;

      final hazardCenter = Offset(size.width * 0.24, size.height * 0.72);
      canvas.drawCircle(hazardCenter, 56, hazardGlow);
      canvas.drawCircle(hazardCenter, 56, hazardBorder);

      // Warning marker in hazard center
      final hazardMarker = Paint()..color = AppColors.warningOrange;
      canvas.drawCircle(hazardCenter, 7, hazardMarker);
    }

    // 6. Arterial Evacuation Route (High-contrast blue corridor with glow)
    if (showCorridors) {
      final evacGlowPaint = Paint()
        ..color = AppColors.brandBlueBright.withOpacity(0.35)
        ..strokeWidth = 12.0
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      final evacRoutePaint = Paint()
        ..color = AppColors.brandBlueBright
        ..strokeWidth = 5.0
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      final evacPath = Path()
        ..moveTo(size.width * 0.48, size.height * 0.60) // Start at user
        ..lineTo(size.width * 0.48, size.height * 0.44)
        ..lineTo(size.width * 0.70, size.height * 0.44)
        ..lineTo(size.width * 0.70, size.height * 0.28); // End at shelter

      canvas.drawPath(evacPath, evacGlowPaint);
      canvas.drawPath(evacPath, evacRoutePaint);
    }

    // 7. Shelter Markers (Emerald Green Designated Hubs)
    // Shelter 1: Sector 14 Primary Hub
    final shelterOffset1 = Offset(size.width * 0.70, size.height * 0.28);
    final shelterOuter = Paint()..color = AppColors.emeraldGreen.withOpacity(0.25);
    final shelterInner = Paint()..color = AppColors.emeraldGreen;
    final whiteHalo = Paint()
      ..color = Colors.white
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(shelterOffset1, 18, shelterOuter);
    canvas.drawCircle(shelterOffset1, 10, shelterInner);
    canvas.drawCircle(shelterOffset1, 10, whiteHalo);

    // Shelter 2: Secondary School Camp
    final shelterOffset2 = Offset(size.width * 0.34, size.height * 0.16);
    canvas.drawCircle(shelterOffset2, 14, shelterOuter);
    canvas.drawCircle(shelterOffset2, 8, shelterInner);
    canvas.drawCircle(shelterOffset2, 8, whiteHalo);

    // 8. User GPS Location Puck (Blue with pulse ring)
    final userOffset = Offset(size.width * 0.48, size.height * 0.60);
    final pulsePaint = Paint()..color = AppColors.brandBlueBright.withOpacity(0.30);
    final userPuck = Paint()..color = AppColors.brandBlueDeep;
    final userWhiteBorder = Paint()
      ..color = Colors.white
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(userOffset, 20, pulsePaint);
    canvas.drawCircle(userOffset, 8, userPuck);
    canvas.drawCircle(userOffset, 8, userWhiteBorder);
  }

  @override
  bool shouldRepaint(covariant _MapCanvasPainter oldDelegate) {
    return oldDelegate.showHazards != showHazards ||
        oldDelegate.showCorridors != showCorridors;
  }
}
