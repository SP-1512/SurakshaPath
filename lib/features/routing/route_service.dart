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
  final List<GeoPoint> intermediateCoords;
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
    this.intermediateCoords = const [],
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
    // do NOT draw a fake straight-line across the region.
    // Instead, fail safely with an honest status indicating no verified road route exists.
    const double maxSnappingRadiusKm = 5.0;
    if (startToGraphKm > maxSnappingRadiusKm || targetToGraphKm > maxSnappingRadiusKm) {
      final double totalDist = userLocation.distanceTo(shelterLocation);
      final String reason = startToGraphKm > maxSnappingRadiusKm
          ? 'Your location is outside verified road graph coverage (${startToGraphKm.toStringAsFixed(1)} km to closest road node).'
          : 'Destination shelter is in an unmapped or distant region (${targetToGraphKm.toStringAsFixed(1)} km from mapped road network, total straight-line distance ${totalDist.toStringAsFixed(1)} km).';

      return RouteCalculationResult(
        recommendedRoute: null,
        alternativeRoute: null,
        allRoutes: const [],
        startPoint: userLocation,
        destinationShelter: shelterLocation,
        disasterType: disasterType,
        statusMessage: 'No verified road route available: $reason Please select a safe shelter within your immediate municipal district.',
        state: RouteVerificationState.noVerifiedRoute,
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
      final edgesToPenalize = safePathEdges.length > 1
          ? {safePathEdges[1].id}
          : {safePathEdges.first.id};
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
    final RouteVerificationState state = calculatedRoutes.isNotEmpty
        ? (hasSafe ? RouteVerificationState.routeAvailable : RouteVerificationState.noVerifiedRoute)
        : RouteVerificationState.noVerifiedRoute;

    final String status = hasSafe
        ? '${calculatedRoutes.length} road-network evacuation corridor(s) calculated. Primary route clear of reported hazards.'
        : (calculatedRoutes.isNotEmpty
            ? 'Active hazard alerts block all evaluated road network corridors. Seek elevated shelter immediately.'
            : 'No verified road route available: No connected road network connects your location (${userLocation.name ?? "Origin"}) to ${shelterLocation.name ?? "Destination"}. Please select an accessible shelter within your district.');

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

        if (penalizedEdgeIds.contains(edge.id)) {
          edgeCost += 50.0; // Penalty to force alternative path discovery
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

    // 2. Traversed Graph Road Segments with genuine intermediate road curvature
    for (final edge in pathEdges) {
      if (!waypoints.contains(edge.startPoint)) waypoints.add(edge.startPoint);
      for (final inter in edge.intermediateCoords) {
        if (!waypoints.contains(inter)) waypoints.add(inter);
      }
      if (!waypoints.contains(edge.endPoint)) waypoints.add(edge.endPoint);

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
        intermediateCoordinates: edge.intermediateCoords,
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

          final rawInter = (map['intermediate_coords'] as List<dynamic>?)
                  ?.map((e) => GeoPoint.fromJson(e as Map<String, dynamic>))
                  .toList() ??
              const <GeoPoint>[];

          graph.putIfAbsent(u, () => []).add(_GraphEdge(
                id: map['id']?.toString() ?? 'R_${u}_$v',
                sourceNodeId: u,
                targetNodeId: v,
                roadName: roadName,
                distanceKm: dist,
                startPoint: start,
                endPoint: end,
                intermediateCoords: rawInter,
                initiallyBlocked: blocked,
                turnInstruction: turn,
                elevationCategory: map['elevation']?.toString() ?? 'Normal Ground',
              ));
          graph.putIfAbsent(v, () => []).add(_GraphEdge(
                id: '${map['id']}_rev',
                sourceNodeId: v,
                targetNodeId: u,
                roadName: roadName,
                distanceKm: dist,
                startPoint: end,
                endPoint: start,
                intermediateCoords: rawInter.reversed.toList(),
                initiallyBlocked: blocked,
                turnInstruction: 'Head towards $u via $roadName',
                elevationCategory: map['elevation']?.toString() ?? 'Normal Ground',
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

    // ── KAKINADA COASTAL SECTOR NODES ──────────────────────────────────────
    const nKSurya = GeoPoint(16.9891, 82.2475, name: 'Suryaraopeta Junction');
    const nKSubhash = GeoPoint(16.9785, 82.2445, name: 'Subhash Road Junction');
    const nKCausewayNorth = GeoPoint(16.9710, 82.2415, name: 'Jagannaickpur Bridge North');
    const nKPortRing = GeoPoint(16.9810, 82.2515, name: 'Port Ring Road Junction');
    const nKPortSouth = GeoPoint(16.9690, 82.2490, name: 'Port South Interchange');
    const nKCinema = GeoPoint(16.9740, 82.2380, name: 'Cinema Road Junction');
    const nKShelter = GeoPoint(16.9604, 82.2382, name: 'Kakinada MPCS Gate');

    // ── VIJAYAWADA URBAN/RIVER SECTOR NODES ────────────────────────────────
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
    const nBhavaniShelter = GeoPoint(16.5180, 80.5980, name: 'Bhavani Island Community Center');

    void addRoad({
      required String id,
      required String fromName,
      required String toName,
      required GeoPoint start,
      required GeoPoint end,
      List<GeoPoint> intermediate = const [],
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
            intermediateCoords: intermediate,
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
            intermediateCoords: intermediate.reversed.toList(),
            initiallyBlocked: blocked,
            turnInstruction: 'Head towards $fromName via $name',
            elevationCategory: elevation,
          ));
    }

    // ── KAKINADA COASTAL SECTOR ROADS ──────────────────────────────────────
    addRoad(
      id: 'K101',
      fromName: 'Suryaraopeta Junction',
      toName: 'Subhash Road Junction',
      start: nKSurya,
      end: nKSubhash,
      intermediate: const [
        GeoPoint(16.9865, 82.2468),
        GeoPoint(16.9838, 82.2459),
        GeoPoint(16.9810, 82.2451),
      ],
      name: 'Suryaraopeta Main Road',
      km: 1.25,
      turn: 'Head South on Suryaraopeta Main Road',
    );
    addRoad(
      id: 'K102',
      fromName: 'Subhash Road Junction',
      toName: 'Jagannaickpur Bridge North',
      start: nKSubhash,
      end: nKCausewayNorth,
      intermediate: const [
        GeoPoint(16.9760, 82.2435),
        GeoPoint(16.9735, 82.2425),
      ],
      name: 'Old Canal Causeway Road',
      km: 0.92,
      turn: 'Proceed along Old Canal Causeway (SIMULATED FLOOD - IMPASSABLE)',
      blocked: true,
      elevation: 'Low-Lying Creek',
    );
    addRoad(
      id: 'K103',
      fromName: 'Subhash Road Junction',
      toName: 'Port Ring Road Junction',
      start: nKSubhash,
      end: nKPortRing,
      intermediate: const [
        GeoPoint(16.9792, 82.2470),
        GeoPoint(16.9802, 82.2495),
      ],
      name: 'Port Elevated Bypass Ramp',
      km: 0.85,
      turn: 'Turn Left onto Port Elevated Bypass Ramp',
      elevation: 'Elevated High Ground',
    );
    addRoad(
      id: 'K104',
      fromName: 'Port Ring Road Junction',
      toName: 'Port South Interchange',
      start: nKPortRing,
      end: nKPortSouth,
      intermediate: const [
        GeoPoint(16.9775, 82.2520),
        GeoPoint(16.9735, 82.2510),
      ],
      name: 'Port Coastal Highway South',
      km: 1.45,
      turn: 'Continue South along Port Coastal Highway',
      elevation: 'Elevated Coastal Ridge',
    );
    addRoad(
      id: 'K105',
      fromName: 'Port South Interchange',
      toName: 'Kakinada MPCS Gate',
      start: nKPortSouth,
      end: nKShelter,
      intermediate: const [
        GeoPoint(16.9665, 82.2460),
        GeoPoint(16.9640, 82.2425),
        GeoPoint(16.9618, 82.2398),
      ],
      name: 'Cyclone Shelter South Access Road',
      km: 1.55,
      turn: 'Turn Right into Kakinada MPCS Shelter Compound',
      elevation: 'Storm-Resistant Elevated Plinth',
    );
    addRoad(
      id: 'K106',
      fromName: 'Subhash Road Junction',
      toName: 'Cinema Road Junction',
      start: nKSubhash,
      end: nKCinema,
      intermediate: const [
        GeoPoint(16.9770, 82.2420),
        GeoPoint(16.9755, 82.2400),
      ],
      name: 'Western Commercial Corridor',
      km: 0.88,
      turn: 'Turn Southwest onto Western Commercial Corridor',
    );
    addRoad(
      id: 'K107',
      fromName: 'Cinema Road Junction',
      toName: 'Kakinada MPCS Gate',
      start: nKCinema,
      end: nKShelter,
      intermediate: const [
        GeoPoint(16.9700, 82.2380),
        GeoPoint(16.9660, 82.2381),
        GeoPoint(16.9625, 82.2382),
      ],
      name: 'Jagannaickpur High Flyover',
      km: 1.62,
      turn: 'Ascend Jagannaickpur High Flyover towards MPCS',
      elevation: 'Elevated Flyover',
    );
    addRoad(
      id: 'K108',
      fromName: 'Jagannaickpur Bridge North',
      toName: 'Cinema Road Junction',
      start: nKCausewayNorth,
      end: nKCinema,
      intermediate: const [
        GeoPoint(16.9725, 82.2395),
      ],
      name: 'Causeway South Connector',
      km: 0.45,
      turn: 'Connect to Cinema Road Junction',
    );

    // ── VIJAYAWADA URBAN/RIVER SECTOR ROADS ────────────────────────────────
    addRoad(
      id: 'R101',
      fromName: 'Benz Circle',
      toName: 'MG Road Junction',
      start: nBenz,
      end: nMGJunction,
      intermediate: const [
        GeoPoint(16.5070, 80.6460),
        GeoPoint(16.5078, 80.6440),
      ],
      name: 'MG Road Expressway',
      km: 0.82,
      turn: 'Head West on MG Road towards Center',
    );
    addRoad(
      id: 'R102',
      fromName: 'MG Road Junction',
      toName: 'Bandar Canal Road',
      start: nMGJunction,
      end: nCanalRoad,
      intermediate: const [
        GeoPoint(16.5065, 80.6395),
        GeoPoint(16.5042, 80.6370),
      ],
      name: 'Canal South Link Road',
      km: 1.12,
      turn: 'Turn Left onto Canal South Link',
      elevation: 'Low-Lying Canal Basin',
    );
    addRoad(
      id: 'R103',
      fromName: 'Bandar Canal Road',
      toName: 'Governorpet Center',
      start: nCanalRoad,
      end: nGovPet,
      intermediate: const [
        GeoPoint(16.5060, 80.6325),
        GeoPoint(16.5100, 80.6300),
      ],
      name: 'Old Canal Road',
      km: 1.45,
      turn: 'Proceed along Old Canal Road (SIMULATED FLOOD)',
      blocked: true,
      elevation: 'Submerged Canal Basin',
    );
    addRoad(
      id: 'R105',
      fromName: 'Governorpet Center',
      toName: 'ZP High School Shelter',
      start: nGovPet,
      end: nShelterA,
      intermediate: const [
        GeoPoint(16.5155, 80.6255),
        GeoPoint(16.5168, 80.6225),
      ],
      name: 'One-Town Access Road',
      km: 0.76,
      turn: 'Turn Right into Shelter Entrance',
    );
    addRoad(
      id: 'R201',
      fromName: 'Benz Circle',
      toName: 'Ring Road East',
      start: nBenz,
      end: nWestBypass1,
      intermediate: const [
        GeoPoint(16.5090, 80.6510),
        GeoPoint(16.5120, 80.6535),
      ],
      name: 'Inner Ring Road Elevated Highway',
      km: 1.54,
      turn: 'Take the ramp up onto Inner Ring Road Elevated Highway',
      elevation: 'Elevated Flyover (+8m)',
    );
    addRoad(
      id: 'R202',
      fromName: 'Ring Road East',
      toName: 'Gunadala Junction',
      start: nWestBypass1,
      end: nWestBypass2,
      intermediate: const [
        GeoPoint(16.5195, 80.6520),
        GeoPoint(16.5240, 80.6485),
      ],
      name: 'Gunadala Bypass',
      km: 1.42,
      turn: 'Continue straight onto Gunadala Bypass',
      elevation: 'High Ground Plateau',
    );
    addRoad(
      id: 'R203',
      fromName: 'Gunadala Junction',
      toName: 'North Elevated Corridor',
      start: nWestBypass2,
      end: nWestBypass3,
      intermediate: const [
        GeoPoint(16.5270, 80.6400),
        GeoPoint(16.5260, 80.6350),
      ],
      name: 'High-Level Flyover Link',
      km: 1.25,
      turn: 'Bear Left onto High-Level Flyover Link',
      elevation: 'Elevated Flyover (+12m)',
    );
    addRoad(
      id: 'R204',
      fromName: 'North Elevated Corridor',
      toName: 'ZP High School Shelter',
      start: nWestBypass3,
      end: nShelterA,
      intermediate: const [
        GeoPoint(16.5230, 80.6265),
        GeoPoint(16.5205, 80.6230),
      ],
      name: 'Shelter North Protected Approach',
      km: 1.15,
      turn: 'Descend ramp and arrive at ZP High School Evacuation Shelter',
      elevation: 'High Ground Entrance',
    );
    addRoad(
      id: 'R301',
      fromName: 'Ring Road East',
      toName: 'High Ridge Perimeter',
      start: nWestBypass1,
      end: nHighRidge,
      intermediate: const [
        GeoPoint(16.5225, 80.6575),
      ],
      name: 'Eastern Ridge Highway',
      km: 2.25,
      turn: 'Take the Eastern Ridge Highway towards High Ridge',
      elevation: 'Hillside Ridge (+20m)',
    );
    addRoad(
      id: 'R302',
      fromName: 'High Ridge Perimeter',
      toName: 'North Ridge Flyover',
      start: nHighRidge,
      end: nNorthRidge,
      intermediate: const [
        GeoPoint(16.5330, 80.6490),
      ],
      name: 'North Ridge Mountain Pass',
      km: 1.85,
      turn: 'Follow North Ridge Mountain Pass around flood perimeter',
      elevation: 'Mountain Ridge (+25m)',
    );
    addRoad(
      id: 'R303',
      fromName: 'North Ridge Flyover',
      toName: 'ZP High School Shelter',
      start: nNorthRidge,
      end: nShelterA,
      intermediate: const [
        GeoPoint(16.5265, 80.6290),
      ],
      name: 'Northern Ridge Descent Road',
      km: 1.35,
      turn: 'Descend into ZP High School Evacuation Shelter entrance',
      elevation: 'Descent Corridor',
    );
    addRoad(
      id: 'R401',
      fromName: 'MG Road Junction',
      toName: 'Besant Commercial Corridor',
      start: nMGJunction,
      end: nBesant,
      intermediate: const [
        GeoPoint(16.5098, 80.6385),
      ],
      name: 'Besant Road Commercial Link',
      km: 1.22,
      turn: 'Turn Northwest onto Besant Commercial Link',
      elevation: 'Commercial Basin',
    );
    addRoad(
      id: 'R402',
      fromName: 'Besant Commercial Corridor',
      toName: 'Governorpet High Overpass',
      start: nBesant,
      end: nGovOverpass,
      intermediate: const [
        GeoPoint(16.5135, 80.6300),
      ],
      name: 'Governorpet Elevated Bridge',
      km: 1.45,
      turn: 'Ascend Governorpet Elevated Bridge to clear drainage basin',
      elevation: 'Bridge Overpass (+6m)',
    );
    addRoad(
      id: 'R403',
      fromName: 'Governorpet High Overpass',
      toName: 'ZP High School Shelter',
      start: nGovOverpass,
      end: nShelterA,
      intermediate: const [
        GeoPoint(16.5170, 80.6225),
      ],
      name: 'North Avenue Access Link',
      km: 1.21,
      turn: 'Turn Right onto North Avenue towards Shelter Gate',
      elevation: 'Normal Street Level',
    );
    addRoad(
      id: 'R501',
      fromName: 'ZP High School Shelter',
      toName: 'Bhavani Island Community Center',
      start: nShelterA,
      end: nBhavaniShelter,
      intermediate: const [
        GeoPoint(16.5175, 80.6130),
        GeoPoint(16.5178, 80.6060),
      ],
      name: 'Krishna River Bund Elevated Corridor',
      km: 2.35,
      turn: 'Follow Krishna River Bund Elevated Corridor to Bhavani Island Center',
      elevation: 'Elevated River Bund',
    );

    return graph;
  }();
}
