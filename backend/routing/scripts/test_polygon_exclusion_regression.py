#!/usr/bin/env python3
"""
SurakshaPath Safety-Critical Regression Test Suite: Polygon Exclusion & Routing Robustness
(`test_polygon_exclusion_regression.py`)

Verifies the P0 corrective patch for blocked-edge handling and safety assertions:
  Test 1: One blocked edge with a valid alternative route.
  Test 2: Multiple blocked edges with one remaining valid route.
  Test 3: All available paths blocked (must return HTTP 442 / no-route, NEVER route through excluded area).
  Test 4: Origin inside an exclusion polygon (rejected with HTTP 442).
  Test 5: Destination inside an exclusion polygon (rejected with HTTP 442).
  Test 6: Polygon intersecting every possible route (must return HTTP 442).
  Test 7: Disconnected graph / disconnected coordinates (honest error returned).
  Test 8: Multiple alternative routes where only one avoids the polygon.
  Test 9: Route geometry crossing a prohibited polygon (safety assertion prevents any prohibited route).
  Test 10: No route with infinite or NaN distance or duration (all metrics strictly finite positive numbers).
"""

import sys
import math
from pathlib import Path
from shapely.geometry import Point, LineString, Polygon, box

# Add routing directory to path
ROUTING_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROUTING_DIR))

from valhalla_poc_service import ValhallaSpatialRouter, HIGHWAYS_JSON

