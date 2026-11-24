# SURAKSHAPATH: ANDHRA PRADESH STATEWIDE EXPANSION
## PHASE 1A P0 CORRECTIVE PATCH REPORT

**Component:** Phase 1A Routing Engine & Geospatial Proof-of-Concept  
**Owner:** Member 5 (Backend, Data & Alerts)  
**Reviewer:** Member 1 (Project Lead)  
**Project Root:** `C:\Users\pinni\.gemini\antigravity\scratch\surakshapath`  
**Git Baseline Checkpoint:** `381176b8fe8e7ca988dc9cc52a73827510eac601`  
**Patch Date:** November 24, 2026  
**Status:** **COMPLETE & VERIFIED (10/10 PASS)**

---

## 1. EXECUTIVE SUMMARY

In accordance with the findings of `PHASE1A_INDEPENDENT_VERIFICATION_REPORT.md`, this P0 Corrective Patch resolves the critical algorithmic defect in polygon hazard avoidance, introduces defense-in-depth safety validations, adds a comprehensive automated regression suite, and updates all technical documentation to transparently state system architecture and pilot scope.

### Core Corrections Implemented
1. **NetworkX Blocked-Edge Pruning:** Fixed the Dijkstra edge weight function to return `None` (instructing NetworkX that prohibited edges are strictly unavailable) instead of `float("inf")`.
2. **Safety-Critical Pre- and Post-Validations:**
   - Validates that origin and destination coordinates are finite numbers within physical ranges.
   - Rejects origin or destination points situated inside active exclusion polygons with HTTP 442 (*"No route found"*).
   - Validates first-mile and last-mile road snapping access lines against exclusion polygons.
   - Performs post-route geometry verification asserting that no segment of the returned route intersects an active exclusion polygon.
   - Enforces that no route with non-finite or NaN distance or duration can be emitted.
   - Guarantees that HTTP 200 is **never** returned when all paths are obstructed or when a path traverses an exclusion polygon.
3. **Automated Regression Suite (`test_polygon_exclusion_regression.py`):** Added a dedicated 10-scenario regression test verifying single and multiple blocked edges, impassable corridor cuts, river crossing barriers, disconnected nodes, and numerical sanity. All 10 tests pass (100% pass rate).
4. **Architectural Documentation Correction:** Updated `README.md` and `PHASE1A_VALHALLA_POC_REPORT.md` to state the required architectural declaration:  
   *"SurakshaPath currently uses a custom Python routing proof of concept based on NetworkX and Shapely STRtree. It exposes a Valhalla-compatible HTTP JSON API but does not currently run the native Valhalla routing engine."*

---

## 2. EXACT FILES CHANGED

Member 5 modified strictly within assigned boundaries (`backend/routing/` and `docs/integration/`):

| File Path | Action | Scope / Purpose |
|---|---|---|
| `backend/routing/valhalla_poc_service.py` | Modified | Replaced `float("inf")` with `None` in `weight_func`; added pre-routing coordinate and polygon checks, access-line collision checks, post-routing geometry validation, and strict HTTP 442 error handling. |
| `backend/routing/scripts/test_polygon_exclusion_regression.py` | Created | New automated 10-point regression test suite asserting robust polygon exclusion, honest no-route rejection, and finite metrics. |
| `backend/routing/README.md` | Modified | Updated architectural declarations, pilot scope limits, synthetic polygon clarifications, and Python daemon benchmark disclaimers. |
| `docs/integration/PHASE1A_VALHALLA_POC_REPORT.md` | Modified | Embedded mandatory architectural declarations, clarified lack of native Valhalla tiles and Docker staging status, and documented P0 edge-pruning fix. |
| `docs/integration/PHASE1A_P0_CORRECTIVE_PATCH_REPORT.md` | Created | This formal patch report. |

*Preserved Files:* Zero files modified in `lib/`, `android/`, `assets/data/`, or Member 2/4 modules.

---

## 3. ROOT CAUSE OF THE INFINITE-WEIGHT DEFECT

### The Problem
In the previous Phase 1A proof-of-concept implementation:
```python
# PREVIOUS FLAWED IMPLEMENTATION
def weight_func(u, v, data):
    if (u, v) in blocked_edges:
        return float("inf")
    return data["weight"]

path = nx.shortest_path(self.graph, source=start_node, target=end_node, weight=weight_func)
```

