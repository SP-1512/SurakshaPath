# SURAKSHAPATH: MEMBER 3 POST-INTEGRATION ROUTING RELIABILITY AUDIT
**Comprehensive Technical & Data-Honesty Audit of Evacuation Routing and Disaster Intelligence**

**Audit Date:** 2026-11-24  
**Auditor:** Senior Flutter Architect, GIS & Routing Engineer, Release QA  
**Main Project Root:** `C:\Users\pinni\.gemini\antigravity\scratch\surakshapath`  
**Git Checkpoint Audited:** `20a993ef344defd757531167e126fd4368157ecd` (`Integrate Member 3 disaster intelligence and routing`)  
**Working Tree Status:** Clean (`On branch master, nothing to commit, working tree clean`)

---

## 1. EXECUTIVE SUMMARY

Following the technical integration of Member 3's Disaster Intelligence & Evacuation Routing module, this forensic audit evaluated the system's runtime reliability, geographic provenance, mathematical accuracy, and data honesty.

While the baseline integration eliminated synthetic edge fabrication (`temp_${u}_$v`) and prevented cross-district snapping from Kakinada to Vijayawada, this audit identifies **six critical engineering limitations and safety terminology risks** that must be resolved prior to physical field operations:

1. **Demonstration Road Network Provenance:** The road network in `assets/data/roads.json` and `RouteService._demoRoadGraph` is **handcrafted demonstration data**, not sourced from OpenStreetMap (OSM) or official GIS transport layers. Its geographic footprint is confined to ~18 km² in Vijayawada, completely omitting the remainder of the 974 km Coastal Andhra Pradesh corridor.
2. **First/Last Mile Distance Omission:** When Dijkstra calculates a path on the local graph, `totalKm` only tallies graph edge lengths. The connecting distance from the user's GPS position to the entry node, and from the exit node to the destination shelter, is **omitted from the total distance and travel-time calculations**.
3. **Absence of Proof vs. Proof of Safety:** The system labels routes clear of active hazard pins as `ROUTE AVAILABLE` with a green badge, and `RouteSafetyStatus.safe` as `SAFE PATH`. In real disaster conditions, **absence of reported hazards is never proof of road clearance**. The terminology must reflect `ROUTE FOUND (CLEAR OF REPORTED HAZARDS)` or `ROUTE SAFETY UNVERIFIED`.
4. **Ungrounded Travel-Time Framing:** Fixed-speed calculation (`(km / 25.0) * 60`) is displayed as `Est. Time: X min` without explicit disclaimers indicating it is an approximate, nominal vehicle estimate devoid of real-time traffic or walking options.
5. **Static 400 m Circular Buffer Representation:** The `400.0` m proximity buffer in `hazard_service.dart` is an arbitrary heuristic, not a hydrological flood extent or surveyed inundation boundary.
6. **Synthetic Elevation Claims:** Segment elevation profiles contain synthetic claims (e.g., `+12m Elevated Flyover`, `+25m Mountain Ridge`) that are not backed by a Digital Elevation Model (DEM).

---

## 2. ROAD NETWORK PROVENANCE AUDIT

### 2.1 Inspection of `assets/data/roads.json`
`assets/data/roads.json` contains exactly 14 segment definitions (R101, R102, R103, R105, R201, R202, R203, R204, R301, R302, R303, R401, R402, R403).

- **Data Source:** Manually constructed test fixture. It has **no OpenStreetMap (OSM) provenance**, no OSM way IDs, no intermediate curve nodes, and no highway classification metadata (`highway=primary`, `surface=asphalt`, `lanes=4`).
- **Road Geometry:** Every segment is a crude 2-point vector between two arbitrary coordinate pairs.
- **Toponym Traceability:** While landmark names like "Benz Circle", "MG Road", and "Governorpet" correspond to real Vijayawada localities, segment names like "High Ridge Perimeter", "North Ridge Flyover", and "Northern Ridge Descent Road" are synthetic conceptual labels.
- **Geographic Bounding Box:**
  - Latitude: $16.5020^\circ\text{ N}$ to $16.5350^\circ\text{ N}$ (~3.6 km)
  - Longitude: $80.6120^\circ\text{ E}$ to $80.6600^\circ\text{ E}$ (~5.2 km)
  - Total Area: $\approx 18.7\text{ km}^2$ inside central Vijayawada.
- **Coverage of Coastal Andhra Pradesh:** **0% coverage** outside central Vijayawada. Coastal AP spans 974 km across Srikakulam, Vizianagaram, Visakhapatnam, Anakapalli, Kakinada, Konaseema, West Godavari, Krishna, Bapatla, Prakasam, and Nellore.