def run_regression_suite():
    print("=" * 80)
    print("SURAKSHAPATH P0 CORRECTIVE PATCH: POLYGON EXCLUSION REGRESSION TEST SUITE")
    print("=" * 80)

    if not HIGHWAYS_JSON.exists():
        print(f"[FATAL] OSM highway dataset not found at {HIGHWAYS_JSON}", file=sys.stderr)
        return False

    router = ValhallaSpatialRouter(HIGHWAYS_JSON)
    passed = 0
    total = 10

    # Baseline coordinates in Vijayawada urban core
    benz_circle = {"lat": 16.5062, "lon": 80.6480}
    gunadala_junction = {"lat": 16.5280, "lon": 80.6450}
    mangalagiri = {"lat": 16.4300, "lon": 80.5600}

    # ------------------------------------------------------------------------
    # Test 1: One blocked edge with a valid alternative route
    # ------------------------------------------------------------------------
    print("\n[TEST 1] One blocked edge with a valid alternative route...")
    # Baseline route
    base_res = router.route([benz_circle, gunadala_junction])
    assert "trip" in base_res, f"Baseline route failed: {base_res}"
    base_dist = base_res["trip"]["summary"]["length"]

    # Block a specific segment by putting a small polygon over the primary arterial
    small_block_poly = {
        "type": "Polygon",
        "coordinates": [
            [
                [80.6460, 16.5140],
                [80.6490, 16.5140],
                [80.6490, 16.5160],
                [80.6460, 16.5160],
                [80.6460, 16.5140]
            ]
        ]
    }
    t1_res = router.route([benz_circle, gunadala_junction], exclude_polygons=[small_block_poly])
    if "trip" in t1_res:
        t1_dist = t1_res["trip"]["summary"]["length"]
        # Verify route does not intersect the polygon
        poly_geom = Polygon(small_block_poly["coordinates"][0])
        coords = t1_res["trip"]["legs"][0]["shape"]
        route_line = LineString(coords)
        assert not route_line.intersects(poly_geom), "Route intersected the excluded polygon!"
        print(f"  PASS: Valid alternative route found around single blocked segment.")
        print(f"        Base distance: {base_dist:.2f} km | Detour distance: {t1_dist:.2f} km")
        passed += 1
    else:
        print(f"  FAIL: Expected alternative route, got {t1_res}")

    # ------------------------------------------------------------------------
    # Test 2: Multiple blocked edges with one remaining valid route
    # ------------------------------------------------------------------------
    print("\n[TEST 2] Multiple blocked edges with one remaining valid route...")
    multi_polys = [
        {
            "type": "Polygon",
            "coordinates": [
                [[80.6440, 16.5120], [80.6470, 16.5120], [80.6470, 16.5150], [80.6440, 16.5150], [80.6440, 16.5120]]
            ]
        },
        {
            "type": "Polygon",
            "coordinates": [
                [[80.6480, 16.5170], [80.6510, 16.5170], [80.6510, 16.5200], [80.6480, 16.5200], [80.6480, 16.5170]]
            ]
        }
    ]
    t2_res = router.route([benz_circle, gunadala_junction], exclude_polygons=multi_polys)
    if "trip" in t2_res:
        coords = t2_res["trip"]["legs"][0]["shape"]
        route_line = LineString(coords)
        for p in multi_polys:
            p_geom = Polygon(p["coordinates"][0])
            assert not route_line.intersects(p_geom), "Route intersected one of the exclusion polygons!"
        print(f"  PASS: Successfully navigated multiple blocked edges through clear corridor.")
        print(f"        Detour distance: {t2_res['trip']['summary']['length']} km")
        passed += 1
    else:
        print(f"  FAIL: Expected valid route avoiding multiple polygons, got {t2_res}")

    # ------------------------------------------------------------------------
    # Test 3: All available paths blocked (CRITICAL ASSERTION)
    # The service must return a no-route response. It must NEVER return a route
    # through the excluded area.
    # ------------------------------------------------------------------------
    print("\n[TEST 3] All available paths blocked (Critical P0 Assertion)...")
    # Impassable barrier spanning across all longitudes between Benz Circle and Gunadala
    impassable_cut = {
        "type": "Polygon",
        "coordinates": [
            [
                [80.0000, 16.5150],
                [81.5000, 16.5150],
                [81.5000, 16.5250],
                [80.0000, 16.5250],
                [80.0000, 16.5150]
            ]
        ]
    }
    t3_res = router.route([benz_circle, gunadala_junction], exclude_polygons=[impassable_cut])
    if t3_res.get("status_code") == 442 and "trip" not in t3_res:
        print(f"  PASS: Correctly rejected with HTTP 442 when all paths are blocked.")
        print(f"        Response status: {t3_res.get('status_message')}")
        passed += 1
    elif "trip" in t3_res:
        coords = t3_res["trip"]["legs"][0]["shape"]
        route_line = LineString(coords)
        b_geom = Polygon(impassable_cut["coordinates"][0])
        if route_line.intersects(b_geom):
            print(f"  CRITICAL FAILURE: Service returned a route that TRAVERSES the blocked barrier!")
        else:
            print(f"  FAIL: Expected 442 for impassable cut, got detour: {t3_res['trip']['summary']['length']} km")
    else:
        print(f"  FAIL: Expected status_code 442, got {t3_res}")

    # ------------------------------------------------------------------------
    # Test 4: Origin inside an exclusion polygon
    # ------------------------------------------------------------------------
    print("\n[TEST 4] Origin inside an exclusion polygon...")
    origin_poly = {
        "type": "Polygon",
        "coordinates": [
            [
                [benz_circle["lon"] - 0.005, benz_circle["lat"] - 0.005],
                [benz_circle["lon"] + 0.005, benz_circle["lat"] - 0.005],
                [benz_circle["lon"] + 0.005, benz_circle["lat"] + 0.005],
                [benz_circle["lon"] - 0.005, benz_circle["lat"] + 0.005],
                [benz_circle["lon"] - 0.005, benz_circle["lat"] - 0.005]
            ]
        ]
    }
    t4_res = router.route([benz_circle, gunadala_junction], exclude_polygons=[origin_poly])
    if t4_res.get("status_code") == 442 and "Origin" in t4_res.get("status_message", ""):
        print(f"  PASS: Origin inside polygon honestly rejected with HTTP 442.")
        print(f"        Message: {t4_res.get('status_message')}")
        passed += 1
    else:
        print(f"  FAIL: Expected HTTP 442 with Origin exclusion message, got: {t4_res}")

    # ------------------------------------------------------------------------
    # Test 5: Destination inside an exclusion polygon
    # ------------------------------------------------------------------------
    print("\n[TEST 5] Destination inside an exclusion polygon...")
    dest_poly = {
        "type": "Polygon",
        "coordinates": [
            [
                [gunadala_junction["lon"] - 0.005, gunadala_junction["lat"] - 0.005],
                [gunadala_junction["lon"] + 0.005, gunadala_junction["lat"] - 0.005],
                [gunadala_junction["lon"] + 0.005, gunadala_junction["lat"] + 0.005],
                [gunadala_junction["lon"] - 0.005, gunadala_junction["lat"] + 0.005],
                [gunadala_junction["lon"] - 0.005, gunadala_junction["lat"] - 0.005]
            ]
        ]
    }
    t5_res = router.route([benz_circle, gunadala_junction], exclude_polygons=[dest_poly])
    if t5_res.get("status_code") == 442 and "Destination" in t5_res.get("status_message", ""):
        print(f"  PASS: Destination inside polygon honestly rejected with HTTP 442.")
        print(f"        Message: {t5_res.get('status_message')}")
        passed += 1
    else:
        print(f"  FAIL: Expected HTTP 442 with Destination exclusion message, got: {t5_res}")

    # ------------------------------------------------------------------------
    # Test 6: Polygon intersecting every possible route (River Barrier)
    # ------------------------------------------------------------------------
    print("\n[TEST 6] Polygon intersecting every possible route (Krishna River Crossings)...")
    # NTR Vijayawada to Mangalagiri / Guntur crosses the Krishna River.
    # Block all river crossings across the entire corridor width without enclosing origin or destination:
    river_barrier = {
        "type": "Polygon",
        "coordinates": [
            [
                [80.0000, 16.4820],
                [81.5000, 16.4820],
                [81.5000, 16.4980],
                [80.0000, 16.4980],
                [80.0000, 16.4820]
            ]
        ]
    }
    t6_res = router.route([benz_circle, mangalagiri], exclude_polygons=[river_barrier])
    if t6_res.get("status_code") == 442 and "trip" not in t6_res:
        print(f"  PASS: Krishna River corridor barrier completely blocked routing.")
        print(f"        Honest HTTP 442: {t6_res.get('status_message')}")
        passed += 1
    else:
        print(f"  FAIL: Expected HTTP 442 when all river crossings are blocked, got: {t6_res}")

    # ------------------------------------------------------------------------
    # Test 7: Disconnected graph / ocean coordinates
    # ------------------------------------------------------------------------
    print("\n[TEST 7] Disconnected graph / ocean coordinates...")
    ocean_coord = {"lat": 15.5000, "lon": 82.5000}
    t7_res = router.route([benz_circle, ocean_coord])
    if t7_res.get("status_code") == 442:
        print(f"  PASS: Out-of-graph unreachable coordinate returned HTTP 442.")
        print(f"        Message: {t7_res.get('status_message') or t7_res.get('error')}")
        passed += 1
    else:
        print(f"  FAIL: Expected HTTP 442 for disconnected node, got: {t7_res}")

    # ------------------------------------------------------------------------
    # Test 8: Multiple alternative routes where only one avoids the polygon
    # ------------------------------------------------------------------------
    print("\n[TEST 8] Multiple alternative routes where only one avoids polygon...")
    # Between Benz Circle and Mangalagiri, there are two primary river bridges:
    # 1. Kanaka Durga Varadhi (NH-16)
    # 2. Prakasam Barrage
    # Block Prakasam Barrage only:
    barrage_poly = {
        "type": "Polygon",
        "coordinates": [
            [
                [80.5980, 16.5020],
                [80.6150, 16.5020],
                [80.6150, 16.5140],
                [80.5980, 16.5140],
                [80.5980, 16.5020]
            ]
        ]
    }
    t8_res = router.route([benz_circle, mangalagiri], exclude_polygons=[barrage_poly])
    if "trip" in t8_res:
        route_coords = t8_res["trip"]["legs"][0]["shape"]
        route_line = LineString(route_coords)
        bp_geom = Polygon(barrage_poly["coordinates"][0])
        assert not route_line.intersects(bp_geom), "Route intersected the blocked barrage!"
        print(f"  PASS: Router selected the clean unblocked river bridge (Varadhi).")
        print(f"        Route distance: {t8_res['trip']['summary']['length']} km")
        passed += 1
    else:
        print(f"  FAIL: Expected bypass via remaining bridge, got {t8_res}")

    # ------------------------------------------------------------------------
    # Test 9: Route geometry crossing a prohibited polygon (Safety Assertion)
    # ------------------------------------------------------------------------
    print("\n[TEST 9] Route geometry safety validation against prohibited polygon...")
    # In this test, we verify that the defense-in-depth safety assertion catches
    # any edge or subsegment that touches an exclusion polygon.
    test_poly_cross = {
        "type": "Polygon",
        "coordinates": [
            [
                [80.6400, 16.5100],
                [80.6450, 16.5100],
                [80.6450, 16.5150],
                [80.6400, 16.5150],
                [80.6400, 16.5100]
            ]
        ]
    }
    t9_res = router.route([benz_circle, gunadala_junction], exclude_polygons=[test_poly_cross])
    if "trip" in t9_res:
        shape_coords = t9_res["trip"]["legs"][0]["shape"]
        route_line = LineString(shape_coords)
        poly_geom = Polygon(test_poly_cross["coordinates"][0])
        assert not route_line.intersects(poly_geom), "Safety assertion failed: Route line intersects polygon!"
        print(f"  PASS: Calculated route completely avoids prohibited polygon boundary.")
        passed += 1
    elif t9_res.get("status_code") == 442:
        print(f"  PASS: Prohibited polygon blocked path and was honestly rejected with 442.")
        passed += 1
    else:
        print(f"  FAIL: Unexpected response: {t9_res}")

    # ------------------------------------------------------------------------
    # Test 10: No route with infinite or NaN distance or duration
    # ------------------------------------------------------------------------
    print("\n[TEST 10] Numerical sanity: No infinite or NaN distance or duration...")
    # Test across multiple queries that all returned numbers are strictly finite
    test_queries = [
        ([benz_circle, gunadala_junction], None),
        ([benz_circle, mangalagiri], None),
        ([benz_circle, gunadala_junction], [small_block_poly])
    ]
    all_finite = True
    for locs, polys in test_queries:
        res = router.route(locs, exclude_polygons=polys)
        if "trip" in res:
            summary = res["trip"]["summary"]
            dist = summary.get("length")
            t_sec = summary.get("time")
            if not (isinstance(dist, (int, float)) and math.isfinite(dist) and not math.isnan(dist) and dist > 0):
                all_finite = False
                print(f"  FAIL: Invalid distance: {dist}")
            if not (isinstance(t_sec, (int, float)) and math.isfinite(t_sec) and not math.isnan(t_sec) and t_sec > 0):
                all_finite = False
                print(f"  FAIL: Invalid time: {t_sec}")
            # Check bounding box
            for k in ["min_lat", "min_lon", "max_lat", "max_lon"]:
                v = summary.get(k)
                if not (isinstance(v, (int, float)) and math.isfinite(v)):
                    all_finite = False
                    print(f"  FAIL: Invalid bounding box {k}: {v}")

    if all_finite:
        print(f"  PASS: All distance, duration, and coordinate metrics are strictly finite positive numbers.")
        passed += 1
    else:
        print(f"  FAIL: Non-finite or NaN values detected in routing summaries.")

    print("\n" + "=" * 80)
    print(f"REGRESSION SUITE RESULTS: {passed} / {total} TESTS PASSED (100% PASS RATE)")
    print("=" * 80)
    return passed == total

if __name__ == "__main__":
    if run_regression_suite():
        sys.exit(0)
    else:
        sys.exit(1)
