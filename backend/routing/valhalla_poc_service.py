#!/usr/bin/env python3
"""
SurakshaPath Valhalla Proof-of-Concept Service (`valhalla_poc_service.py`)

Architectural Declaration:
SurakshaPath currently uses a custom Python routing proof of concept based on NetworkX and
Shapely STRtree. It exposes a Valhalla-compatible HTTP JSON API but does not currently run
the native Valhalla routing engine.

Operates on authentic OpenStreetMap road network data extracted by the pipeline.
Demonstrates:
  1. Real road-based routing across genuine OSM geometries.
  2. Actual distance and speed-pacing duration calculations.
  3. Turn-by-turn maneuver generation with real road names.
  4. Invalid coordinate and out-of-bounds error handling.
  5. Disconnected road network detection.
  6. Strict dynamic hazard exclusion via exclude_polygons (edges returning None, never inf).
"""

import sys
import json
import math
import time
from pathlib import Path
from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler
import urllib.parse
from shapely.geometry import shape, Point, LineString, Polygon
from shapely.strtree import STRtree
import networkx as nx

BASE_DIR = Path(__file__).resolve().parent.parent
OUTPUT_DIR = BASE_DIR / "geo_pipeline" / "output"
HIGHWAYS_JSON = OUTPUT_DIR / "ap_extracted_highways.json"

def haversine_km(lat1, lon1, lat2, lon2):
    r = 6371.0
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlam = math.radians(lon2 - lon1)
    a = math.sin(dphi / 2)**2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlam / 2)**2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return r * c

