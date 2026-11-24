#!/usr/bin/env python3
"""
SurakshaPath Geospatial Pipeline - Step 03: Highway Extraction & Topological Filtering
Extracts genuine OpenStreetMap highways, applies 15 km geographic boundary buffer,
preserves road attributes (surface, bridge, ford, oneway, lanes, ref, name),
separates non-routable footpaths from vehicular networks, and outputs validated topological road graph.
"""

import sys
import json
import math
from pathlib import Path
from collections import Counter
import yaml
from shapely.geometry import shape, Point, LineString

BASE_DIR = Path(__file__).resolve().parent.parent
CONFIG_FILE = BASE_DIR / "config" / "extraction_config.yaml"
BOUNDARIES_DIR = BASE_DIR / "boundaries"
OUTPUT_DIR = BASE_DIR / "output"
STATE_BOUNDARY_FILE = BOUNDARIES_DIR / "andhra_pradesh_boundary.geojson"

def haversine_km(lat1, lon1, lat2, lon2):
    r = 6371.0
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlam = math.radians(lon2 - lon1)
    a = math.sin(dphi / 2)**2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlam / 2)**2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return r * c

def load_ap_boundary_with_buffer(buffer_km=15.0):
    with open(STATE_BOUNDARY_FILE, "r", encoding="utf-8") as f:
        data = json.load(f)
    geom = shape(data["features"][0]["geometry"])
    # Approximate degree buffer: 1 deg ~ 111 km
    buffer_deg = buffer_km / 111.0
    buffered_geom = geom.buffer(buffer_deg)
    return geom, buffered_geom

def extract_from_osm_json(input_json_path, config):
    print(f"[*] Reading OSM elements from {input_json_path}...")
    with open(input_json_path, "r", encoding="utf-8") as f:
        osm_data = json.load(f)

    elements = osm_data.get("elements", [])
    nodes = {}
    ways = []

    for el in elements:
        if el["type"] == "node":
            nodes[el["id"]] = (el["lat"], el["lon"])
        elif el["type"] == "way":
            ways.append(el)

    print(f"    Loaded {len(nodes):,} nodes and {len(ways):,} ways.")
    return process_ways_and_nodes(ways, nodes, config)