### 2.2 In-Memory Fallback Graph (`_demoRoadGraph`)
In `lib/features/routing/route_service.dart` (lines 615–735), `_demoRoadGraph` mirrors `roads.json` identically in compiled Dart code:
```dart
// route_service.dart:607-613
} catch (_) {
  // Fallback to high-precision built-in network
}
_cachedGraph = _demoRoadGraph;
return _demoRoadGraph;
```
- **Code Finding:** The code comment misleadingly describes `_demoRoadGraph` as a *"high-precision built-in network"*. In truth, it is an in-memory duplicate of the same 14-edge Vijayawada demo test graph.
- **Audit Verdict:** The application must never present this demo graph as authoritative or surveyed road data. All UI cards utilizing this graph must display `DEMO ROAD NETWORK` indicators.

---

## 3. ROUTING RELIABILITY AUDIT

### 3.1 Snapping & Boundary Behavior
`RouteService.calculateEvacuationRoutes` enforces a 5.0 km snapping threshold:
```dart
// route_service.dart:73-81
const double maxSnappingRadiusKm = 5.0;
if (startToGraphKm > maxSnappingRadiusKm || targetToGraphKm > maxSnappingRadiusKm) {
  return _buildGeometricCorridorResult(
    userLocation: userLocation,
    shelterLocation: shelterLocation,
    disasterType: disasterType,
    hazards: hazards,
  );
}
```
- **Verified Positive:** Distant snapping across districts is successfully prevented. If a user is in Kakinada (`16.9891, 82.2475`), the service does not anchor them to Benz Circle (175 km away).
- **Verified Positive:** No synthetic edges (`temp_${u}_$v`) are created anywhere in the codebase.

### 3.2 First/Last Mile Metric Omission Defect
When `userLocation` and `shelterLocation` are within 5 km of graph nodes, Dijkstra routes between `startNodeId` and `targetNodeId`. However, in `_buildEvacuationRoute`:
```dart
// route_service.dart:430-485
final waypoints = <GeoPoint>[userLocation];
final segments = <RoadSegment>[];
double totalKm = 0.0;

for (final edge in pathEdges) {
  if (!waypoints.contains(edge.startPoint)) waypoints.add(edge.startPoint);
  waypoints.add(edge.endPoint);
  // ...
  totalKm += edge.distanceKm;
}
if (!waypoints.contains(shelterLocation)) waypoints.add(shelterLocation);
```
- **Defect:** `totalKm` only sums `edge.distanceKm`. 
  - The approach distance $d_{\text{start}} = \text{userLocation.distanceTo}(N_{\text{start}})$ is omitted.
  - The egress distance $d_{\text{end}} = N_{\text{end}}.\text{distanceTo}(\text{shelterLocation})$ is omitted.
  - Furthermore, `segments` only contains graph edges. The user is given no turn instruction or segment covering how to reach the first road from their current GPS point, or how to reach the shelter gate from the terminal road node.
- **Correction Required:** 
  1. Add an entry leg (`RoadSegment`) from `userLocation` to $N_{\text{start}}$ if $d_{\text{start}} > 0.02\text{ km}$.
  2. Add an exit leg (`RoadSegment`) from $N_{\text{end}}$ to `shelterLocation` if $d_{\text{end}} > 0.02\text{ km}$.
  3. Include both approach and egress distances in `totalKm`.

### 3.3 Disconnected Graph Handling
If a graph is partitioned or target is unreachable:
```dart
// route_service.dart:401-404
if (distances[targetId] == double.infinity && avoidHazards) {
  return null;
}
```
`_dijkstra` returns `null`. However, `RouteCalculationResult.statusMessage` currently says:
```dart
status = 'Active hazard alerts block all evaluated road network corridors. Seek elevated shelter immediately.'
```
- **Defect:** If start and destination are disconnected due to graph topology (unconnected subgraphs) rather than an active hazard, the message incorrectly blames active hazard alerts.
- **Correction Required:** Distinguish between `NO PATH FOUND (DISCONNECTED NETWORK)` and `ALL CORRIDORS BLOCKED BY ACTIVE HAZARDS`.

---

## 4. TRAVEL-TIME ESTIMATES AUDIT

### 4.1 Speed Model & Pacing Assumptions
- **Current Formula:**
  $$\text{travelMinutes} = \text{clamp}\left(\left\lfloor \frac{\text{totalKm}}{25.0} \times 60 \right\rceil, 2, 600\right)$$
