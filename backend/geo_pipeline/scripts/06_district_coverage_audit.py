#!/usr/bin/env python3
"""
SurakshaPath Geospatial Pipeline - Step 06: District-by-District Road Network Audit
Performs comprehensive spatial join and graph topology analysis for all 26 districts of Andhra Pradesh.
Evaluates:
- Road length (km) & segment counts
- Road classification distributions
- Surface tagging completeness (paved, unpaved, unspecified)
- Structural features (bridges, tunnels, fords/causeways)
- Network graph connectivity (connected components, Largest Connected Component ratio)
"""

import sys
import json
from pathlib import Path
from collections import Counter
import networkx as nx
from shapely.geometry import shape, Point, LineString
from shapely.strtree import STRtree

BASE_DIR = Path(__file__).resolve().parent.parent
BOUNDARIES_DIR = BASE_DIR / "boundaries"
OUTPUT_DIR = BASE_DIR / "output"

DISTRICTS_GEOJSON = BOUNDARIES_DIR / "andhra_pradesh_26_districts.geojson"
DISTRICTS_META = BOUNDARIES_DIR / "districts_26_metadata.json"
STATEWIDE_HIGHWAYS_JSON = OUTPUT_DIR / "ap_statewide_highways.json"
FALLBACK_HIGHWAYS_JSON = OUTPUT_DIR / "ap_extracted_highways.json"
OUTPUT_METRICS_JSON = OUTPUT_DIR / "district_coverage_metrics.json"

PAVED_SURFACES = {
    "asphalt", "concrete", "paved", "concrete:lanes", "concrete:plates",
    "cobblestone", "cement", "sett", "paving_stones"
}
UNPAVED_SURFACES = {
    "unpaved", "dirt", "ground", "compacted", "gravel", "fine_gravel",
    "sand", "earth", "mud", "grass"
}

def load_data():
    if not DISTRICTS_GEOJSON.exists():
        raise FileNotFoundError(f"Missing district boundaries: {DISTRICTS_GEOJSON}")

    with open(DISTRICTS_GEOJSON, "r", encoding="utf-8") as f:
        dist_fc = json.load(f)

    meta_lookup = {}
    if DISTRICTS_META.exists():
        with open(DISTRICTS_META, "r", encoding="utf-8") as f:
            meta_data = json.load(f)
            for d in meta_data.get("districts", []):
                meta_lookup[d["name_en"].lower()] = d
                meta_lookup[d["id"]] = d

    highways_file = STATEWIDE_HIGHWAYS_JSON if STATEWIDE_HIGHWAYS_JSON.exists() else FALLBACK_HIGHWAYS_JSON
    if not highways_file.exists():
        raise FileNotFoundError(f"Missing road network data at {highways_file}")

    print(f"[*] Ingesting road network from: {highways_file.name}")
    with open(highways_file, "r", encoding="utf-8") as f:
        road_data = json.load(f)

    roads = road_data.get("roads", [])
    print(f"    Loaded {len(roads):,} road segments.")
    return dist_fc, meta_lookup, roads

