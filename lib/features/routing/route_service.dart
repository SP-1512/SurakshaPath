// lib/features/routing/route_service.dart
// Dynamic GIS evacuation routing engine for SurakshaPath.
// Supports graph-based Dijkstra search, dynamic origin/destination snapping,
// hazard boundary assessment, and geometric corridor fallbacks.

import 'dart:convert';
import 'package:flutter/services.dart';
import '../../core/models/disaster_type.dart';
import '../disaster/hazard_service.dart';
import 'route_model.dart';

class _GraphEdge {
  final String id;
  final String sourceNodeId;
  final String targetNodeId;
  final String roadName;
  final double distanceKm;
  final GeoPoint startPoint;
  final GeoPoint endPoint;
  final bool initiallyBlocked;
  final String turnInstruction;
  final String elevationCategory;

  const _GraphEdge({
    required this.id,
    required this.sourceNodeId,
    required this.targetNodeId,
    required this.roadName,
    required this.distanceKm,
    required this.startPoint,
    required this.endPoint,
    this.initiallyBlocked = false,
    required this.turnInstruction,
    this.elevationCategory = 'Normal Ground',
  });
}

class RouteService {
  static final RouteService _instance = RouteService._internal();
  factory RouteService() => _instance;
  RouteService._internal();

  final HazardService _hazardService = HazardService();

  Map<String, List<_GraphEdge>>? _cachedGraph;