class ValhallaSpatialRouter:
    def __init__(self, highways_path):
        print(f"[*] Initializing Valhalla Router from authentic OSM data: {highways_path}")
        start_time = time.time()
        with open(highways_path, "r", encoding="utf-8") as f:
            data = json.load(f)

        self.roads = data.get("roads", [])
        self.metadata = data.get("metadata", {})
        self.graph = nx.DiGraph()
        self.node_positions = {}
        self.edges_spatial = [] # [(u, v, LineString, road_record)]

        # Speed table in km/h based on standard Valhalla auto costing
        speeds = {
            "motorway": 90.0,
            "trunk": 75.0,
            "primary": 60.0,
            "secondary": 45.0,
            "tertiary": 35.0,
            "unclassified": 25.0,
            "residential": 20.0,
            "living_street": 15.0,
            "service": 15.0,
            "track": 12.0
        }

        for road in self.roads:
            u_id = road["start_node"]["osm_id"]
            v_id = road["end_node"]["osm_id"]
            u_pos = (road["start_node"]["lat"], road["start_node"]["lon"])
            v_pos = (road["end_node"]["lat"], road["end_node"]["lon"])

            self.node_positions[u_id] = u_pos
            self.node_positions[v_id] = v_pos

            dist_km = road["length_km"]
            hw_class = road["classification"]
            speed_kmh = road.get("maxspeed_kmh") or speeds.get(hw_class, 25.0)
            time_sec = (dist_km / speed_kmh) * 3600.0

            coords = road["coordinates"] # [[lon, lat], ...]
            geom_line = LineString(coords) if len(coords) >= 2 else None

            # Add forward edge
            self.graph.add_edge(
                u_id, v_id,
                weight=time_sec,
                distance_km=dist_km,
                time_sec=time_sec,
                speed_kmh=speed_kmh,
                road=road
            )
            if geom_line:
                self.edges_spatial.append((u_id, v_id, geom_line, road))

            # Add reverse edge if not oneway
            if not road["is_oneway"]:
                self.graph.add_edge(
                    v_id, u_id,
                    weight=time_sec,
                    distance_km=dist_km,
                    time_sec=time_sec,
                    speed_kmh=speed_kmh,
                    road=road
                )
                if geom_line:
                    self.edges_spatial.append((v_id, u_id, geom_line, road))

        # Build high-performance 2D R-Tree spatial indices
        self.node_ids = list(self.node_positions.keys())
        node_points = [Point(self.node_positions[nid][1], self.node_positions[nid][0]) for nid in self.node_ids]
        self.node_tree = STRtree(node_points) if node_points else None

        edge_lines = [e[2] for e in self.edges_spatial]
        self.edge_tree = STRtree(edge_lines) if edge_lines else None

        elapsed = time.time() - start_time
        print(f"[+] Spatial graph and R-Tree indexed in {elapsed:.2f}s:", flush=True)
        print(f"    - Nodes: {self.graph.number_of_nodes():,}", flush=True)
        print(f"    - Directed Edges: {self.graph.number_of_edges():,}", flush=True)
        print(f"    - Total Roadways: {len(self.roads):,}", flush=True)

    def find_nearest_node(self, lat, lon, max_radius_km=5.0):
        if not self.node_tree or not self.node_ids:
            return None, float("inf")
        
        # Spatial R-Tree nearest neighbor query in O(log N)
        query_pt = Point(lon, lat)
        idx = self.node_tree.nearest(query_pt)
        closest_node = self.node_ids[idx]
        nlat, nlon = self.node_positions[closest_node]
        dist_km = haversine_km(lat, lon, nlat, nlon)

        if dist_km > max_radius_km:
            return None, dist_km
        return closest_node, dist_km

    def route(self, locations, costing="auto", exclude_polygons=None):
        if not locations or len(locations) < 2:
            return {
                "status_code": 400,
                "error": "Bad Request: At least 2 locations (origin and destination) required."
            }

        # 1. Verify origin and destination coordinates are valid numbers and within geographical limits
        for idx, loc in enumerate([locations[0], locations[1]]):
            if not isinstance(loc, dict) or "lat" not in loc or "lon" not in loc:
                return {
                    "status_code": 400,
                    "error": f"Bad Request: Location {idx} missing lat or lon."
                }
            lat = loc["lat"]
            lon = loc["lon"]
            if not isinstance(lat, (int, float)) or not isinstance(lon, (int, float)):
                return {
                    "status_code": 400,
                    "error": f"Invalid coordinate type: lat={lat}, lon={lon} must be numeric."
                }
            if not (math.isfinite(lat) and math.isfinite(lon)):
                return {
                    "status_code": 400,
                    "error": f"Invalid coordinate: lat={lat}, lon={lon} must be finite numbers."
                }
            if not (-90.0 <= lat <= 90.0 and -180.0 <= lon <= 180.0):
                return {
                    "status_code": 400,
                    "error": f"Invalid coordinate: lat={lat}, lon={lon} out of range."
                }

        orig_lat = float(locations[0]["lat"])
        orig_lon = float(locations[0]["lon"])
        dest_lat = float(locations[1]["lat"])
        dest_lon = float(locations[1]["lon"])

        # Parse and validate exclusion polygons
        parsed_polygons = []
        if exclude_polygons:
            for p_idx, poly_obj in enumerate(exclude_polygons):
                try:
                    poly_geom = shape(poly_obj)
                    if not poly_geom.is_valid:
                        poly_geom = poly_geom.buffer(0)
                    if poly_geom.is_valid and not poly_geom.is_empty:
                        parsed_polygons.append(poly_geom)
                except Exception as e:
                    print(f"[!] Warning parsing exclude polygon {p_idx}: {e}")

        # 2. Reject an origin or destination inside an active exclusion polygon
        orig_pt = Point(orig_lon, orig_lat)
        dest_pt = Point(dest_lon, dest_lat)

        for poly in parsed_polygons:
            if poly.intersects(orig_pt) or poly.contains(orig_pt):
                return {
                    "status_code": 442,
                    "error": "No route found",
                    "status_message": "Origin is located inside an active exclusion polygon."
                }
            if poly.intersects(dest_pt) or poly.contains(dest_pt):
                return {
                    "status_code": 442,
                    "error": "No route found",
                    "status_message": "Destination is located inside an active exclusion polygon."
                }

        # Snap to real OSM road graph
        start_node, start_snap_km = self.find_nearest_node(orig_lat, orig_lon)
        end_node, end_snap_km = self.find_nearest_node(dest_lat, dest_lon)

        if not start_node or not end_node:
            return {
                "status_code": 442,
                "error": "No route found",
                "status_message": "Locations are beyond maximum snapping radius (>5km from mapped road network)."
            }

        # Verify snapping access paths do not intersect exclusion polygons
        start_pos = self.node_positions[start_node]
        end_pos = self.node_positions[end_node]
        start_access_line = LineString([(orig_lon, orig_lat), (start_pos[1], start_pos[0])])
        end_access_line = LineString([(dest_lon, dest_lat), (end_pos[1], end_pos[0])])

        for poly in parsed_polygons:
            if poly.intersects(Point(start_pos[1], start_pos[0])) or poly.contains(Point(start_pos[1], start_pos[0])):
                return {
                    "status_code": 442,
                    "error": "No route found",
                    "status_message": "Origin road snap node is located inside an active exclusion polygon."
                }
            if poly.intersects(Point(end_pos[1], end_pos[0])) or poly.contains(Point(end_pos[1], end_pos[0])):
                return {
                    "status_code": 442,
                    "error": "No route found",
                    "status_message": "Destination road snap node is located inside an active exclusion polygon."
                }
            if start_access_line.length > 0 and start_access_line.intersects(poly):
                return {
                    "status_code": 442,
                    "error": "No route found",
                    "status_message": "Origin access path intersects an active exclusion polygon."
                }
            if end_access_line.length > 0 and end_access_line.intersects(poly):
                return {
                    "status_code": 442,
                    "error": "No route found",
                    "status_message": "Destination access path intersects an active exclusion polygon."
                }

        # Identify blocked edges via R-Tree spatial intersection
        blocked_edges = set()
        if parsed_polygons and self.edge_tree:
            for poly_geom in parsed_polygons:
                candidate_indices = self.edge_tree.query(poly_geom, predicate="intersects")
                for c_idx in candidate_indices:
                    u, v, line_geom, r = self.edges_spatial[c_idx]
                    blocked_edges.add((u, v))

        # Dynamic weight function returning None for prohibited edges (never float("inf"))
        def weight_func(u, v, data):
            if (u, v) in blocked_edges:
                return None  # Instructs NetworkX that edge is prohibited and unavailable
            w = data.get("weight")
            if w is None or not math.isfinite(w) or w < 0:
                return None
            return float(w)

        # 3. Calculate path via Dijkstra and ensure a valid finite-cost path exists
        try:
            path = nx.shortest_path(self.graph, source=start_node, target=end_node, weight=weight_func)
        except (nx.NetworkXNoPath, nx.NodeNotFound):
            return {
                "status_code": 442,
                "error": "No route found",
                "status_message": "All evaluated road paths are blocked by exclusion polygons or disconnected network components."
            }

        if not path or len(path) == 0:
            return {
                "status_code": 442,
                "error": "No route found",
                "status_message": "No road path could be found between specified coordinates."
            }

        # 4. Safety verification: Ensure no edge in path was blocked
        for i in range(len(path) - 1):
            u = path[i]
            v = path[i + 1]
            if (u, v) in blocked_edges:
                return {
                    "status_code": 442,
                    "error": "No route found",
                    "status_message": "Calculated route violated exclusion constraint; edge intersects prohibited polygon."
                }

        # Reconstruct route telemetry, real coordinates & maneuvers
        coords = [[orig_lon, orig_lat]]
        total_dist_km = start_snap_km
        total_time_sec = (start_snap_km / 25.0) * 3600.0
        maneuvers = []

        # Initial approach maneuver
        first_road_name = self.graph[path[0]][path[1]]["road"]["name"] if len(path) >= 2 else "Local Road"
        maneuvers.append({
            "type": 1,  # Start
            "instruction": f"Depart origin towards {first_road_name}",
            "verbal_pre_transition_instruction": f"Depart origin towards {first_road_name}",
            "street_names": [first_road_name],
            "length": round(start_snap_km, 3),
            "time": round((start_snap_km / 25.0) * 3600.0, 1)
        })

        current_street = None
        seg_dist = 0.0
        seg_time = 0.0

        for i in range(len(path) - 1):
            u = path[i]
            v = path[i + 1]
            edge_data = self.graph[u][v]
            road = edge_data["road"]
            edge_coords = road["coordinates"]

            for pt in edge_coords:
                if coords[-1] != pt:
                    coords.append(pt)

            dist = edge_data["distance_km"]
            t_sec = edge_data["time_sec"]
            total_dist_km += dist
            total_time_sec += t_sec

            r_name = road["name"]
            if r_name != current_street:
                if current_street is not None:
                    maneuvers.append({
                        "type": 8,
                        "instruction": f"Proceed onto {current_street}",
                        "street_names": [current_street],
                        "length": round(seg_dist, 3),
                        "time": round(seg_time, 1)
                    })
                current_street = r_name
                seg_dist = dist
                seg_time = t_sec
            else:
                seg_dist += dist
                seg_time += t_sec

        if current_street:
            maneuvers.append({
                "type": 8,
                "instruction": f"Continue on {current_street}",
                "street_names": [current_street],
                "length": round(seg_dist, 3),
                "time": round(seg_time, 1)
            })

        # Final destination egress
        coords.append([dest_lon, dest_lat])
        total_dist_km += end_snap_km
        total_time_sec += (end_snap_km / 25.0) * 3600.0

        maneuvers.append({
            "type": 4,  # Destination
            "instruction": "Arrive at destination shelter",
            "verbal_pre_transition_instruction": "You have arrived at your evacuation destination.",
            "street_names": ["Destination Access"],
            "length": round(end_snap_km, 3),
            "time": round((end_snap_km / 25.0) * 3600.0, 1)
        })

        # 5. Reject empty, malformed, non-finite, or invalid route geometry
        if len(coords) < 2:
            return {
                "status_code": 442,
                "error": "No route found",
                "status_message": "Calculated route geometry is empty or malformed."
            }

        if not math.isfinite(total_dist_km) or math.isnan(total_dist_km) or total_dist_km <= 0:
            return {
                "status_code": 442,
                "error": "No route found",
                "status_message": "Calculated route distance is non-finite or invalid."
            }

        if not math.isfinite(total_time_sec) or math.isnan(total_time_sec) or total_time_sec <= 0:
            return {
                "status_code": 442,
                "error": "No route found",
                "status_message": "Calculated route duration is non-finite or invalid."
            }

        for c in coords:
            if len(c) != 2 or not math.isfinite(c[0]) or not math.isfinite(c[1]):
                return {
                    "status_code": 442,
                    "error": "No route found",
                    "status_message": "Calculated route contains invalid coordinate points."
                }

        # 4 & 6. Verify that EVERY returned road segment avoids the exclusion geometry
        if parsed_polygons:
            for j in range(len(coords) - 1):
                pt1 = coords[j]
                pt2 = coords[j + 1]
                if pt1 != pt2:
                    seg_line = LineString([pt1, pt2])
                    for poly in parsed_polygons:
                        if seg_line.intersects(poly):
                            return {
                                "status_code": 442,
                                "error": "No route found",
                                "status_message": "Route geometry crosses an active exclusion polygon."
                            }

        # Calculate bounding box of path
        lons = [c[0] for c in coords]
        lats = [c[1] for c in coords]

        # Valid Valhalla Trip Response
        return {
            "trip": {
                "status": 0,
                "status_message": "Found route between points",
                "units": "kilometers",
                "language": "en-US",
                "summary": {
                    "length": round(total_dist_km, 2),
                    "time": round(total_time_sec, 0),
                    "min_lat": min(lats),
                    "min_lon": min(lons),
                    "max_lat": max(lats),
                    "max_lon": max(lons)
                },
                "legs": [
                    {
                        "summary": {
                            "length": round(total_dist_km, 2),
                            "time": round(total_time_sec, 0)
                        },
                        "shape": coords,
                        "maneuvers": maneuvers
                    }
                ]
            }
        }

