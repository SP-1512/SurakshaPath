#!/usr/bin/env python3
"""
SurakshaPath Geospatial Pipeline - Step 05: Statewide PBF Highway Extraction
Single-Pass High-Throughput Memory-Optimized Highway Extractor for Andhra Pradesh (All 26 Districts).
Applies a 25-50 km buffered boundary envelope preserving critical interstate transit gateways:
- NH-16 North to Odisha (Ganjam / Brahmapur corridor)
- NH-16 South to Tamil Nadu (Tiruvallur / Chennai corridor)
- NH-65 West to Telangana (Suryapet / Hyderabad corridor)
- NH-44 North to Telangana (Alampur / Gadwal corridor)
- NH-44 South to Karnataka (Bagepalli / Bengaluru corridor)

Features:
- Two-node spatial gate: Discards out-of-state ways in O(1) before loading intermediate node coordinates.
- Preserves classifications (motorway down to tertiary, residential, unclassified, track, service).
- Preserves emergency attributes (bridge, tunnel, ford/causeway, oneway, lanes, surface, maxspeed).
"""

import os
import sys
import json
import math
import time
from pathlib import Path
from collections import Counter
from shapely.geometry import shape, Point, box
from shapely.ops import unary_union
import yaml
import osmium

BASE_DIR = Path(__file__).resolve().parent.parent
CONFIG_FILE = BASE_DIR / "config" / "extraction_config.yaml"
BOUNDARIES_DIR = BASE_DIR / "boundaries"
OUTPUT_DIR = BASE_DIR / "output"
STATE_BOUNDARY_FILE = BOUNDARIES_DIR / "andhra_pradesh_boundary.geojson"
DISTRICTS_FILE = BOUNDARIES_DIR / "andhra_pradesh_26_districts.geojson"

OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

def haversine_km(lat1, lon1, lat2, lon2):
    r = 6371.0
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlam = math.radians(lon2 - lon1)
    a = math.sin(dphi / 2)**2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlam / 2)**2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return r * c

def build_statewide_buffered_geometry():
    with open(STATE_BOUNDARY_FILE, "r", encoding="utf-8") as f:
        data = json.load(f)
    base_geom = shape(data["features"][0]["geometry"])
    
    # 25 km perimeter buffer (~0.225 degrees)
    buffer_deg = 25.0 / 111.0
    buffered_state = base_geom.buffer(buffer_deg)
    
    # Interstate gateway extension boxes (preserving continuity into neighboring states)
    gateways = [
        # NH-16 North to Odisha (Ichchapuram - Brahmapur corridor)
        box(84.40, 18.90, 85.10, 19.50),
        # NH-16 South to Tamil Nadu (Tada - Gummidipoondi corridor)
        box(79.80, 13.15, 80.30, 13.65),
        # NH-65 West to Telangana (Garikapadu - Kodad / Suryapet corridor)
        box(79.60, 16.65, 80.20, 17.20),
        # NH-44 North to Telangana (Pullur / Tungabhadra - Alampur corridor)
        box(77.75, 15.75, 78.30, 16.30),
        # NH-44 South to Karnataka (Bagepalli - Kodikonda corridor)
        box(77.40, 13.50, 77.95, 14.10),
    ]
    
    combined = unary_union([buffered_state] + gateways)
    return base_geom, combined