  /// Dynamic Evacuation Route Calculation.
  /// Accepts arbitrary user origin and target shelter coordinates.
  /// Validates graph proximity before graph search.
  Future<RouteCalculationResult> calculateEvacuationRoutes({
    required GeoPoint userLocation,
    required GeoPoint shelterLocation,
    required DisasterType disasterType,
    List<HazardModel>? customHazards,
  }) async {
    final hazards = customHazards ?? await _hazardService.getHazardsForDisaster(disasterType);
    final graph = await _getOrBuildRoadGraph();

    // 1. Proximity Validation: Check if start and destination are near our known road network
    final closestStartNode = _findClosestNode(userLocation, graph);
    final closestTargetNode = _findClosestNode(shelterLocation, graph);

    final double startToGraphKm = closestStartNode != null
        ? userLocation.distanceTo(closestStartNode.location)
        : double.infinity;
    final double targetToGraphKm = closestTargetNode != null
        ? shelterLocation.distanceTo(closestTargetNode.location)
        : double.infinity;

    // If either point is further than 5 km from our localized graph coverage,
    // do NOT falsely snap across the state to Vijayawada.
    // Instead, compute an honest geometric corridor labeled ROUTE SAFETY UNVERIFIED.
    const double maxSnappingRadiusKm = 5.0;
    if (startToGraphKm > maxSnappingRadiusKm || targetToGraphKm > maxSnappingRadiusKm) {
      return _buildGeometricCorridorResult(
        userLocation: userLocation,
        shelterLocation: shelterLocation,
        disasterType: disasterType,
        hazards: hazards,
      );
    }

    // 2. Points are within local graph envelope: Run Dijkstra graph search
    final startNodeId = closestStartNode!.id;
    final targetNodeId = closestTargetNode!.id;

    final List<EvacuationRoute> calculatedRoutes = [];

    // Path 1: Safest path avoiding active hazards
    final safePathEdges = _dijkstra(
      graph: graph,
      startId: startNodeId,
      targetId: targetNodeId,
      disasterType: disasterType,
      hazards: hazards,
      avoidHazards: true,
    );

    EvacuationRoute? primarySafeRoute;
    if (safePathEdges != null && safePathEdges.isNotEmpty) {
      primarySafeRoute = _buildEvacuationRoute(
        id: 'ROUTE-PRIMARY-SAFE',
        name: 'Recommended Evacuation Route',
        pathEdges: safePathEdges,
        userLocation: userLocation,
        shelterLocation: shelterLocation,
        disasterType: disasterType,
        hazards: hazards,
        isRecommended: true,
        elevationProfile: 'Nominal Corridor (Simulated Elevation)',
        customExplanation: 'Corridor clear of known active hazard perimeters on local network.',
      );
      calculatedRoutes.add(primarySafeRoute);
    }

    // Path 2: Alternative corridor (penalize primary route's primary edge to find alternative)
    if (safePathEdges != null && safePathEdges.isNotEmpty) {
      final edgesToPenalize = {safePathEdges.first.id};
      final altPathEdges = _dijkstra(
        graph: graph,
        startId: startNodeId,
        targetId: targetNodeId,
        disasterType: disasterType,
        hazards: hazards,
        avoidHazards: true,
        penalizedEdgeIds: edgesToPenalize,
      );

      if (altPathEdges != null && altPathEdges.isNotEmpty && !_areEdgeListsIdentical(safePathEdges, altPathEdges)) {
        final altRoute = _buildEvacuationRoute(
          id: 'ROUTE-SECONDARY-ALT',
          name: 'Alternative Evacuation Corridor',
          pathEdges: altPathEdges,
          userLocation: userLocation,
          shelterLocation: shelterLocation,
          disasterType: disasterType,
          hazards: hazards,
          isRecommended: false,
          elevationProfile: 'Secondary Bypass (Simulated Elevation)',
          customExplanation: 'Clear secondary alternative path if primary corridor experiences evacuation congestion.',
        );
        calculatedRoutes.add(altRoute);
      }
    }

    // Path 3: Direct shortest path (checking if standard shortest path is hazardous/blocked)
    final shortestPathEdges = _dijkstra(
      graph: graph,
      startId: startNodeId,
      targetId: targetNodeId,
      disasterType: disasterType,
      hazards: hazards,
      avoidHazards: false,
    );

    EvacuationRoute? directRoute;
    if (shortestPathEdges != null && shortestPathEdges.isNotEmpty && !_areEdgeListsIdentical(safePathEdges ?? [], shortestPathEdges)) {
      directRoute = _buildEvacuationRoute(
        id: 'ROUTE-DIRECT-SHORTEST',
        name: 'Direct Arterial Corridor',
        pathEdges: shortestPathEdges,
        userLocation: userLocation,
        shelterLocation: shelterLocation,
        disasterType: disasterType,
        hazards: hazards,
        isRecommended: false,
        elevationProfile: 'Low-Lying Corridor (Simulated Elevation)',
      );
      calculatedRoutes.add(directRoute);
    }

    // Determine honest status message and state
    final bool hasSafe = primarySafeRoute != null && !primarySafeRoute.hasBlockedRoads;
    final RouteVerificationState state = hasSafe
        ? RouteVerificationState.routeAvailable
        : RouteVerificationState.noVerifiedRoute;

    final String status = hasSafe
        ? '${calculatedRoutes.length} evacuation corridor(s) calculated. Primary route clear of reported hazards.'
        : (shortestPathEdges == null
            ? 'No connected road path found between selected locations on local demo network.'
            : 'Active hazard alerts block all evaluated road network corridors. Seek elevated shelter immediately.');

    return RouteCalculationResult(
      recommendedRoute: primarySafeRoute,
      alternativeRoute: calculatedRoutes.length > 1 ? calculatedRoutes[1] : directRoute,
      allRoutes: calculatedRoutes,
      startPoint: userLocation,
      destinationShelter: shelterLocation,
      disasterType: disasterType,
      statusMessage: status,
      state: state,
    );
  }

