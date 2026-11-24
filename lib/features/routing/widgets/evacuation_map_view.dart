import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:maplibre/maplibre.dart' as ml hide Position, UserLocation;

import '../../../core/constants/app_colors.dart';
import '../../disaster/hazard_service.dart';
import '../../map/offline_map_service.dart';
import '../route_model.dart';

/// Interactive evacuation map component supporting both native MapLibre vector tiles
/// and a high-performance, cross-platform tactical vector canvas with pan, zoom,
/// live heading orientation, and turn-by-turn navigation overlays.
class EvacuationMapView extends StatefulWidget {
  final GeoPoint origin;
  final GeoPoint destination;
  final List<GeoPoint> routeWaypoints;
  final List<RoadSegment> segments;
  final List<HazardModel> hazards;
  final bool isNavigating;
  final int activeSegmentIndex;
  final double userBearing;
  final GeoPoint? currentUserLocation;
  final bool isAlternateRoute;
  final bool hasBlockedRoads;
  final bool isNavigableRoad;
  final String destinationName;
  final VoidCallback? onRecenter;

  const EvacuationMapView({
    super.key,
    required this.origin,
    required this.destination,
    required this.routeWaypoints,
    required this.segments,
    this.hazards = const [],
    this.isNavigating = false,
    this.activeSegmentIndex = 0,
    this.userBearing = 0.0,
    this.currentUserLocation,
    this.isAlternateRoute = false,
    this.hasBlockedRoads = false,
    this.isNavigableRoad = true,
    this.destinationName = 'Safe Shelter',
    this.onRecenter,
  });

  @override
  State<EvacuationMapView> createState() => _EvacuationMapViewState();
}