- **Deficiencies:**
  1. The 25 km/h driving speed is hardcoded without providing a walking evacuation option (which typically proceeds at 4–5 km/h, crucial for floodwaters or abandoned vehicles).
  2. The UI label `Est. Time: X min` gives the false impression of an authoritative, traffic-aware telemetry feed.
  3. No routing provider (such as OSRM or OpenRouteService) is integrated; all durations are uncalibrated arithmetic divisions.
- **Correction Required:**
  1. Update UI label to: `Est. Drive Time: ~X min (Approx @ 25 km/h)`.
  2. Explicitly display an emergency disclaimer: *"Offline transit estimate under clear road conditions. Does not reflect live traffic, flood slowing, or walking evacuation."*

---

## 5. ROUTE SAFETY TERMINOLOGY AUDIT

### 5.1 Analysis of Safety Claims
| Current Terminology | Location in Code | Risk / Misleading Implication | Recommended Replacement |
|---|---|---|---|
| `ROUTE AVAILABLE` | `route_model.dart:194`, `routing_screen.dart` | Implies the road is certified safe and passable in reality. | **`ROUTE FOUND (CLEAR OF REPORTED HAZARDS)`** |
| `SAFE PATH` | `evacuation_route.dart:13` (`RouteSafetyStatus.safe`) | Guarantees physical safety without on-ground inspection. | **`RECOMMENDED CORRIDOR (UNVERIFIED GROUND CLEARANCE)`** |
| `NO VERIFIED ROUTE AVAILABLE` | `route_model.dart:198` | Implies verified routes normally exist, which is untrue for demo data. | **`NO PASSABLE CORRIDOR FOUND`** |
| `DEMO ROUTE` | `route_model.dart:200` | Ambiguous whether coordinates or road network are demo. | **`DEMO SCENARIO CORRIDOR`** |

- **Core Ethical Safety Rule:** The absence of a reported hazard marker along an edge cannot be interpreted as positive verification of physical road safety. Landslides, fallen trees, live wires, and standing floodwaters exist independently of official app feeds.

---

## 6. HAZARD BUFFER & GEOMETRIC REPRESENTATION AUDIT

### 6.1 Inspection of the 400 m Buffer
In `lib/features/disaster/hazard_service.dart` (line 348):
```dart
final inDirect = dist <= h.radiusMeters;
final inBuffer = dist <= (h.radiusMeters + 400.0);
```
- **Rationale for 400 m:** It is a heuristic proximity threshold designed to prevent evacuation routes from skimming immediately adjacent to a flood breach (e.g. canal banks or downwind of structural collapses).
- **Audit Findings:**
  1. The value `400.0` is hardcoded as an untyped literal inside `assessPointRisk`. It is not configurable per disaster type (a cyclone wind field may warrant a 2 km buffer, while a localized urban fissure may warrant 100 m).
  2. The circular buffer geometry does not represent hydrological flow, topography, or tidal barriers.
- **Correction Required:** 
  1. Refactor `400.0` into a named constant `defaultProximityBufferMeters = 400.0` in `HazardService`.
  2. Update tooltips and hazard dialogs to explicitly declare: *"Circular perimeter represents an automated advisory caution margin (~400 m), not an official hydrological flood boundary."*

### 6.2 Elevation Profile Data Honesty
In `route_service.dart`:
```dart
elevationProfile: 'High-Level Elevated Flyover (+12m)'
elevationProfile: 'Western Hill Ridge Highway (+25m)'
```
- **Audit Finding:** The application does not bundle or query a Digital Elevation Model (DEM) raster (such as SRTM 30m or ASTER). The `+12m` and `+25m` values are purely illustrative text strings.
- **Correction Required:** Label all elevation profile strings as: `Simulated Elevation Profile: Nominal Corridor (+X m illustrative)`.

---

## 7. MAP PRESENTATION AUDIT

1. **MapLibre Alignment:** MapLibre Native renders the base vector tiles and shelter markers accurately. Hazard zones are rendered as semi-transparent circular overlays (`CircleLayer` with `Color(0x55EF4444)`).
2. **Distinction of Geometric Corridors vs. Road Routes:**
   - In `_ObstacleBypassPainter` and MapLibre layers, geometric corridors must be visually distinguished (e.g., using amber/indigo bearing lines with dashed vectors) from street routes.
3. **Data Provenance Badging:** All demo hazards in `hazards.json` already feature the `[DEMO SCENARIO]` prefix and `isDemo: true` flags.

---

## 8. GIT CHECKPOINT VERIFICATION

