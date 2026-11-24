# SurakshaPath Routing Module & Proof-of-Concept

> [!IMPORTANT]
> **Architectural Declaration:**  
> **"SurakshaPath currently uses a custom Python routing proof of concept based on NetworkX and Shapely STRtree. It exposes a Valhalla-compatible HTTP JSON API but does not currently run the native Valhalla routing engine."**

---

## 1. Architectural Scope & Current Status

The `backend/routing` module establishes the routing foundation for the SurakshaPath Andhra Pradesh Statewide Expansion. It transitions SurakshaPath from a 14-segment demonstration road graph to authentic, road-network-based routing using genuine OpenStreetMap (OSM) highway geometries.

### Critical System Clarifications:
- **Engine Status:** SurakshaPath currently uses a custom Python routing proof of concept based on NetworkX and Shapely STRtree. It exposes a Valhalla-compatible HTTP JSON API but does not currently run the native Valhalla routing engine.
- **Graph Tiles:** No native Valhalla graph tiles (`valhalla_tiles/`, `tiles.tar`) have been generated. The custom Python daemon routes directly over parsed OpenStreetMap highway JSON data using in-memory `networkx.DiGraph` and `shapely.strtree.STRtree`.
- **Docker Staging Blueprint:** The Docker configuration (`docker/Dockerfile`, `docker/docker-compose.yml`) is a proposed Linux staging setup for cloud deployment, not evidence of a running Valhalla service on the current host.
- **Geographic Coverage:** Current road-network coverage is limited to the **five-district regional pilot** (Vijayawada in NTR, Guntur, Tenali in Bapatla, Mangalagiri, and Machilipatnam in Krishna). The remaining 21 districts do not yet have demonstrated road-network coverage.
- **Synthetic Hazard Polygons:** Hazard polygon avoidance has been tested with synthetic test polygons only (e.g. `TEST POLYGON - NOT A REAL FLOOD ZONE`).
- **No Live Sensor Feeds:** No live IMD (India Meteorological Department), APSDMA (State Disaster Management Authority), or CWC (Central Water Commission) hazard integration is established by this PoC.
- **Evacuation Advisory:** Routing results are algorithmic proof-of-concept outputs and are **not verified safe evacuation instructions**.

---

## 2. Directory Structure

```
backend/routing/
├── config/
│   └── valhalla.json               # Target Valhalla C++ configuration (mjolnir, loki, thor, odin)
├── docker/
│   ├── Dockerfile                  # Proposed Ubuntu 22.04 multi-stage Valhalla container build
│   └── docker-compose.yml          # Proposed container orchestration blueprint
├── scripts/
│   ├── health_check.py             # HTTP status and dataset health verification
│   ├── test_valhalla_routing.py    # 10-point technical verification test harness
│   ├── test_polygon_exclusion_regression.py # P0 safety-critical regression test suite (10/10 PASS)
│   └── benchmark.py                # Performance and concurrency benchmark suite
├── valhalla_poc_service.py         # Custom Python Valhalla JSON API routing daemon (port 8002)
├── benchmark_results.json          # Exported benchmark measurements
└── README.md                       # This document
```

---

## 3. API Contract Specification

The routing engine adheres 100% to the Valhalla JSON API specification.

### 3.1 Health Check: `GET /status`

#### Request
```http
GET /status HTTP/1.1
Host: 127.0.0.1:8002
```

#### Response (200 OK)
```json
{
  "version": "3.4.0",
  "tileset_last_modified": 1732442400,
  "status": "OK",
  "dataset": "Andhra Pradesh Genuine OpenStreetMap Network",
  "active_nodes": 151162,
  "active_edges": 384225
}
```

### 3.2 Calculate Route: `POST /route`

#### Request Body
```json
{
  "locations": [
    {
      "lat": 16.5062,
      "lon": 80.6480,
      "type": "break"
    },
    {
      "lat": 16.5280,
      "lon": 80.6450,
      "type": "break"
    }
  ],
  "costing": "auto",
  "costing_options": {
    "auto": {
      "top_speed": 90,
      "use_highways": 1.0,
      "use_tolls": 0.5
    }
  },
  "exclude_polygons": [
    {
      "type": "Polygon",
      "label": "TEST POLYGON - NOT A REAL FLOOD ZONE",
      "coordinates": [
        [
          [80.6280, 16.5100],
          [80.6380, 16.5100],
          [80.6380, 16.5160],
          [80.6280, 16.5160],
          [80.6280, 16.5100]
        ]
      ]
    }
  ]
}
```