### Technical Root Cause in NetworkX (v3.6.1)
NetworkX Dijkstra's algorithm accumulates edge weights numerically. When `weight_func` returns `float("inf")`, NetworkX treats the edge as existing with an infinite weight.
- If an alternative path with finite weight exists, Dijkstra chooses the finite path over the infinite path.
- **However, if all alternative paths are blocked**, Dijkstra still relaxes the infinite-weight edges because `float("inf")` is a valid floating-point number.
- Consequently, NetworkX did **not** raise `nx.NetworkXNoPath`. Instead, it returned an arbitrary path traversing the blocked edges with a cumulative path length of `float("inf")`, allowing the service to construct and return a route directly through a hazard zone with HTTP 200!

---

## 4. IMPLEMENTATION OF THE CORRECTION

### 4.1 Blocked-Edge Pruning via `None`
In accordance with NetworkX's documented callable weight specification:
> *"If weight is callable, the function must return a number or None to indicate that the edge is not available."*

The weight function in `backend/routing/valhalla_poc_service.py` was corrected to:
```python
def weight_func(u, v, data):
    if (u, v) in blocked_edges:
        return None  # Instructs NetworkX that edge is prohibited and unavailable
    w = data.get("weight")
    if w is None or not math.isfinite(w) or w < 0:
        return None
    return float(w)
```
When `weight_func` returns `None`, NetworkX completely ignores the edge during graph relaxation. If all paths between origin and destination contain blocked edges, NetworkX raises `nx.NetworkXNoPath`, which is caught and converted into an honest HTTP 442 response:
```python
except (nx.NetworkXNoPath, nx.NodeNotFound):
    return {
        "status_code": 442,
        "error": "No route found",
        "status_message": "All evaluated road paths are blocked by exclusion polygons or disconnected network components."
    }
```

### 4.2 Multi-Layered Safety Validation
Before and after computing a route, the following validations are strictly enforced:

1. **Origin & Destination Numerical Validity:**
   Rejects non-numeric, non-finite (NaN/Inf), or out-of-range coordinates with HTTP 400.
2. **Point-in-Polygon Check:**
   If `orig_pt` or `dest_pt` intersects or is contained within any active exclusion polygon, the query is rejected immediately with HTTP 442 (*"Origin/Destination is located inside an active exclusion polygon."*).
3. **Access Line Snap Check:**
   Validates that the first-mile line `LineString([(orig_lon, orig_lat), (start_node_lon, start_node_lat)])` and last-mile line do not intersect any active exclusion polygon.
4. **Post-Path Edge Check:**
   Iterates through each edge `(path[i], path[i+1])` asserting that no edge belongs to `blocked_edges`.
5. **Geometry Intersection Policy Verification:**
   Iterates through each coordinate pair in the final reconstructed `coords` geometry and checks `seg_line.intersects(poly)`. If any line segment touches an exclusion polygon, HTTP 442 is returned.
6. **Numerical Sanity Assertion:**
   Asserts that `total_dist_km` and `total_time_sec` are finite, positive, and non-NaN.

---

## 5. REGRESSION TEST RESULTS

### 5.1 New Safety Regression Suite (`test_polygon_exclusion_regression.py`)
Executed against authentic OpenStreetMap highway data (151,162 nodes, 384,225 directed edges):

```
================================================================================
SURAKSHAPATH P0 CORRECTIVE PATCH: POLYGON EXCLUSION REGRESSION TEST SUITE
================================================================================
[*] Initializing Valhalla Router from authentic OSM data: .../ap_extracted_highways.json
[+] Spatial graph and R-Tree indexed in 7.69s:
    - Nodes: 151,162
    - Directed Edges: 384,225
    - Total Roadways: 196,266

[TEST 1] One blocked edge with a valid alternative route...
  PASS: Valid alternative route found around single blocked segment.
        Base distance: 4.00 km | Detour distance: 4.00 km

[TEST 2] Multiple blocked edges with one remaining valid route...
  PASS: Successfully navigated multiple blocked edges through clear corridor.
        Detour distance: 4.0 km

[TEST 3] All available paths blocked (Critical P0 Assertion)...
  PASS: Correctly rejected with HTTP 442 when all paths are blocked.
        Response status: All evaluated road paths are blocked by exclusion polygons or disconnected network components.

[TEST 4] Origin inside an exclusion polygon...
  PASS: Origin inside polygon honestly rejected with HTTP 442.
        Message: Origin is located inside an active exclusion polygon.

[TEST 5] Destination inside an exclusion polygon...
  PASS: Destination inside polygon honestly rejected with HTTP 442.
        Message: Destination is located inside an active exclusion polygon.

[TEST 6] Polygon intersecting every possible route (Krishna River Crossings)...
  PASS: Krishna River corridor barrier completely blocked routing.
        Honest HTTP 442: All evaluated road paths are blocked by exclusion polygons or disconnected network components.

[TEST 7] Disconnected graph / ocean coordinates...
  PASS: Out-of-graph unreachable coordinate returned HTTP 442.
        Message: Locations are beyond maximum snapping radius (>5km from mapped road network).

[TEST 8] Multiple alternative routes where only one avoids polygon...
  PASS: Router selected the clean unblocked river bridge (Varadhi).
        Route distance: 17.28 km

[TEST 9] Route geometry safety validation against prohibited polygon...
  PASS: Calculated route completely avoids prohibited polygon boundary.

[TEST 10] Numerical sanity: No infinite or NaN distance or duration...
  PASS: All distance, duration, and coordinate metrics are strictly finite positive numbers.

================================================================================
REGRESSION SUITE RESULTS: 10 / 10 TESTS PASSED (100% PASS RATE)
================================================================================
```