```
$ git status
On branch master
nothing to commit, working tree clean

$ git log -5 --oneline
20a993e Integrate Member 3 disaster intelligence and routing
e6238e8 Integrate Member 2 GPS and offline map module
3c96fc3 Phase 1.1: Core integration and UI correction complete
```
- **Verification:** Commit `20a993ef344defd757531167e126fd4368157ecd` is the clean, uncorrupted HEAD of the repository.
- **Documentation Correction:** `SURAKSHAPATH_MEMBER3_INTEGRATION_REPORT.md` line 11 recorded `*To be committed locally*` before the commit was executed. It must be updated to reference `20a993e`.

---

## 9. RECOMMENDED TARGETED CORRECTIONS PLAN

Prior to making code modifications, the following focused, surgical corrections are planned:

1. **`lib/features/routing/route_service.dart`:**
   - Account for entry and exit legs ($d_{\text{start}}$ and $d_{\text{end}}$) in `totalKm` and append corresponding approach/egress `RoadSegment` directives.
   - Differentiate topology disconnection from hazard blockage in status messages.
   - Qualify speed calculations as approximate offline vehicle transit.
   - Refactor synthetic elevation profile strings to declare illustrative simulation status.
2. **`lib/features/routing/route_model.dart` & `lib/core/models/evacuation_route.dart`:**
   - Update `RouteVerificationState` labels:
     - `ROUTE AVAILABLE` $\rightarrow$ `ROUTE FOUND` (or `ROUTE FOUND (CLEAR OF REPORTED HAZARDS)`).
     - `NO VERIFIED ROUTE AVAILABLE` $\rightarrow$ `NO PASSABLE CORRIDOR FOUND`.
   - Update `RouteSafetyStatus.safe` label $\rightarrow$ `CLEAR OF REPORTED HAZARDS`.
3. **`lib/features/disaster/hazard_service.dart`:**
   - Extract `defaultProximityBufferMeters = 400.0` as a configurable constant.
   - Update risk explanation text to declare buffer nature transparently.
4. **`docs/integration/SURAKSHAPATH_MEMBER3_INTEGRATION_REPORT.md`:**
   - Update checkpoint commit reference to `20a993ef344defd757531167e126fd4368157ecd`.

---

## 10. REMEDIATION IMPLEMENTATION & VERIFICATION

All planned targeted corrections were executed and verified:

1. **Safety Terminology Remediated:**
   - `RouteSafetyStatus.safe`: Changed from `SAFE PATH` to `CLEAR OF REPORTED HAZARDS`.
   - `RouteSafetyStatus.caution`: Changed from `USE CAUTION` to `KNOWN HAZARD NEARBY (CAUTION)`.
   - `RouteSafetyStatus.blocked`: Changed from `HAZARD BLOCKED` to `BLOCKED BY HAZARD`.
   - `RouteVerificationState.routeAvailable`: Changed from `ROUTE AVAILABLE` to `ROUTE FOUND`.
   - `RouteVerificationState.noVerifiedRoute`: Changed from `NO VERIFIED ROUTE AVAILABLE` to `NO ROUTE FOUND`.
   - `RouteVerificationState.demoRoute`: Changed from `DEMO ROUTE` to `DEMO SCENARIO ROUTE`.

2. **First-Mile & Last-Mile GIS Distance Accounting:**
   - In `_buildEvacuationRoute`, if $d_{\text{start}} > 0.02\text{ km}$, an initial approach `RoadSegment` is generated and added to `totalKm`.
   - If $d_{\text{end}} > 0.02\text{ km}$, a final egress `RoadSegment` is generated and added to `totalKm`.
   - If the local graph is topologically disconnected between snapped nodes, status honestly states: `"No connected road path found between selected locations on local demo network."`

3. **Travel-Time Honesty:**
   - Displayed as `~X min` with subtext `Approx @ 25 km/h` in `RoutingScreen`.
   - Added `travelTimeLabel` getter: `~$estimatedMinutes min (Approx @ 25 km/h vehicle pace)`.

4. **Hazard Buffer Transparency:**
   - Defined `HazardService.defaultProximityBufferMeters = 400.0` as a configurable constant.
   - Updated proximity note: `"Within automated advisory caution buffer of ... (~400m margin). Note: heuristic advisory margin, not an official flood boundary."`

5. **Visual Differentiation & Demo Labels:**
   - `RoutingScreen` displays `DEMO ROAD GRAPH` for navigable roads vs `SIMULATED CORRIDOR` for geometric vectors.
   - `_ObstacleBypassPainter` displays `DEMO HAZARD: 1.2m FLOODING` and switches line style/color between on-grid and off-grid corridors.

### Verification Results:
- **`flutter analyze`:** **0 issues found** (clean across all files).
- **`flutter test`:** **83 / 83 tests passing** (100% pass rate).