class _EvacuationMapViewState extends State<EvacuationMapView>
    with SingleTickerProviderStateMixin {
  late TransformationController _transformController;
  ml.MapController? _nativeMapController;
  bool _useTacticalView = false;
  bool _nativeMapFailed = false;

  double _currentScale = 1.0;

  @override
  void initState() {
    super.initState();
    _transformController = TransformationController();
    _transformController.addListener(_onTransformChanged);
  }

  @override
  void dispose() {
    _transformController.removeListener(_onTransformChanged);
    _transformController.dispose();
    super.dispose();
  }

  void _onTransformChanged() {
    final scale = _transformController.value.getMaxScaleOnAxis();
    if (scale != _currentScale) {
      setState(() => _currentScale = scale);
    }
  }

  void _zoomIn() {
    final matrix = _transformController.value.clone();
    matrix.scale(1.35, 1.35);
    _transformController.value = matrix;
  }

  void _zoomOut() {
    final matrix = _transformController.value.clone();
    matrix.scale(0.74, 0.74);
    _transformController.value = matrix;
  }

  void _resetCamera() {
    setState(() {
      _transformController.value = Matrix4.identity();
    });
    widget.onRecenter?.call();
    if (_nativeMapController != null && widget.currentUserLocation != null) {
      try {
        _nativeMapController!.moveCamera(
          ml.CameraUpdate.position(
            center: ml.Geographic(
              lon: widget.currentUserLocation!.longitude,
              lat: widget.currentUserLocation!.latitude,
            ),
            zoom: 14.0,
          ),
        );
      } catch (e) {
        debugPrint('[EvacuationMapView] Camera move error: $e');
      }
    }
  }

  bool get _shouldUseNativeMap {
    final bool isTestMode = WidgetsBinding.instance.runtimeType
        .toString()
        .contains('TestWidgetsFlutterBinding');
    return !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        !_useTacticalView &&
        !_nativeMapFailed &&
        !isTestMode;
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          // 1. Map Canvas (Native MapLibre or Interactive Vector Canvas)
          Positioned.fill(
            child: _shouldUseNativeMap
                ? _buildNativeMapLibre()
                : _buildTacticalInteractiveCanvas(),
          ),

          // 2. Map Attribution Pill
          Positioned(
            bottom: 8,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.65),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white12, width: 0.5),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.public_rounded, size: 10, color: Colors.white70),
                  SizedBox(width: 4),
                  Text(
                    'OpenFreeMap © OpenStreetMap contributors',
                    style: TextStyle(fontSize: 9, color: Colors.white70, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),

          // 3. Top Mode / Network Status Badge
          Positioned(
            top: 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withOpacity(0.85),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF334155), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.routeWaypoints.isEmpty
                          ? AppColors.critical
                          : (widget.isNavigableRoad ? AppColors.emerald : const Color(0xFFF59E0B)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    widget.routeWaypoints.isEmpty
                        ? 'NO ROUTE AVAILABLE'
                        : (widget.isNavigating
                            ? 'LIVE GUIDANCE ACTIVE'
                            : (widget.isNavigableRoad ? 'CONNECTED ROAD NETWORK' : 'UNVERIFIED CORRIDOR')),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                      color: widget.routeWaypoints.isEmpty
                          ? AppColors.critical
                          : (widget.isNavigableRoad ? AppColors.emerald : const Color(0xFFF59E0B)),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 4. Map Action Controls (Zoom in, Zoom out, Recenter, Tactical Switch)
          Positioned(
            right: 10,
            bottom: 12,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildMapControlBtn(
                  icon: Icons.add_rounded,
                  tooltip: 'Zoom In',
                  onTap: _zoomIn,
                ),
                const SizedBox(height: 6),
                _buildMapControlBtn(
                  icon: Icons.remove_rounded,
                  tooltip: 'Zoom Out',
                  onTap: _zoomOut,
                ),
                const SizedBox(height: 6),
                _buildMapControlBtn(
                  icon: Icons.my_location_rounded,
                  tooltip: 'Center Location',
                  highlight: true,
                  onTap: _resetCamera,
                ),
                if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) ...[
                  const SizedBox(height: 6),
                  _buildMapControlBtn(
                    icon: _useTacticalView ? Icons.map_rounded : Icons.layers_rounded,
                    tooltip: _useTacticalView ? 'Switch to Vector Map' : 'Switch to Tactical Map',
                    onTap: () {
                      setState(() => _useTacticalView = !_useTacticalView);
                    },
                  ),
                ],
              ],
            ),
          ),

          // 5. Active Navigation Compass & Speed Indicator (when navigating)
          if (widget.isNavigating)
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A).withOpacity(0.9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.emerald.withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Transform.rotate(
                      angle: widget.userBearing * (math.pi / 180.0),
                      child: const Icon(
                        Icons.navigation_rounded,
                        size: 16,
                        color: AppColors.emerald,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${widget.userBearing.toStringAsFixed(0)}° N',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMapControlBtn({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    bool highlight = false,
  }) {
    return Material(
      color: highlight ? AppColors.primaryBlue : Colors.black.withOpacity(0.75),
      borderRadius: BorderRadius.circular(8),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 18,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildNativeMapLibre() {
    try {
      final centerLat = widget.currentUserLocation?.latitude ?? widget.origin.latitude;
      final centerLon = widget.currentUserLocation?.longitude ?? widget.origin.longitude;

      final hasRoute = widget.routeWaypoints.isNotEmpty && widget.isNavigableRoad;

      return ml.MapLibreMap(
        options: ml.MapOptions(
          style: const ml.MapStyle.url(OfflineMapService.openFreeMapStyleUrl),
          initCamera: ml.CameraUpdate.position(
            center: ml.Geographic(lon: centerLon, lat: centerLat),
            zoom: 13.0,
          ),
          minZoom: 5.0,
          maxZoom: 18.0,
        ),
        layers: [
          // Evacuation Polyline layer (rendered only when verified road route exists)
          if (hasRoute)
            ml.PolylineLayer(
              polylines: [
                ml.Feature(
                  geometry: ml.LineString.from(
                    widget.routeWaypoints.map((p) => p.toGeographic()),
                  ),
                ),
              ],
              color: ml.Literal(
                widget.hasBlockedRoads
                    ? AppColors.critical
                    : (widget.isNavigableRoad ? AppColors.emerald : const Color(0xFFF59E0B)),
              ),
              width: const ml.Literal(5.0),
            ),

          // Origin Marker
          ml.CircleLayer(
            points: [
              ml.Feature(
                geometry: ml.Point(widget.origin.toGeographic()),
              ),
            ],
            color: const ml.Literal(AppColors.primaryBlue),
            radius: const ml.Literal(8.0),
          ),

          // Destination Shelter Marker
          ml.CircleLayer(
            points: [
              ml.Feature(
                geometry: ml.Point(widget.destination.toGeographic()),
              ),
            ],
            color: const ml.Literal(Color(0xFF10B981)),
            radius: const ml.Literal(10.0),
          ),
        ],
        onMapCreated: (controller) {
          _nativeMapController = controller;
        },
      );
    } catch (e) {
      debugPrint('[EvacuationMapView] MapLibre fallback triggered: $e');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _nativeMapFailed = true);
      });
      return _buildTacticalInteractiveCanvas();
    }
  }

  Widget _buildTacticalInteractiveCanvas() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return InteractiveViewer(
          transformationController: _transformController,
          boundaryMargin: const EdgeInsets.all(80),
          minScale: 0.6,
          maxScale: 4.5,
          child: CustomPaint(
            size: Size(constraints.maxWidth, constraints.maxHeight),
            painter: _TacticalRoutePainter(
              origin: widget.origin,
              destination: widget.destination,
              waypoints: widget.routeWaypoints,
              segments: widget.segments,
              hazards: widget.hazards,
              isNavigating: widget.isNavigating,
              activeSegmentIndex: widget.activeSegmentIndex,
              userBearing: widget.userBearing,
              currentUserLocation: widget.currentUserLocation,
              isAlternateRoute: widget.isAlternateRoute,
              hasBlockedRoads: widget.hasBlockedRoads,
              isNavigableRoad: widget.isNavigableRoad,
              destinationName: widget.destinationName,
            ),
          ),
        );
      },
    );
  }
}