  /// Evaluates an evacuation corridor geometrically when no local street graph exists.
  RouteCalculationResult _buildGeometricCorridorResult({
    required GeoPoint userLocation,
    required GeoPoint shelterLocation,
    required DisasterType disasterType,
    required List<HazardModel> hazards,
  }) {
    final double distKm = userLocation.distanceTo(shelterLocation);
    final int travelMinutes = ((distKm / 25.0) * 60).round().clamp(2, 600);

    // Assess hazard risk along direct geometric corridor
    final assessment = _hazardService.assessSegmentRisk(
      userLocation,
      shelterLocation,
      disasterType,
      activeHazards: hazards,
    );

    final bool isBlocked = assessment.isBlocked;
    final RouteRiskLevel risk = isBlocked
        ? RouteRiskLevel.blocked
        : (assessment.isDirectlyHit
            ? RouteRiskLevel.high
            : (assessment.isBufferZone ? RouteRiskLevel.moderate : RouteRiskLevel.low));

    // Construct intermediate waypoints along the bearing line for smooth polyline rendering
    final waypoints = <GeoPoint>[userLocation];
    const steps = 4;
    for (int i = 1; i < steps; i++) {
      final frac = i / steps;
      final lat = userLocation.latitude + (shelterLocation.latitude - userLocation.latitude) * frac;
      final lng = userLocation.longitude + (shelterLocation.longitude - userLocation.longitude) * frac;
      waypoints.add(GeoPoint(lat, lng, name: 'Corridor Marker $i'));
    }
    waypoints.add(shelterLocation);

    final segment = RoadSegment(
      id: 'geom_${userLocation.lat}_${shelterLocation.lat}',
      start: userLocation,
      end: shelterLocation,
      roadName: 'Direct Evacuation Bearing Line',
      distanceKm: double.parse(distKm.toStringAsFixed(2)),
      isBlocked: isBlocked,
      riskLevel: risk,
      hazardNotes: assessment.explanation,
      turnInstruction: 'Head towards destination shelter along bearing ${userLocation.bearingTo(shelterLocation).toStringAsFixed(0)}°',
    );

    final route = EvacuationRoute(
      id: 'GEOMETRIC-CORRIDOR',
      name: 'Evacuation Bearing Corridor',
      destinationShelterId: shelterLocation.name ?? 'shelter',
      destinationShelterName: shelterLocation.name ?? 'Destination Shelter',
      waypoints: waypoints,
      segments: [segment],
      totalDistanceKm: double.parse(distKm.toStringAsFixed(2)),
      estimatedMinutes: travelMinutes,
      riskLevel: risk,
      verificationState: RouteVerificationState.routeSafetyUnverified,
      riskScore: isBlocked ? 95.0 : (risk == RouteRiskLevel.high ? 70.0 : 35.0),
      riskExplanation: 'Geometric evacuation vector. ${assessment.explanation}',
      disclaimer: 'Detailed street network graph is not loaded for this region. Straight-line evacuation corridor shown. Route safety unverified - proceed with caution.',
      isRecommended: !isBlocked,
      hasBlockedRoads: isBlocked,
      isDemo: true,
    );

    return RouteCalculationResult(
      recommendedRoute: isBlocked ? null : route,
      alternativeRoute: null,
      allRoutes: [route],
      startPoint: userLocation,
      destinationShelter: shelterLocation,
      disasterType: disasterType,
      statusMessage: isBlocked
          ? 'Geometric evacuation vector intersects critical hazard zone. Route impassable.'
          : 'Direct evacuation corridor calculated. Local street network unverified.',
      state: isBlocked ? RouteVerificationState.noVerifiedRoute : RouteVerificationState.routeSafetyUnverified,
    );
  }

  /// Shelter Evaluation Engine for Member 4 (Shanmukh)
  Future<List<ShelterRouteAssessment>> rankSheltersBySafety({
    required GeoPoint userLocation,
    required List<GeoPoint> candidateShelters,
    required DisasterType disasterType,
  }) async {
    final List<ShelterRouteAssessment> list = [];

    for (final shelter in candidateShelters) {
      final res = await calculateEvacuationRoutes(
        userLocation: userLocation,
        shelterLocation: shelter,
        disasterType: disasterType,
      );

      final route = res.recommendedRoute ?? res.alternativeRoute;
      final isClear = route != null && !route.hasBlockedRoads && !route.isBlocked;

      String rec;
      if (isClear && route.riskLevel == RouteRiskLevel.low) {
        rec = 'Recommended: Route evaluated clear of active reported hazards.';
      } else if (isClear) {
        rec = 'Accessible with Caution: Slower transit advised near hazard perimeters.';
      } else {
        rec = 'Impassable: Active hazard closures block safe transit to this shelter.';
      }

      list.add(ShelterRouteAssessment(
        shelterId: shelter.name ?? 'shelter_${shelter.lat}_${shelter.lng}',
        shelterName: shelter.name ?? 'Evacuation Shelter',
        shelterLocation: shelter,
        safestRoute: route,
        distanceKm: route?.totalDistanceKm ?? userLocation.distanceTo(shelter),
        travelMinutes: route?.estimatedMinutes ?? ((userLocation.distanceTo(shelter) / 25.0) * 60).round().clamp(2, 600),
        riskScore: route?.riskScore ?? (isClear ? 30.0 : 90.0),
        isAccessible: isClear,
        recommendation: rec,
      ));
    }

    list.sort((a, b) {
      if (a.isAccessible != b.isAccessible) {
        return a.isAccessible ? -1 : 1;
      }
      final riskCompare = a.riskScore.compareTo(b.riskScore);
      if (riskCompare != 0) return riskCompare;
      return a.distanceKm.compareTo(b.distanceKm);
    });

    return list;
  }