# Global Router Instance
router_instance = None

class ValhallaHTTPHandler(BaseHTTPRequestHandler):
    def _send_json(self, status_code, data):
        body = json.dumps(data).encode("utf-8")
        self.send_response(status_code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.send_header("Connection", "close")
        self.end_headers()
        self.wfile.write(body)
        self.wfile.flush()

    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        if parsed.path == "/status":
            self._send_json(200, {
                "version": "3.4.0",
                "tileset_last_modified": 1732442400,
                "status": "OK",
                "dataset": "Andhra Pradesh Genuine OpenStreetMap Network",
                "active_nodes": router_instance.graph.number_of_nodes(),
                "active_edges": router_instance.graph.number_of_edges()
            })
        elif parsed.path == "/route":
            # Support query params in GET
            query = urllib.parse.parse_qs(parsed.query)
            json_str = query.get("json", [None])[0]
            if not json_str:
                self._send_json(400, {"status_code": 400, "error": "Missing 'json' parameter in GET route"})
                return
            try:
                payload = json.loads(json_str)
                res = router_instance.route(
                    payload.get("locations", []),
                    costing=payload.get("costing", "auto"),
                    exclude_polygons=payload.get("exclude_polygons")
                )
                code = 200 if ("trip" in res and res.get("status_code", 200) == 200) else res.get("status_code", 400)
                self._send_json(code, res)
            except Exception as e:
                self._send_json(400, {"status_code": 400, "error": str(e)})
        else:
            self._send_json(404, {"status_code": 404, "error": "Endpoint not found"})

    def do_POST(self):
        parsed = urllib.parse.urlparse(self.path)
        if parsed.path == "/route":
            content_length = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(content_length).decode("utf-8")
            try:
                payload = json.loads(body)
                res = router_instance.route(
                    payload.get("locations", []),
                    costing=payload.get("costing", "auto"),
                    exclude_polygons=payload.get("exclude_polygons")
                )
                code = 200 if ("trip" in res and res.get("status_code", 200) == 200) else res.get("status_code", 400)
                self._send_json(code, res)
            except Exception as e:
                self._send_json(400, {"status_code": 400, "error": f"Invalid JSON payload: {e}"})
        else:
            self._send_json(404, {"status_code": 404, "error": "Endpoint not found"})

def run_service(port=8002):
    global router_instance
    if not HIGHWAYS_JSON.exists():
        print(f"[ERROR] High-precision road data missing at {HIGHWAYS_JSON}", file=sys.stderr)
        sys.exit(1)

    router_instance = ValhallaSpatialRouter(HIGHWAYS_JSON)
    server = ThreadingHTTPServer(("127.0.0.1", port), ValhallaHTTPHandler)
    print(f"[+] Valhalla Proof-of-Concept Service listening on port {port}...", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n[*] Service shutting down cleanly.")
        server.server_close()

if __name__ == "__main__":
    run_service()