class StatewideHighwayCollector(osmium.SimpleHandler):
    def __init__(self, allowed_highways, walking_highways, buffered_polygon):
        super().__init__()
        self.allowed = allowed_highways
        self.walking = walking_highways
        self.poly = buffered_polygon
        self.poly_bounds = buffered_polygon.bounds # (min_lon, min_lat, max_lon, max_lat)
        self.extracted_roads = []
        self.stats = {
            "total_ways_evaluated": 0,
            "vehicle_roads_extracted": 0,
            "walking_paths_separated": 0,
            "discarded_out_of_bounds": 0,
            "discarded_unroutable": 0,
            "total_road_km": 0.0,
            "classifications": Counter(),
            "surfaces": Counter(),
            "bridges": 0,
            "tunnels": 0,
            "fords_causeways": 0,
            "oneway_segments": 0
        }
        self.last_log = time.time()

    def way(self, w):
        self.stats["total_ways_evaluated"] += 1
        tags = w.tags
        hw = tags.get("highway")

        if not hw:
            self.stats["discarded_unroutable"] += 1
            return
        if hw in self.walking:
            self.stats["walking_paths_separated"] += 1
            return
        if hw not in self.allowed:
            self.stats["discarded_unroutable"] += 1
            return

        node_count = len(w.nodes)
        if node_count < 2:
            return

        # Fast O(1) endpoint spatial gate: check start and end nodes first
        try:
            n_start = w.nodes[0]
            lat_s, lon_s = n_start.location.lat, n_start.location.lon
            n_end = w.nodes[-1]
            lat_e, lon_e = n_end.location.lat, n_end.location.lon
        except (osmium.InvalidLocationError, KeyError):
            return

        pb = self.poly_bounds # (min_lon, min_lat, max_lon, max_lat)
        # Discard if both start and end are entirely outside on any single cardinal direction
        if (lon_s < pb[0] and lon_e < pb[0]) or \
           (lon_s > pb[2] and lon_e > pb[2]) or \
           (lat_s < pb[1] and lat_e < pb[1]) or \
           (lat_s > pb[3] and lat_e > pb[3]):
            self.stats["discarded_out_of_bounds"] += 1
            return

        # Check midpoint
        mid_idx = node_count // 2
        try:
            n_mid = w.nodes[mid_idx]
            lat_m, lon_m = n_mid.location.lat, n_mid.location.lon
        except (osmium.InvalidLocationError, KeyError):
            lat_m, lon_m = lat_s, lon_s

        p_start = Point(lon_s, lat_s)
        p_end = Point(lon_e, lat_e)
        p_mid = Point(lon_m, lat_m)

        # Polygon containment gate
        if not (self.poly.contains(p_mid) or self.poly.contains(p_start) or self.poly.contains(p_end)):
            self.stats["discarded_out_of_bounds"] += 1
            return

        # Load full way coordinates only for matched roads
        way_nodes = [(n_start.ref, lat_s, lon_s)]
        for i in range(1, node_count - 1):
            n = w.nodes[i]
            try:
                way_nodes.append((n.ref, n.location.lat, n.location.lon))
            except (osmium.InvalidLocationError, KeyError):
                continue
        way_nodes.append((n_end.ref, lat_e, lon_e))

        # Calculate exact geometric length
        seg_len_km = 0.0
        for i in range(len(way_nodes) - 1):
            seg_len_km += haversine_km(way_nodes[i][1], way_nodes[i][2], way_nodes[i+1][1], way_nodes[i+1][2])

        name = tags.get("name") or tags.get("name:en") or tags.get("ref") or "Unnamed Road"
        ref = tags.get("ref")
        is_oneway = tags.get("oneway") in ["yes", "1", "true"]
        is_bridge = tags.get("bridge") in ["yes", "true"]
        is_tunnel = tags.get("tunnel") in ["yes", "true"]
        is_ford = tags.get("ford") in ["yes", "true"] or tags.get("flood_prone") in ["yes", "true"]
        lanes = int(tags.get("lanes")) if tags.get("lanes", "").isdigit() else None
        maxspeed = int(tags.get("maxspeed")) if tags.get("maxspeed", "").isdigit() else None
        surface = tags.get("surface", "unspecified")

        if is_oneway:
            self.stats["oneway_segments"] += 1
        if is_bridge:
            self.stats["bridges"] += 1
        if is_tunnel:
            self.stats["tunnels"] += 1
        if is_ford:
            self.stats["fords_causeways"] += 1

        self.stats["classifications"][hw] += 1
        self.stats["surfaces"][surface] += 1
        self.stats["total_road_km"] += seg_len_km
        self.stats["vehicle_roads_extracted"] += 1

        road_record = {
            "osm_id": w.id,
            "segment_index": 0,
            "name": name,
            "ref": ref,
            "classification": hw,
            "length_km": round(seg_len_km, 3),
            "is_oneway": is_oneway,
            "lanes": lanes,
            "maxspeed_kmh": maxspeed,
            "surface": surface,
            "is_bridge": is_bridge,
            "is_tunnel": is_tunnel,
            "is_ford_or_causeway": is_ford,
            "start_node": {"osm_id": way_nodes[0][0], "lat": way_nodes[0][1], "lon": way_nodes[0][2]},
            "end_node": {"osm_id": way_nodes[-1][0], "lat": way_nodes[-1][1], "lon": way_nodes[-1][2]},
            "node_count": len(way_nodes),
            "coordinates": [[n[2], n[1]] for n in way_nodes] # [lon, lat]
        }
        self.extracted_roads.append(road_record)

        now = time.time()
        if now - self.last_log > 8.0:
            print(f"    Extracted: {self.stats['vehicle_roads_extracted']:,} roads ({self.stats['total_road_km']:,.1f} km) | Discarded: {self.stats['discarded_out_of_bounds']:,} out-of-state | Evaluated: {self.stats['total_ways_evaluated']:,} ways", flush=True)
            self.last_log = now