  /// Dijkstra's Shortest & Safest Path Algorithm implementation
  List<_GraphEdge>? _dijkstra({
    required Map<String, List<_GraphEdge>> graph,
    required String startId,
    required String targetId,
    required DisasterType disasterType,
    required List<HazardModel> hazards,
    required bool avoidHazards,
    Set<String> penalizedEdgeIds = const {},
  }) {
    if (!graph.containsKey(startId) || !graph.containsKey(targetId)) return null;

    final distances = <String, double>{};
    final previousEdges = <String, _GraphEdge>{};
    final unvisited = <String>{};

    for (final node in graph.keys) {
      distances[node] = double.infinity;
      unvisited.add(node);
    }
    distances[startId] = 0.0;

    while (unvisited.isNotEmpty) {
      String? currentNode;
      double minDistance = double.infinity;
      for (final node in unvisited) {
        if (distances[node]! < minDistance) {
          minDistance = distances[node]!;
          currentNode = node;
        }
      }

      if (currentNode == null || minDistance == double.infinity) break;
      if (currentNode == targetId) break;

      unvisited.remove(currentNode);

      for (final edge in graph[currentNode] ?? []) {
        if (!unvisited.contains(edge.targetNodeId)) continue;

        double edgeCost = edge.distanceKm;

        if (penalizedEdgeIds.contains(edge.id)) {
          edgeCost += 50.0; // Penalty to force alternative path discovery
        }

        if (avoidHazards) {
          final assessment = _hazardService.assessSegmentRisk(
            edge.startPoint,
            edge.endPoint,
            disasterType,
            activeHazards: hazards,
          );

          if (edge.initiallyBlocked || assessment.isBlocked) {
            edgeCost = 99999.0; // Blocked or submerged road
          } else {
            edgeCost = edge.distanceKm * assessment.riskMultiplier;
            if (assessment.isDirectlyHit) {
              edgeCost += 50.0;
            } else if (assessment.isBufferZone) {
              edgeCost += 10.0;
            }
          }
        }

        final tentative = distances[currentNode]! + edgeCost;
        if (tentative < distances[edge.targetNodeId]!) {
          distances[edge.targetNodeId] = tentative;
          previousEdges[edge.targetNodeId] = edge;
        }
      }
    }

    if (distances[targetId] == double.infinity && avoidHazards) {
      // No safe path exists. Do NOT silently return unsafe path disguised as safe.
      return null;
    }

    final path = <_GraphEdge>[];
    String curr = targetId;
    while (curr != startId) {
      final edge = previousEdges[curr];
      if (edge == null) break;
      path.insert(0, edge);
      curr = edge.sourceNodeId;
    }

    return path.isEmpty ? null : path;
  }