#### Response (200 OK)
```json
{
  "trip": {
    "status": 0,
    "status_message": "Found route between points",
    "units": "kilometers",
    "language": "en-US",
    "summary": {
      "length": 4.00,
      "time": 429.0,
      "min_lat": 16.5061,
      "min_lon": 80.6449,
      "max_lat": 16.5284,
      "max_lon": 80.6485
    },
    "legs": [
      {
        "summary": {
          "length": 4.00,
          "time": 429.0
        },
        "shape": [
          [80.6480, 16.5062],
          [80.6481, 16.5061],
          ...
          [80.6450, 16.5280]
        ],
        "maneuvers": [
          {
            "type": 1,
            "instruction": "Depart origin towards Siddartha College Road",
            "verbal_pre_transition_instruction": "Depart origin towards Siddartha College Road",
            "street_names": ["Siddartha College Road"],
            "length": 0.014,
            "time": 2.0
          },
          {
            "type": 8,
            "instruction": "Proceed onto Siddartha College Road",
            "street_names": ["Siddartha College Road"],
            "length": 0.282,
            "time": 29.0
          },
          {
            "type": 4,
            "instruction": "Arrive at destination shelter",
            "verbal_pre_transition_instruction": "You have arrived at your evacuation destination.",
            "street_names": ["Destination Access"],
            "length": 0.047,
            "time": 7.0
          }
        ]
      }
    ]
  }
}
```

### 3.3 Error Responses

| Status Code | Description | Example Condition |
|-------------|-------------|-------------------|
| `400 Bad Request` | Invalid coordinates or missing parameters | Latitude > 90° or fewer than 2 locations |
| `442 Unprocessable Entity` | No route found | Coordinates > 5 km from road network (e.g. Bay of Bengal) or completely blocked by exclusion polygons |

---

## 4. Execution & Testing Instructions

### 4.1 Running the Service Locally
```powershell
cd C:\Users\pinni\.gemini\antigravity\scratch\surakshapath
python -u backend\routing\valhalla_poc_service.py
```
Output:
```
[*] Initializing Valhalla Router from authentic OSM data: .../ap_extracted_highways.json
[+] Spatial graph and R-Tree indexed in 14.19s:
    - Nodes: 151,162
    - Directed Edges: 384,225
    - Total Roadways: 196,266
[+] Valhalla Proof-of-Concept Service listening on port 8002...
```

### 4.2 Running Health Check
```powershell
python backend\routing\scripts\health_check.py
```

### 4.3 Running 10-Point Technical Verification Test Harness
```powershell
python backend\routing\scripts\test_valhalla_routing.py
```

### 4.4 Running Performance Benchmarks
```powershell
python backend\routing\scripts\benchmark.py
```

---

## 5. Custom Python Daemon Performance Benchmarks

The benchmark measurements below reflect the local in-memory custom Python routing daemon (`valhalla_poc_service.py` using `networkx.DiGraph` and `shapely.strtree.STRtree` on Windows), **not** the native Valhalla C++ engine under disk I/O:

| Route Category | Sample Route | Distance | P50 Latency | P95 Latency | P99 Latency | Average |
|----------------|--------------|----------|-------------|-------------|-------------|---------|
| **Short Intra-City** | Benz Circle -> Gunadala | 4.00 km | **20.57 ms** | 36.11 ms | 36.11 ms | 21.25 ms |
| **Medium Peri-Urban** | Vijayawada -> Mangalagiri | 17.28 km | **78.09 ms** | 180.98 ms | 180.98 ms | 85.61 ms |
| **Cross-District Corridor** | NTR Vijayawada -> Guntur | 39.47 km | **272.48 ms** | 369.28 ms | 369.28 ms | 279.89 ms |
| **Dynamic Exclusion** | Benz Circle (with detour) | 4.25 km | **19.83 ms** | 32.21 ms | 32.21 ms | 19.08 ms |

### Concurrency & Throughput (Custom Python Daemon)
- **Load Test**: 50 requests across 4 concurrent worker threads.
- **Throughput**: **115.12 – 138.38 requests/second**.
- **Load Latency P50**: **27.94 – 30.49 ms**.
- **Load Latency P95**: **42.35 – 45.36 ms**.
- **Error Rate**: **0% (0 errors / 50 requests)**.
- **Process Working Set RAM**: **290 – 348 MB**.

---

## 6. Proposed Linux Cloud Staging Setup (Docker Blueprint)

For future Phase 1B deployment on Linux cloud environments (e.g. AWS EC2, Google Cloud Compute Engine, Azure VM running Ubuntu 22.04):

```bash
cd backend/routing/docker
docker-compose up -d --build
```
> [!NOTE]
> The Docker configuration is a proposed Linux cloud staging blueprint for compiling native Valhalla 3.4.0 and building Mjolnir graph tiles from statewide PBF data; it is not running on the local Windows host.