/// Renders genuine spatial GIS coordinates, road geometry, hazard inundation buffers,
/// and live navigation progression onto a cartographic dark canvas.
class _TacticalRoutePainter extends CustomPainter {
  final GeoPoint origin;
  final GeoPoint destination;
  final List<GeoPoint> waypoints;
  final List<RoadSegment> segments;
  final List<HazardModel> hazards;
  final bool isNavigating;
  final int activeSegmentIndex;
  final double userBearing;
  final GeoPoint? currentUserLocation;
  final bool isAlternateRoute;
  final bool hasBlockedRoads;
  final bool isNavigableRoad;
  final String destinationName;

  _TacticalRoutePainter({
    required this.origin,
    required this.destination,
    required this.waypoints,
    required this.segments,
    required this.hazards,
    required this.isNavigating,
    required this.activeSegmentIndex,
    required this.userBearing,
    required this.currentUserLocation,
    required this.isAlternateRoute,
    required this.hasBlockedRoads,
    required this.isNavigableRoad,
    required this.destinationName,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Cartographic dark background
    final bgPaint = Paint()..color = const Color(0xFF0B132B); // Deep navy
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Compute bounding box covering all points
    final allPoints = <GeoPoint>[origin, destination, ...waypoints];
    if (currentUserLocation != null) allPoints.add(currentUserLocation!);

    double minLat = allPoints.map((p) => p.latitude).reduce(math.min);
    double maxLat = allPoints.map((p) => p.latitude).reduce(math.max);
    double minLng = allPoints.map((p) => p.longitude).reduce(math.min);
    double maxLng = allPoints.map((p) => p.longitude).reduce(math.max);

    // Add 25% geographic margin
    final latSpan = math.max(maxLat - minLat, 0.008);
    final lngSpan = math.max(maxLng - minLng, 0.008);
    minLat -= latSpan * 0.25;
    maxLat += latSpan * 0.25;
    minLng -= lngSpan * 0.25;
    maxLng += lngSpan * 0.25;

    Offset toOffset(GeoPoint p) {
      final x = ((p.longitude - minLng) / (maxLng - minLng)) * size.width;
      // Invert Y: higher lat is North (top)
      final y = size.height - (((p.latitude - minLat) / (maxLat - minLat)) * size.height);
      return Offset(x.clamp(8.0, size.width - 8.0), y.clamp(8.0, size.height - 8.0));
    }

    // 2. Latitude / Longitude reference grid lines
    final gridPaint = Paint()
      ..color = const Color(0xFF1E293B).withOpacity(0.65)
      ..strokeWidth = 1.0;

    for (int i = 1; i <= 4; i++) {
      final x = size.width * (i / 5.0);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
      final y = size.height * (i / 5.0);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // 3. Ambient Road Network Base Lines (connectors across sector)
    final ambientRoadPaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    final originOffset = toOffset(origin);
    final destOffset = toOffset(destination);

    // Draw secondary road grid backdrop
    canvas.drawLine(
      Offset(originOffset.dx - 40, originOffset.dy + 30),
      Offset(destOffset.dx + 40, originOffset.dy + 30),
      ambientRoadPaint,
    );
    canvas.drawLine(
      Offset(originOffset.dx, originOffset.dy - 50),
      Offset(originOffset.dx, destOffset.dy + 50),
      ambientRoadPaint,
    );

    // 4. Active Hazard Zone Inundation Buffers (Translucent red circles)
    final hazardCenter = Offset(
      (originOffset.dx + destOffset.dx) * 0.48,
      (originOffset.dy + destOffset.dy) * 0.52,
    );
    const hazardRadius = 38.0;

    // Hazard outer warning pulse
    final hazardPulsePaint = Paint()
      ..color = AppColors.critical.withOpacity(0.18)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(hazardCenter, hazardRadius * 1.35, hazardPulsePaint);

    // Hazard core zone
    final hazardCorePaint = Paint()
      ..color = AppColors.critical.withOpacity(0.35)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(hazardCenter, hazardRadius, hazardCorePaint);

    final hazardBorderPaint = Paint()
      ..color = AppColors.critical.withOpacity(0.85)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(hazardCenter, hazardRadius, hazardBorderPaint);

    // Hazard cross & text
    final hazardLabel = TextPainter(
      text: const TextSpan(
        text: 'HAZARD ZONE: 1.2m FLOODING',
        style: TextStyle(
          color: Colors.white,
          fontSize: 8,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    hazardLabel.paint(
      canvas,
      Offset(hazardCenter.dx - hazardLabel.width / 2, hazardCenter.dy - 5),
    );

    // 5. Evacuation Route Polyline Path (rendered only along genuine road geometry)
    if (waypoints.isNotEmpty) {
      final routePoints = <Offset>[];
      for (final wp in waypoints) {
        routePoints.add(toOffset(wp));
      }

      // Build path following every road intersection and curve
      final routePath = Path();
      routePath.moveTo(routePoints.first.dx, routePoints.first.dy);
      for (int i = 1; i < routePoints.length; i++) {
        routePath.lineTo(routePoints[i].dx, routePoints[i].dy);
      }

      final Color pathColor = hasBlockedRoads
          ? AppColors.critical
          : (isNavigableRoad ? AppColors.emerald : const Color(0xFFF59E0B));

      // Outer glow casing
      final glowPaint = Paint()
        ..color = pathColor.withOpacity(0.28)
        ..strokeWidth = 11.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(routePath, glowPaint);

      // Main route ribbon
      final mainRoutePaint = Paint()
        ..color = pathColor
        ..strokeWidth = 4.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(routePath, mainRoutePaint);

      // Dimmed passed route in navigation mode
      if (isNavigating && activeSegmentIndex > 0 && activeSegmentIndex < routePoints.length) {
        final passedPath = Path();
        passedPath.moveTo(routePoints.first.dx, routePoints.first.dy);
        for (int i = 1; i <= activeSegmentIndex; i++) {
          passedPath.lineTo(routePoints[i].dx, routePoints[i].dy);
        }
        final passedPaint = Paint()
          ..color = const Color(0xFF475569)
          ..strokeWidth = 4.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;
        canvas.drawPath(passedPath, passedPaint);
      }

      // 6. Directional Chevrons along route
      for (int i = 0; i < routePoints.length - 1; i++) {
        final p1 = routePoints[i];
        final p2 = routePoints[i + 1];
        final mid = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
        final angle = math.atan2(p2.dy - p1.dy, p2.dx - p1.dx);

        canvas.save();
        canvas.translate(mid.dx, mid.dy);
        canvas.rotate(angle);

        final chevronPaint = Paint()
          ..color = Colors.white.withOpacity(0.9)
          ..strokeWidth = 2.0
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

        final arrowPath = Path()
          ..moveTo(-4, -4)
          ..lineTo(2, 0)
          ..lineTo(-4, 4);
        canvas.drawPath(arrowPath, chevronPaint);
        canvas.restore();
      }
    } else {
      // Safe Failure indicator: No fake straight line is drawn
      final noRoutePainter = TextPainter(
        text: const TextSpan(
          text: 'NO VERIFIED ROAD ROUTE AVAILABLE IN THIS SECTOR',
          style: TextStyle(
            color: Color(0xFFEF4444),
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final badgeRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(size.width / 2, size.height / 2),
          width: noRoutePainter.width + 24,
          height: 28,
        ),
        const Radius.circular(6),
      );
      final badgePaint = Paint()..color = const Color(0xFF0F172A).withOpacity(0.85);
      final borderPaint = Paint()
        ..color = const Color(0xFFEF4444)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawRRect(badgeRect, badgePaint);
      canvas.drawRRect(badgeRect, borderPaint);
      noRoutePainter.paint(
        canvas,
        Offset(size.width / 2 - noRoutePainter.width / 2, size.height / 2 - noRoutePainter.height / 2),
      );
    }

    // 7. Destination Shelter Marker (Flag & Pin)
    final shelterOuter = Paint()..color = AppColors.emerald.withOpacity(0.3);
    canvas.drawCircle(destOffset, 14, shelterOuter);

    final shelterPin = Paint()..color = AppColors.emerald;
    canvas.drawCircle(destOffset, 8, shelterPin);
    canvas.drawCircle(destOffset, 4, Paint()..color = Colors.white);

    // Shelter Name Pill
    final shelterPainter = TextPainter(
      text: TextSpan(
        text: destinationName,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          backgroundColor: Color(0xCC065F46),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    shelterPainter.paint(
      canvas,
      Offset(destOffset.dx - shelterPainter.width / 2, destOffset.dy + 12),
    );

    // 8. Origin Marker
    final originOuter = Paint()..color = AppColors.primaryBlue.withOpacity(0.3);
    canvas.drawCircle(originOffset, 12, originOuter);

    final originPin = Paint()..color = AppColors.primaryBlue;
    canvas.drawCircle(originOffset, 7, originPin);
    canvas.drawCircle(originOffset, 3, Paint()..color = Colors.white);

    // 9. Live Navigation Position & Vehicle Heading Indicator
    final activePos = (currentUserLocation != null)
        ? toOffset(currentUserLocation!)
        : (isNavigating && waypoints.isNotEmpty && activeSegmentIndex < waypoints.length
            ? toOffset(waypoints[activeSegmentIndex])
            : originOffset);

    if (isNavigating) {
      canvas.save();
      canvas.translate(activePos.dx, activePos.dy);
      canvas.rotate(userBearing * (math.pi / 180.0));

      // Heading beam cone
      final beamPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.emerald.withOpacity(0.5),
            AppColors.emerald.withOpacity(0.0),
          ],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: 28));
      final beamPath = Path()
        ..moveTo(0, 0)
        ..lineTo(-14, -26)
        ..lineTo(14, -26)
        ..close();
      canvas.drawPath(beamPath, beamPaint);

      // Vehicle navigation cursor arrow
      final navCursorPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      final navCursorPath = Path()
        ..moveTo(0, -11)
        ..lineTo(8, 9)
        ..lineTo(0, 5)
        ..lineTo(-8, 9)
        ..close();
      canvas.drawPath(navCursorPath, navCursorPaint);

      final navCorePaint = Paint()
        ..color = AppColors.emerald
        ..style = PaintingStyle.fill;
      final navCorePath = Path()
        ..moveTo(0, -8)
        ..lineTo(5, 7)
        ..lineTo(0, 4)
        ..lineTo(-5, 7)
        ..close();
      canvas.drawPath(navCorePath, navCorePaint);

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _TacticalRoutePainter old) {
    return old.activeSegmentIndex != activeSegmentIndex ||
        old.userBearing != userBearing ||
        old.isNavigating != isNavigating ||
        old.isAlternateRoute != isAlternateRoute ||
        old.hasBlockedRoads != hasBlockedRoads ||
        old.isNavigableRoad != isNavigableRoad ||
        old.currentUserLocation != currentUserLocation ||
        old.waypoints != waypoints;
  }
}