def run_statewide_extraction(pbf_path=None):
    print("=" * 70, flush=True)
    print("SURAKSHAPATH GEOSPATIAL PIPELINE: STATEWIDE HIGHWAY EXTRACTION", flush=True)
    print("=" * 70, flush=True)
    
    if pbf_path is None:
        pbf_path = OUTPUT_DIR / "india-latest.osm.pbf"
    else:
        pbf_path = Path(pbf_path)

    if not pbf_path.exists():
        print(f"[ERROR] Input PBF file does not exist: {pbf_path}", file=sys.stderr)
        return False

    print(f"[*] Input PBF Source: {pbf_path} ({pbf_path.stat().st_size:,} bytes)", flush=True)
    
    with open(CONFIG_FILE, "r", encoding="utf-8") as f:
        config = yaml.safe_load(f)

    allowed_highways = set(config["filtering"]["vehicle_highways"])
    walking_highways = set(config["filtering"]["walking_exclusive_highways"])

    print("[*] Generating buffered Andhra Pradesh statewide boundary (25 km buffer + gateways)...", flush=True)
    base_geom, buffered_geom = build_statewide_buffered_geometry()
    envelope_box = buffered_geom.bounds
    print(f"    Buffered Envelope: Lon [{envelope_box[0]:.2f}, {envelope_box[2]:.2f}], Lat [{envelope_box[1]:.2f}, {envelope_box[3]:.2f}]", flush=True)
    print(f"    Target Area: {buffered_geom.area:.2f} sq degrees (~{buffered_geom.area * 111 * 111:,.0f} sq km)", flush=True)

    t0 = time.time()

    print("\n[*] Starting accelerated single-pass extraction with disk-backed node cache...", flush=True)
    collector = StatewideHighwayCollector(allowed_highways, walking_highways, buffered_geom)
    collector.apply_file(str(pbf_path), locations=True, idx="sparse_file_array")

    elapsed = time.time() - t0
    stats = collector.stats

    print("\n[+] Extraction Complete in {:.1f} seconds.".format(elapsed), flush=True)
    print(f"    - Vehicle Roads Extracted:  {stats['vehicle_roads_extracted']:,}", flush=True)
    print(f"    - Total Mapped Road Length: {stats['total_road_km']:,.2f} km", flush=True)
    print(f"    - Bridges:                  {stats['bridges']:,}", flush=True)
    print(f"    - Tunnels:                  {stats['tunnels']:,}", flush=True)
    print(f"    - Fords / Causeways:        {stats['fords_causeways']:,}", flush=True)
    print(f"    - One-way Segments:         {stats['oneway_segments']:,}", flush=True)

    output_json = OUTPUT_DIR / "ap_statewide_highways.json"
    output_payload = {
        "metadata": {
            "source": "OpenStreetMap Contributors under ODbL 1.0",
            "source_pbf": str(pbf_path.name),
            "source_pbf_size_bytes": pbf_path.stat().st_size,
            "extracted_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "pipeline_version": "2.0-statewide",
            "scope": "Statewide Andhra Pradesh (All 26 Districts + Interstate Gateways)",
            "boundary_buffer_km": 25.0,
            "statistics": {
                "total_ways_evaluated": stats["total_ways_evaluated"],
                "vehicle_roads_extracted": stats["vehicle_roads_extracted"],
                "walking_paths_separated": stats["walking_paths_separated"],
                "discarded_out_of_bounds": stats["discarded_out_of_bounds"],
                "total_road_km": round(stats["total_road_km"], 2),
                "classifications": dict(stats["classifications"]),
                "surfaces": dict(stats["surfaces"]),
                "bridges": stats["bridges"],
                "tunnels": stats["tunnels"],
                "fords_causeways": stats["fords_causeways"],
                "oneway_segments": stats["oneway_segments"]
            }
        },
        "roads": collector.extracted_roads
    }

    print(f"[*] Writing statewide road network JSON to {output_json}...", flush=True)
    with open(output_json, "w", encoding="utf-8") as f:
        json.dump(output_payload, f, indent=2)

    output_geojson = OUTPUT_DIR / "ap_statewide_highways.geojson"
    print(f"[*] Writing statewide road network GeoJSON to {output_geojson}...", flush=True)
    features = []
    for r in collector.extracted_roads:
        feat = {
            "type": "Feature",
            "properties": {
                "osm_id": r["osm_id"],
                "segment_index": r["segment_index"],
                "name": r["name"],
                "ref": r["ref"],
                "highway": r["classification"],
                "length_km": r["length_km"],
                "surface": r["surface"],
                "oneway": r["is_oneway"],
                "bridge": r["is_bridge"],
                "tunnel": r["is_tunnel"],
                "ford": r["is_ford_or_causeway"]
            },
            "geometry": {
                "type": "LineString",
                "coordinates": r["coordinates"]
            }
        }
        features.append(feat)

    with open(output_geojson, "w", encoding="utf-8") as f:
        json.dump({"type": "FeatureCollection", "features": features}, f)

    print(f"[SUCCESS] Statewide road network saved successfully.", flush=True)
    print(f"    - JSON:    {output_json} ({output_json.stat().st_size:,} bytes)", flush=True)
    print(f"    - GeoJSON: {output_geojson} ({output_geojson.stat().st_size:,} bytes)", flush=True)
    return True

if __name__ == "__main__":
    pbf_arg = sys.argv[1] if len(sys.argv) > 1 else None
    success = run_statewide_extraction(pbf_arg)
    sys.exit(0 if success else 1)