### 5.2 Existing Test Suite Verification
- **Health Check (`health_check.py`):** Verified HTTP 200, 151,162 nodes, 384,225 edges.
- **Original 10-Point Verification Harness (`test_valhalla_routing.py`):** **10 / 10 PASS** (100%).
- **Performance Benchmarks (`benchmark.py`):**
  - Short Route P50: **17.10 ms**
  - Medium Route P50: **61.54 ms**
  - Cross-District P50: **220.49 ms**
  - Dynamic Hazard Exclusion Detour P50: **21.66 ms**
  - Dynamic Exclusion Overhead: **+1.79 ms (+9.7%)**
  - Concurrent Throughput: **138.38 req/sec** across 4 worker threads with **0 errors / 50 requests**.
- **Flutter Analyzer:** `No issues found! (ran in 3.9s)`.

---

## 6. DOCUMENTATION CORRECTIONS

Both `backend/routing/README.md` and `docs/integration/PHASE1A_VALHALLA_POC_REPORT.md` were updated to reflect the verified technical reality:

1. **Mandatory Declaration:**  
   *"SurakshaPath currently uses a custom Python routing proof of concept based on NetworkX and Shapely STRtree. It exposes a Valhalla-compatible HTTP JSON API but does not currently run the native Valhalla routing engine."*
2. **Graph Tiles:** Explicitly noted that no native Valhalla tiles (`valhalla_tiles/`, `tiles.tar`) exist.
3. **Docker Staging:** Clarified that Docker configurations are proposed Linux cloud deployment blueprints, not active local containers.
4. **Coverage Scope:** Explicitly restricted to the 5-district Coastal Disaster Corridor pilot; the remaining 21 districts have zero road network coverage in Phase 1A.
5. **Synthetic Polygons:** Explicitly labeled test polygons as synthetic (`TEST POLYGON - NOT A REAL FLOOD ZONE`).
6. **No Live Feeds:** Clarified that no live IMD, APSDMA, or CWC feeds are connected.
7. **Advisory Disclaimer:** Routing results are not verified safe evacuation instructions.
8. **Benchmark Context:** Benchmark results are explicitly identified as custom Python daemon measurements.

---

## 7. UNRESOLVED LIMITATIONS (DEFERRED TO PHASE 1B)

The following items are outside the scope of this P0 patch and are tracked for Phase 1B:
1. **Statewide PBF Ingestion:** Expanding road-network coverage from the 5 pilot districts to all 26 districts requires downloading `india-latest.osm.pbf` and extracting statewide highways using `pyosmium`.
2. **Native Valhalla C++ Engine:** Compiling true Mjolnir routing tiles requires staging the Docker container on a dedicated Linux host.
3. **OSM Relations & Turn Restrictions:** Ingesting OSM relations to enforce turn restrictions and mandatory lanes.
4. **Administrative Boundary Polygons:** Ingesting official Survey of India / APSDMA district and mandal boundary polygons.

---

## 8. GIT STATUS & RECOVERY CHECKPOINT

```
$ git status
On branch master
Changes not staged for commit:
	modified:   .gitignore
	modified:   assets/icons/flaticon/evacuate.png
	modified:   assets/icons/flaticon/home.png

Untracked files:
	backend/geo_pipeline/
	backend/routing/
	docs/integration/

$ git log -n 1 --oneline
381176b Correct routing reliability, first-mile distance, and safety terminology
```

---

## STOP CONDITION COMPLIANCE

This task implements **only the P0 corrective patch**. Phase 1B has not been initiated. Awaiting Member 1's technical review and explicit authorization.