def process_ways_and_nodes(ways, nodes, config):
    state_geom, buffered_geom = load_ap_boundary_with_buffer(
        config["state"].get("boundary_buffer_km", 15.0)
    )

    allowed_vehicle_highways = set(config["filtering"]["vehicle_highways"])
    walking_highways = set(config["filtering"]["walking_exclusive_highways"])

    # First pass: identify topological junctions (nodes shared by >1 routable way or way terminals)
    node_usage = Counter()
    valid_ways = []
    for way in ways:
        tags = way.get("tags", {})
        hw = tags.get("highway")
        if not hw or hw in walking_highways or hw not in allowed_vehicle_highways:
            continue
        valid_ways.append(way)
        for nid in way.get("nodes", []):
            node_usage[nid] += 1

    junction_nodes = {nid for nid, count in node_usage.items() if count > 1}

    extracted_roads = []
    geojson_features = []
    stats = {
        "total_ways_evaluated": len(ways),
        "vehicle_roads_extracted": 0,
        "walking_paths_separated": 0,
        "discarded_out_of_bounds": 0,
        "discarded_unroutable": 0,
        "total_road_km": 0.0,
        "topological_junctions": len(junction_nodes),
        "classifications": {},
        "surfaces": {},
        "bridges": 0,
        "fords_causeways": 0,
        "oneway_segments": 0
    }

    for way in ways:
        tags = way.get("tags", {})
        hw = tags.get("highway")
        if not hw:
            stats["discarded_unroutable"] += 1
            continue

        if hw in walking_highways:
            stats["walking_paths_separated"] += 1
            continue

        if hw not in allowed_vehicle_highways:
            stats["discarded_unroutable"] += 1
            continue

        way_node_ids = way.get("nodes", [])
        if len(way_node_ids) < 2:
            continue

        name = tags.get("name") or tags.get("name:en") or tags.get("ref") or "Unnamed Road"
        ref = tags.get("ref")
        is_oneway = tags.get("oneway") in ["yes", "1", "true"]
        is_bridge = tags.get("bridge") in ["yes", "true"]
        is_ford = tags.get("ford") in ["yes", "true"] or tags.get("flood_prone") in ["yes", "true"]
        lanes = int(tags.get("lanes")) if tags.get("lanes", "").isdigit() else None
        maxspeed = int(tags.get("maxspeed")) if tags.get("maxspeed", "").isdigit() else None
        surface = tags.get("surface", "unspecified")

        # Topological Segmentation: split way at junctions to ensure network connectedness
        cur_node_ids = [way_node_ids[0]]
        subsegments = []

        for nid in way_node_ids[1:]:
            cur_node_ids.append(nid)
            if nid in junction_nodes or nid == way_node_ids[-1]:
                if len(cur_node_ids) >= 2:
                    subsegments.append(list(cur_node_ids))
                cur_node_ids = [nid]

        for seg_idx, seg_nids in enumerate(subsegments):
            seg_coords = []
            for nid in seg_nids:
                if nid in nodes:
                    seg_coords.append(nodes[nid])

            if len(seg_coords) < 2:
                continue

            # Check boundary buffer
            start_pt = Point(seg_coords[0][1], seg_coords[0][0])
            end_pt = Point(seg_coords[-1][1], seg_coords[-1][0])

            if not (buffered_geom.contains(start_pt) or buffered_geom.contains(end_pt)):
                stats["discarded_out_of_bounds"] += 1
                continue

            # Calculate exact geometric length
            seg_length_km = 0.0
            for i in range(len(seg_coords) - 1):
                seg_length_km += haversine_km(seg_coords[i][0], seg_coords[i][1], seg_coords[i+1][0], seg_coords[i+1][1])

            if is_oneway:
                stats["oneway_segments"] += 1
            if is_bridge:
                stats["bridges"] += 1
            if is_ford:
                stats["fords_causeways"] += 1

            stats["classifications"][hw] = stats["classifications"].get(hw, 0) + 1
            stats["surfaces"][surface] = stats["surfaces"].get(surface, 0) + 1
            stats["total_road_km"] += seg_length_km
            stats["vehicle_roads_extracted"] += 1

            road_record = {
                "osm_id": way["id"],
                "segment_index": seg_idx,
                "name": name,
                "ref": ref,
                "classification": hw,
                "length_km": round(seg_length_km, 3),
                "is_oneway": is_oneway,
                "lanes": lanes,
                "maxspeed_kmh": maxspeed,
                "surface": surface,
                "is_bridge": is_bridge,
                "is_ford_or_causeway": is_ford,
                "start_node": { "osm_id": seg_nids[0], "lat": seg_coords[0][0], "lon": seg_coords[0][1] },
                "end_node": { "osm_id": seg_nids[-1], "lat": seg_coords[-1][0], "lon": seg_coords[-1][1] },
                "node_count": len(seg_coords),
                "coordinates": [[c[1], c[0]] for c in seg_coords] # GeoJSON [lon, lat]
            }
            extracted_roads.append(road_record)

            feature = {
                "type": "Feature",
                "properties": {
                    "osm_id": way["id"],
                    "segment_index": seg_idx,
                    "name": name,
                    "ref": ref,
                    "highway": hw,
                    "length_km": round(seg_length_km, 3),
                    "surface": surface,
                    "bridge": is_bridge,
                    "ford": is_ford,
                    "oneway": is_oneway
                },
                "geometry": {
                    "type": "LineString",
                    "coordinates": [[c[1], c[0]] for c in seg_coords]
                }
            }
            geojson_features.append(feature)

    stats["total_road_km"] = round(stats["total_road_km"], 2)

    # Save outputs
    output_json = OUTPUT_DIR / "ap_extracted_highways.json"
    with open(output_json, "w", encoding="utf-8") as f:
        json.dump({
            "metadata": {
                "source": "OpenStreetMap Contributors under ODbL 1.0",
                "extracted_at": "2026-11-24T10:45:00Z",
                "pipeline_version": "1.0",
                "stats": stats
            },
            "roads": extracted_roads
        }, f, indent=2)

    output_geojson = OUTPUT_DIR / "ap_extracted_highways.geojson"
    with open(output_geojson, "w", encoding="utf-8") as f:
        json.dump({
            "type": "FeatureCollection",
            "name": "AndhraPradesh_Extracted_Highways",
            "features": geojson_features
        }, f, indent=2)

    print(f"\n[+] Extraction Complete:")
    print(f"    - Extracted Vehicle Roads: {stats['vehicle_roads_extracted']:,}")
    print(f"    - Total Road Network Length: {stats['total_road_km']:,} km")
    print(f"    - Bridges Identified: {stats['bridges']}")
    print(f"    - Fords / Causeways Identified: {stats['fords_causeways']}")
    print(f"    - Output JSON: {output_json} ({output_json.stat().st_size:,} bytes)")
    print(f"    - Output GeoJSON: {output_geojson} ({output_geojson.stat().st_size:,} bytes)")

    return stats

def main():
    print("=" * 65)
    print("SURAKSHAPATH GEOSPATIAL PIPELINE: HIGHWAY EXTRACTION")
    print("=" * 65)
    with open(CONFIG_FILE, "r", encoding="utf-8") as f:
        config = yaml.safe_load(f)

    pilot_input = OUTPUT_DIR / "ap_pilot_corridor_osm.json"
    if pilot_input.exists():
        stats = extract_from_osm_json(pilot_input, config)
        return 0
    else:
        print("[!] No pilot OSM JSON found. Please run 01_fetch_osm.py first or stage dataset.", file=sys.stderr)
        return 1

if __name__ == "__main__":
    sys.exit(main())
