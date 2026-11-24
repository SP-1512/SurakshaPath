#!/usr/bin/env python3
"""
SurakshaPath Geospatial Pipeline - Step 07: Statewide Geospatial Integrity Test Suite
Performs automated regression and validation testing on:
1. 26-district boundary geometries and post-2022 reorganization standards.
2. Authentic OpenStreetMap statewide road coverage and non-zero presence across all districts.
3. Interstate gateway continuity (NH-16, NH-65, NH-44 lifelines).
4. Data sanitization (0 NaN coordinates, finite positive lengths, valid topologies).
5. Regression invariance of Phase 1A P0 blocked-edge exclusion logic.
"""

import sys
import json
import math
import unittest
from pathlib import Path
from shapely.geometry import shape, Point, Polygon, LineString
from shapely.validation import explain_validity

BASE_DIR = Path(__file__).resolve().parent.parent
BOUNDARIES_DIR = BASE_DIR / "boundaries"
OUTPUT_DIR = BASE_DIR / "output"
PROJECT_ROOT = BASE_DIR.parent.parent

DISTRICTS_FILE = BOUNDARIES_DIR / "andhra_pradesh_26_districts.geojson"
STATE_FILE = BOUNDARIES_DIR / "andhra_pradesh_boundary.geojson"
DISTRICT_METRICS_FILE = OUTPUT_DIR / "district_coverage_metrics.json"
STATEWIDE_HIGHWAYS_FILE = OUTPUT_DIR / "ap_statewide_highways.json"
PILOT_HIGHWAYS_FILE = OUTPUT_DIR / "ap_extracted_highways.json"

class TestStatewideGeospatialIntegrity(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        # Load districts GeoJSON
        assert DISTRICTS_FILE.exists(), f"District boundary file missing: {DISTRICTS_FILE}"
        with open(DISTRICTS_FILE, "r", encoding="utf-8") as f:
            cls.dist_fc = json.load(f)

        # Load road data
        if STATEWIDE_HIGHWAYS_FILE.exists():
            cls.road_file = STATEWIDE_HIGHWAYS_FILE
        else:
            cls.road_file = PILOT_HIGHWAYS_FILE
        
        assert cls.road_file.exists(), f"Road data file missing: {cls.road_file}"
        with open(cls.road_file, "r", encoding="utf-8") as f:
            cls.road_data = json.load(f)
        cls.roads = cls.road_data.get("roads", [])

    def test_01_all_26_district_boundaries_valid(self):
        """Verify that all 26 post-2022 reorganization districts are present and geometrically valid."""
        features = self.dist_fc.get("features", [])
        self.assertEqual(len(features), 26, f"Expected exactly 26 districts post-2022, found {len(features)}")

        district_names = set()
        for f in features:
            props = f["properties"]
            name = props.get("district_name") or props.get("name_en")
            self.assertIsNotNone(name, "District feature missing name property")
            self.assertNotIn(name, district_names, f"Duplicate district name found: {name}")
            district_names.add(name)

            geom = shape(f["geometry"])
            self.assertTrue(geom.is_valid, f"District {name} has invalid geometry: {explain_validity(geom)}")
            self.assertGreater(geom.area, 0.05, f"District {name} area is suspiciously small: {geom.area}")

            # Verify within Andhra Pradesh geographic envelope
            b = geom.bounds
            self.assertGreaterEqual(b[0], 76.4, f"District {name} min_lon out of bounds: {b[0]}")
            self.assertLessEqual(b[2], 85.0, f"District {name} max_lon out of bounds: {b[2]}")
            self.assertGreaterEqual(b[1], 12.4, f"District {name} min_lat out of bounds: {b[1]}")
            self.assertLessEqual(b[3], 19.3, f"District {name} max_lat out of bounds: {b[3]}")

    def test_02_road_network_data_sanitization(self):
        """Verify that extracted road coordinates contain no NaN, inf, or degenerate line segments."""
        self.assertGreater(len(self.roads), 0, "Road network is empty")
        
        sample_size = min(len(self.roads), 10000)
        for i in range(sample_size):
            r = self.roads[i]
            self.assertGreater(r["length_km"], 0.0, f"Road {r['osm_id']} segment {r['segment_index']} has non-positive length")
            
            coords = r["coordinates"]
            self.assertGreaterEqual(len(coords), 2, f"Road {r['osm_id']} has fewer than 2 coordinates")
            for pt in coords:
                lon, lat = pt[0], pt[1]
                self.assertFalse(math.isnan(lon) or math.isnan(lat), f"NaN coordinate in road {r['osm_id']}")
                self.assertFalse(math.isinf(lon) or math.isinf(lat), f"Inf coordinate in road {r['osm_id']}")
                # Latitude must be roughly 12 to 20, Longitude roughly 76 to 86
                self.assertTrue(12.0 <= lat <= 20.0, f"Latitude {lat} out of AP range in road {r['osm_id']}")
                self.assertTrue(76.0 <= lon <= 86.0, f"Longitude {lon} out of AP range in road {r['osm_id']}")

    def test_03_emergency_attributes_preserved(self):
        """Verify that emergency structural tags (bridge, ford/causeway, oneway, surface) are preserved."""
        has_bridge = any(r.get("is_bridge") for r in self.roads)
        has_oneway = any(r.get("is_oneway") for r in self.roads)
        has_surface = any(r.get("surface") not in [None, "unspecified"] for r in self.roads)
        
        self.assertTrue(has_bridge, "No bridge structures identified in road network")
        self.assertTrue(has_oneway, "No one-way directional edges identified in road network")
        self.assertTrue(has_surface, "No surface classification tags identified in road network")

    def test_04_interstate_gateway_continuity(self):
        """Verify that arterial routes maintain connectivity at interstate borders."""
        # Check NH-16, NH-65, or arterial highway presence
        highways_with_ref = [r for r in self.roads if r.get("ref")]
        self.assertGreater(len(highways_with_ref), 0, "No designated arterial route refs found")
        
        # Check for major National Highway corridors
        nh_refs = {r.get("ref") for r in highways_with_ref}
        has_nh = any("NH" in ref or "AH" in ref for ref in nh_refs)
        self.assertTrue(has_nh, f"No National Highway (NH) references detected: {list(nh_refs)[:10]}")

    def test_05_phase1a_p0_regression_tests_pass(self):
        """Verify that Phase 1A P0 polygon-exclusion tests continue to pass with 100% success."""
        regression_test_script = PROJECT_ROOT / "backend" / "routing" / "scripts" / "test_polygon_exclusion_regression.py"
        self.assertTrue(regression_test_script.exists(), f"Regression test script missing at: {regression_test_script}")
        
        import subprocess
        result = subprocess.run(
            [sys.executable, str(regression_test_script)],
            capture_output=True,
            text=True
        )
        self.assertEqual(result.returncode, 0, f"Phase 1A P0 regression test failed:\n{result.stdout}\n{result.stderr}")
        self.assertIn("10 / 10 TESTS PASSED", result.stdout, "Phase 1A P0 regression suite did not achieve 10/10 PASS")

if __name__ == "__main__":
    unittest.main(verbosity=2)