  EvacuationRoute _buildEvacuationRoute({
    required String id,
    required String name,
    required List<_GraphEdge> pathEdges,
    required GeoPoint userLocation,
    required GeoPoint shelterLocation,
    required DisasterType disasterType,
    required List<HazardModel> hazards,
    required bool isRecommended,
    required String elevationProfile,
    String? customExplanation,
  }) {
    final waypoints = <GeoPoint>[userLocation];
    final segments = <RoadSegment>[];
    double totalKm = 0.0;
    bool hasBlocked = false;
    double maxMultiplier = 1.0;
    final hazardReasons = <String>[];

    // 1. Initial Approach Leg (User GPS location to first graph road node)
    if (pathEdges.isNotEmpty) {
      final double startLegKm = userLocation.distanceTo(pathEdges.first.startPoint);
      if (startLegKm > 0.02) {
        final startAssessment = _hazardService.assessSegmentRisk(
          userLocation,
          pathEdges.first.startPoint,
          disasterType,
          activeHazards: hazards,
        );
        final isStartBlocked = startAssessment.isBlocked;
        if (isStartBlocked) hasBlocked = true;
        final startRisk = isStartBlocked
            ? RouteRiskLevel.blocked
            : (startAssessment.isDirectlyHit
                ? RouteRiskLevel.high
                : (startAssessment.isBufferZone ? RouteRiskLevel.moderate : RouteRiskLevel.low));

        if (startAssessment.riskMultiplier > maxMultiplier) {
          maxMultiplier = startAssessment.riskMultiplier;
        }

        segments.add(RoadSegment(
          id: 'approach_${userLocation.lat}_${pathEdges.first.sourceNodeId}',
          start: userLocation,
          end: pathEdges.first.startPoint,
          roadName: 'Approach to ${pathEdges.first.roadName}',
          distanceKm: double.parse(startLegKm.toStringAsFixed(2)),
          isBlocked: isStartBlocked,
          riskLevel: startRisk,
          hazardNotes: startAssessment.explanation,
          turnInstruction: 'Head towards ${pathEdges.first.sourceNodeId} via access road',
        ));
        totalKm += startLegKm;
      }
    }

    // 2. Traversed Graph Road Segments
    for (final edge in pathEdges) {
      if (!waypoints.contains(edge.startPoint)) waypoints.add(edge.startPoint);
      waypoints.add(edge.endPoint);

      final assessment = _hazardService.assessSegmentRisk(
        edge.startPoint,
        edge.endPoint,
        disasterType,
        activeHazards: hazards,
      );

      final isEdgeBlocked = edge.initiallyBlocked || assessment.isBlocked;
      if (isEdgeBlocked) hasBlocked = true;

      RouteRiskLevel segRisk = isEdgeBlocked
          ? RouteRiskLevel.blocked
          : assessment.isDirectlyHit
              ? RouteRiskLevel.high
              : assessment.isBufferZone
                  ? RouteRiskLevel.moderate
                  : RouteRiskLevel.low;

      if (assessment.riskMultiplier > maxMultiplier) {
        maxMultiplier = assessment.riskMultiplier;
      }

      if (assessment.primaryHazard != null &&
          !hazardReasons.contains(assessment.primaryHazard!.title)) {
        hazardReasons.add(assessment.primaryHazard!.title);
      }

      segments.add(RoadSegment(
        id: edge.id,
        start: edge.startPoint,
        end: edge.endPoint,
        roadName: edge.roadName,
        distanceKm: edge.distanceKm,
        isBlocked: isEdgeBlocked,
        riskLevel: segRisk,
        hazardNotes: assessment.explanation,
        turnInstruction: edge.turnInstruction,
      ));

      totalKm += edge.distanceKm;
    }

    // 3. Final Egress Leg (Last graph road node to destination shelter)
    if (pathEdges.isNotEmpty) {
      final double endLegKm = pathEdges.last.endPoint.distanceTo(shelterLocation);
      if (endLegKm > 0.02) {
        final endAssessment = _hazardService.assessSegmentRisk(
          pathEdges.last.endPoint,
          shelterLocation,
          disasterType,
          activeHazards: hazards,
        );
        final isEndBlocked = endAssessment.isBlocked;
        if (isEndBlocked) hasBlocked = true;
        final endRisk = isEndBlocked
            ? RouteRiskLevel.blocked
            : (endAssessment.isDirectlyHit
                ? RouteRiskLevel.high
                : (endAssessment.isBufferZone ? RouteRiskLevel.moderate : RouteRiskLevel.low));

        if (endAssessment.riskMultiplier > maxMultiplier) {
          maxMultiplier = endAssessment.riskMultiplier;
        }

        segments.add(RoadSegment(
          id: 'egress_${pathEdges.last.targetNodeId}_${shelterLocation.lat}',
          start: pathEdges.last.endPoint,
          end: shelterLocation,
          roadName: 'Access to ${shelterLocation.name ?? "Shelter"}',
          distanceKm: double.parse(endLegKm.toStringAsFixed(2)),
          isBlocked: isEndBlocked,
          riskLevel: endRisk,
          hazardNotes: endAssessment.explanation,
          turnInstruction: 'Turn into entrance of ${shelterLocation.name ?? "Destination Shelter"}',
        ));
        totalKm += endLegKm;
      }
    }

    if (!waypoints.contains(shelterLocation)) waypoints.add(shelterLocation);

    final travelMinutes = ((totalKm / 25.0) * 60).round().clamp(2, 600);

    double riskScore = 15.0;
    RouteRiskLevel overallRisk = RouteRiskLevel.low;

    if (hasBlocked) {
      riskScore = 95.0;
      overallRisk = RouteRiskLevel.blocked;
    } else if (maxMultiplier >= 5.0) {
      riskScore = 75.0;
      overallRisk = RouteRiskLevel.high;
    } else if (maxMultiplier >= 2.0) {
      riskScore = 42.0;
      overallRisk = RouteRiskLevel.moderate;
    }

    String explanation = customExplanation ??
        (hasBlocked
            ? 'Route traverses impassable roads (${hazardReasons.join(', ')}). High danger of vehicular submersion.'
            : 'Evacuation route evaluated clear of active hazards via elevated corridors.');

    return EvacuationRoute(
      id: id,
      name: name,
      destinationShelterId: shelterLocation.name ?? 'shelter',
      destinationShelterName: shelterLocation.name ?? 'Destination Shelter',
      waypoints: waypoints,
      segments: segments,
      totalDistanceKm: double.parse(totalKm.toStringAsFixed(2)),
      estimatedMinutes: travelMinutes,
      riskLevel: overallRisk,
      verificationState: hasBlocked
          ? RouteVerificationState.noVerifiedRoute
          : RouteVerificationState.routeAvailable,
      riskScore: riskScore,
      riskExplanation: explanation,
      isRecommended: isRecommended && !hasBlocked,
      hasBlockedRoads: hasBlocked,
      elevationProfile: elevationProfile,
      disclaimer: 'Demonstration route calculated from local demo network. Real-world conditions require on-ground NDRF/SDRF confirmation. Absence of reported hazards does not guarantee road safety.',
      isDemo: true,
    );
  }