def audit_districts():
    print("=" * 75)
    print("SURAKSHAPATH GEOSPATIAL PIPELINE: 26-DISTRICT COVERAGE AUDIT")
    print("=" * 75)

    dist_fc, meta_lookup, roads = load_data()

    # Build spatial index over 26 district polygons
    dist_features = dist_fc["features"]
    dist_geoms = [shape(f["geometry"]) for f in dist_features]
    dist_names = [f["properties"].get("district_name") or f["properties"].get("name_en") for f in dist_features]
    tree = STRtree(dist_geoms)

    print(f"[*] Initialized spatial index for {len(dist_geoms)} Andhra Pradesh district boundaries.")

    # Storage for per-district records
    district_buckets = {name: [] for name in dist_names}
    interstate_roads = []

    print("[*] Performing spatial joins between road segments and administrative boundaries...")
    for r in roads:
        # Check midpoint
        coords = r["coordinates"]
        mid_idx = len(coords) // 2
        pt = Point(coords[mid_idx][0], coords[mid_idx][1])
        
        # Spatial query
        candidates = tree.query(pt)
        matched = False
        for geom_idx in candidates:
            if dist_geoms[geom_idx].contains(pt):
                district_buckets[dist_names[geom_idx]].append(r)
                matched = True
                break
        
        if not matched:
            # Check start or end
            p_start = Point(coords[0][0], coords[0][1])
            for geom_idx in tree.query(p_start):
                if dist_geoms[geom_idx].contains(p_start):
                    district_buckets[dist_names[geom_idx]].append(r)
                    matched = True
                    break
        
        if not matched:
            interstate_roads.append(r)

    print(f"    Assigned roads across {len(dist_names)} districts. Interstate/gateway buffer roads: {len(interstate_roads):,}")

    district_audit_results = {}
    
    print("\n" + "=" * 110)
    print(f"{'District':<26} | {'Zone':<14} | {'Roads':<7} | {'Total km':<10} | {'Paved %':<8} | {'LCC %':<7} | {'Bridges':<7} | {'Fords':<5}")
    print("-" * 110)

    total_state_roads = 0
    total_state_km = 0.0

    for idx, f in enumerate(dist_features):
        props = f["properties"]
        d_name = props.get("district_name") or props.get("name_en")
        meta = meta_lookup.get(d_name.lower(), {})
        d_id = meta.get("id", props.get("district_id", d_name.lower().replace(" ", "_")))
        zone = meta.get("zone", "Unassigned")
        mandals = meta.get("mandals", len(props.get("mandals", [])))

        d_roads = district_buckets.get(d_name, [])
        d_count = len(d_roads)
        d_km = sum(r["length_km"] for r in d_roads)
        total_state_roads += d_count
        total_state_km += d_km

        # Classification counts
        class_counter = Counter(r["classification"] for r in d_roads)

        # Surface analysis
        paved_count = 0
        unpaved_count = 0
        unspecified_count = 0
        for r in d_roads:
            s = (r.get("surface") or "").lower()
            if s in PAVED_SURFACES:
                paved_count += 1
            elif s in UNPAVED_SURFACES:
                unpaved_count += 1
            else:
                unspecified_count += 1

        paved_pct = round((paved_count / d_count * 100), 1) if d_count > 0 else 0.0
        unpaved_pct = round((unpaved_count / d_count * 100), 1) if d_count > 0 else 0.0
        unspecified_pct = round((unspecified_count / d_count * 100), 1) if d_count > 0 else 0.0

        # Structural features
        bridges = sum(1 for r in d_roads if r.get("is_bridge"))
        tunnels = sum(1 for r in d_roads if r.get("is_tunnel"))
        fords = sum(1 for r in d_roads if r.get("is_ford_or_causeway"))
        oneways = sum(1 for r in d_roads if r.get("is_oneway"))

        # Graph topology analysis
        G = nx.Graph()
        for r in d_roads:
            u = r["start_node"]["osm_id"]
            v = r["end_node"]["osm_id"]
            G.add_edge(u, v, weight=r["length_km"])

        node_count = G.number_of_nodes()
        edge_count = G.number_of_edges()
        if node_count > 0:
            components = list(nx.connected_components(G))
            num_cc = len(components)
            lcc_size = len(max(components, key=len))
            lcc_pct = round((lcc_size / node_count * 100), 1)
        else:
            num_cc = 0
            lcc_size = 0
            lcc_pct = 0.0

        district_audit_results[d_name] = {
            "district_name": d_name,
            "district_id": d_id,
            "zone": zone,
            "headquarters": meta.get("headquarters", "N/A"),
            "mandal_count": mandals,
            "road_segments": d_count,
            "total_road_km": round(d_km, 2),
            "classifications": dict(class_counter),
            "surfaces": {
                "paved_count": paved_count,
                "paved_pct": paved_pct,
                "unpaved_count": unpaved_count,
                "unpaved_pct": unpaved_pct,
                "unspecified_count": unspecified_count,
                "unspecified_pct": unspecified_pct
            },
            "structural": {
                "bridges": bridges,
                "tunnels": tunnels,
                "fords_causeways": fords,
                "oneway_segments": oneways
            },
            "topology": {
                "nodes": node_count,
                "edges": edge_count,
                "connected_components": num_cc,
                "largest_connected_component_nodes": lcc_size,
                "lcc_connectivity_pct": lcc_pct
            }
        }

        print(f"{d_name:<26} | {zone:<14} | {d_count:<7} | {d_km:>8.2f} km | {paved_pct:>6.1f} % | {lcc_pct:>5.1f} % | {bridges:<7} | {fords:<5}")

    print("-" * 110)
    print(f"{'STATEWIDE TOTAL':<26} | {'All 26 Dists':<14} | {total_state_roads:<7} | {total_state_km:>8.2f} km |")
    print("=" * 110)

    # Save complete audit report JSON
    payload = {
        "metadata": {
            "audited_at": "2026-11-24T12:00:00Z",
            "scope": "Statewide Andhra Pradesh (All 26 Reorganized Districts)",
            "total_districts": len(dist_names),
            "total_state_roads": total_state_roads,
            "total_state_road_km": round(total_state_km, 2),
            "interstate_gateway_buffer_roads": len(interstate_roads)
        },
        "districts": district_audit_results
    }

    with open(OUTPUT_METRICS_JSON, "w", encoding="utf-8") as f:
        json.dump(payload, f, indent=2)

    print(f"\n[+] District coverage audit results saved to: {OUTPUT_METRICS_JSON}")
    return district_audit_results

if __name__ == "__main__":
    audit_districts()