  bool _areEdgeListsIdentical(List<_GraphEdge> a, List<_GraphEdge> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  ({String id, GeoPoint location})? _findClosestNode(GeoPoint point, Map<String, List<_GraphEdge>> graph) {
    if (graph.isEmpty) return null;
    String? closest;
    GeoPoint? closestLoc;
    double minDistance = double.infinity;

    for (final entry in graph.entries) {
      if (entry.value.isEmpty) continue;
      final nodeLoc = entry.value.first.startPoint;
      final dist = point.distanceTo(nodeLoc);
      if (dist < minDistance) {
        minDistance = dist;
        closest = entry.key;
        closestLoc = nodeLoc;
      }
    }

    if (closest == null || closestLoc == null) return null;
    return (id: closest, location: closestLoc);
  }

  Future<Map<String, List<_GraphEdge>>> _getOrBuildRoadGraph() async {
    if (_cachedGraph != null && _cachedGraph!.isNotEmpty) {
      return _cachedGraph!;
    }

    try {
      final jsonString = await rootBundle.loadString('assets/data/roads.json');
      final dynamic decoded = jsonDecode(jsonString);
      final List<dynamic> list = decoded is List ? decoded : (decoded['roads'] ?? []);

      if (list.isNotEmpty) {
        final Map<String, List<_GraphEdge>> graph = {};
        for (final item in list) {
          final map = item as Map<String, dynamic>;
          final start = GeoPoint.fromJson(map['start'] as Map<String, dynamic>);
          final end = GeoPoint.fromJson(map['end'] as Map<String, dynamic>);
          final u = start.name ?? 'Node_${start.lat}_${start.lng}';
          final v = end.name ?? 'Node_${end.lat}_${end.lng}';
          final dist = (map['distance_km'] ?? map['distance'] as num?)?.toDouble() ?? start.distanceTo(end);
          final roadName = map['road_name']?.toString() ?? 'Connecting Road';
          final blocked = map['status'] == 'blocked' || map['is_blocked'] == true;
          final turn = map['turn_instruction']?.toString() ?? 'Proceed onto $roadName';

          graph.putIfAbsent(u, () => []).add(_GraphEdge(
                id: map['id']?.toString() ?? 'R_${u}_$v',
                sourceNodeId: u,
                targetNodeId: v,
                roadName: roadName,
                distanceKm: dist,
                startPoint: start,
                endPoint: end,
                initiallyBlocked: blocked,
                turnInstruction: turn,
              ));
          graph.putIfAbsent(v, () => []).add(_GraphEdge(
                id: '${map['id']}_rev',
                sourceNodeId: v,
                targetNodeId: u,
                roadName: roadName,
                distanceKm: dist,
                startPoint: end,
                endPoint: start,
                initiallyBlocked: blocked,
                turnInstruction: 'Head towards $u via $roadName',
              ));
        }
        _cachedGraph = graph;
        return graph;
      }
    } catch (_) {
      // Fallback to high-precision built-in network
    }

    _cachedGraph = _demoRoadGraph;
    return _demoRoadGraph;
  }

  static final Map<String, List<_GraphEdge>> _demoRoadGraph = () {
    final Map<String, List<_GraphEdge>> graph = {};

    const nBenz = GeoPoint(16.5062, 80.6480, name: 'Benz Circle');
    const nMGJunction = GeoPoint(16.5085, 80.6420, name: 'MG Road Junction');
    const nCanalRoad = GeoPoint(16.5020, 80.6350, name: 'Bandar Canal Road');
    const nGovPet = GeoPoint(16.5140, 80.6280, name: 'Governorpet Center');
    const nShelterA = GeoPoint(16.5180, 80.6200, name: 'ZP High School Shelter');
    const nWestBypass1 = GeoPoint(16.5150, 80.6550, name: 'Ring Road East');
    const nWestBypass2 = GeoPoint(16.5280, 80.6450, name: 'Gunadala Junction');
    const nWestBypass3 = GeoPoint(16.5250, 80.6300, name: 'North Elevated Corridor');
    const nHighRidge = GeoPoint(16.5300, 80.6600, name: 'High Ridge Perimeter');
    const nNorthRidge = GeoPoint(16.5350, 80.6380, name: 'North Ridge Flyover');
    const nBesant = GeoPoint(16.5110, 80.6350, name: 'Besant Commercial Corridor');
    const nGovOverpass = GeoPoint(16.5160, 80.6250, name: 'Governorpet High Overpass');

    void addRoad({
      required String id,
      required String fromName,
      required String toName,
      required GeoPoint start,
      required GeoPoint end,
      required String name,
      required double km,
      required String turn,
      bool blocked = false,
      String elevation = 'Normal Ground',
    }) {
      graph.putIfAbsent(fromName, () => []).add(_GraphEdge(
            id: id,
            sourceNodeId: fromName,
            targetNodeId: toName,
            roadName: name,
            distanceKm: km,
            startPoint: start,
            endPoint: end,
            initiallyBlocked: blocked,
            turnInstruction: turn,
            elevationCategory: elevation,
          ));
      graph.putIfAbsent(toName, () => []).add(_GraphEdge(
            id: '${id}_rev',
            sourceNodeId: toName,
            targetNodeId: fromName,
            roadName: name,
            distanceKm: km,
            startPoint: end,
            endPoint: start,
            initiallyBlocked: blocked,
            turnInstruction: 'Head towards $fromName via $name',
            elevationCategory: elevation,
          ));
    }

    // Direct Canal Road Corridor (Shortest Direct Route - Submerged Canal Road)
    addRoad(
      id: 'R101',
      fromName: 'Benz Circle',
      toName: 'MG Road Junction',
      start: nBenz,
      end: nMGJunction,
      name: 'MG Road Expressway',
      km: 0.8,
      turn: 'Head West on MG Road towards Center',
    );
    addRoad(
      id: 'R102',
      fromName: 'MG Road Junction',
      toName: 'Bandar Canal Road',
      start: nMGJunction,
      end: nCanalRoad,
      name: 'Canal South Link Road',
      km: 1.1,
      turn: 'Turn Left onto Canal South Link',
    );
    addRoad(
      id: 'R103',
      fromName: 'Bandar Canal Road',
      toName: 'Governorpet Center',
      start: nCanalRoad,
      end: nGovPet,
      name: 'Old Canal Road',
      km: 1.4,
      turn: 'Proceed along Old Canal Road (SIMULATED FLOOD)',
      blocked: true,
      elevation: 'Low-Lying Canal Basin',
    );
    addRoad(
      id: 'R105',
      fromName: 'Governorpet Center',
      toName: 'ZP High School Shelter',
      start: nGovPet,
      end: nShelterA,
      name: 'One-Town Access Road',
      km: 0.7,
      turn: 'Turn Right into Shelter Entrance',
    );

    // Elevated Bypass Corridor (Recommended Safe Route)
    addRoad(
      id: 'R201',
      fromName: 'Benz Circle',
      toName: 'Ring Road East',
      start: nBenz,
      end: nWestBypass1,
      name: 'Inner Ring Road Elevated Highway',
      km: 1.5,
      turn: 'Take the ramp up onto Inner Ring Road Elevated Highway',
      elevation: 'Elevated Highway (+8m)',
    );
    addRoad(
      id: 'R202',
      fromName: 'Ring Road East',
      toName: 'Gunadala Junction',
      start: nWestBypass1,
      end: nWestBypass2,
      name: 'Gunadala Bypass',
      km: 1.4,
      turn: 'Continue straight onto Gunadala Bypass',
      elevation: 'High Ground Plateau',
    );
    addRoad(
      id: 'R203',
      fromName: 'Gunadala Junction',
      toName: 'North Elevated Corridor',
      start: nWestBypass2,
      end: nWestBypass3,
      name: 'High-Level Flyover Link',
      km: 1.2,
      turn: 'Bear Left onto High-Level Flyover Link',
      elevation: 'Elevated Flyover (+12m)',
    );
    addRoad(
      id: 'R204',
      fromName: 'North Elevated Corridor',
      toName: 'ZP High School Shelter',
      start: nWestBypass3,
      end: nShelterA,
      name: 'Shelter North Protected Approach',
      km: 1.1,
      turn: 'Descend ramp and arrive at ZP High School Evacuation Shelter',
      elevation: 'High Ground Entrance',
    );

    // High Ridge Detour Corridor (Alternative Clear Route)
    addRoad(
      id: 'R301',
      fromName: 'Ring Road East',
      toName: 'High Ridge Perimeter',
      start: nWestBypass1,
      end: nHighRidge,
      name: 'Eastern Ridge Highway',
      km: 2.2,
      turn: 'Take the Eastern Ridge Highway towards High Ridge',
      elevation: 'Hillside Ridge (+20m)',
    );
    addRoad(
      id: 'R302',
      fromName: 'High Ridge Perimeter',
      toName: 'North Ridge Flyover',
      start: nHighRidge,
      end: nNorthRidge,
      name: 'North Ridge Mountain Pass',
      km: 1.8,
      turn: 'Follow North Ridge Mountain Pass around flood perimeter',
      elevation: 'Mountain Ridge (+25m)',
    );
    addRoad(
      id: 'R303',
      fromName: 'North Ridge Flyover',
      toName: 'ZP High School Shelter',
      start: nNorthRidge,
      end: nShelterA,
      name: 'Northern Ridge Descent Road',
      km: 1.3,
      turn: 'Descend into ZP High School Evacuation Shelter entrance',
      elevation: 'Descent Corridor',
    );

    // Commercial Arterial Corridor (Moderate Caution)
    addRoad(
      id: 'R401',
      fromName: 'MG Road Junction',
      toName: 'Besant Commercial Corridor',
      start: nMGJunction,
      end: nBesant,
      name: 'Besant Road Commercial Link',
      km: 1.2,
      turn: 'Turn Northwest onto Besant Commercial Link',
      elevation: 'Commercial Basin',
    );
    addRoad(
      id: 'R402',
      fromName: 'Besant Commercial Corridor',
      toName: 'Governorpet High Overpass',
      start: nBesant,
      end: nGovOverpass,
      name: 'Governorpet Elevated Bridge',
      km: 1.4,
      turn: 'Ascend Governorpet Elevated Bridge to clear drainage basin',
      elevation: 'Bridge Overpass (+6m)',
    );
    addRoad(
      id: 'R403',
      fromName: 'Governorpet High Overpass',
      toName: 'ZP High School Shelter',
      start: nGovOverpass,
      end: nShelterA,
      name: 'North Avenue Access Link',
      km: 1.2,
      turn: 'Turn Right onto North Avenue towards Shelter Gate',
      elevation: 'Normal Street Level',
    );

    return graph;
  }();
}
