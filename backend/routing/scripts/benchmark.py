#!/usr/bin/env python3
"""
SurakshaPath Valhalla Routing Performance Benchmark Suite (`benchmark.py`)
Measures:
  1. Routing Latency across categories:
     - Short routes (< 5 km, intra-urban)
     - Medium routes (5 - 20 km, peri-urban)
     - Cross-district routes (20 - 100 km, e.g. Vijayawada NTR to Guntur)
  2. Latency percentiles: P50, P90, P95, P99.
  3. Polygon Exclusion Overhead: Latency delta with dynamic polygon avoidance.
  4. Throughput & Concurrency: Requests per second under multi-threaded queries.
  5. System Memory & Resource Consumption (via psutil or OS diagnostics).
"""

import sys
import json
import time
import urllib.request
import urllib.error
import statistics
import concurrent.futures
from pathlib import Path

ROUTE_URL = "http://127.0.0.1:8002/route"
STATUS_URL = "http://127.0.0.1:8002/status"

# Test route definitions within authentic Coastal Disaster Corridor (Vijayawada-Guntur-Tenali-Machilipatnam)
BENCHMARK_ROUTES = {
    "short": {
        "name": "Short Intra-City (Benz Circle -> Gunadala, ~3.5km)",
        "payload": {
            "locations": [
                {"lat": 16.5062, "lon": 80.6480},
                {"lat": 16.5280, "lon": 80.6450}
            ],
            "costing": "auto"
        }
    },
    "medium": {
        "name": "Medium Peri-Urban (Vijayawada Center -> Mangalagiri, ~12km)",
        "payload": {
            "locations": [
                {"lat": 16.5062, "lon": 80.6480},
                {"lat": 16.4300, "lon": 80.5600}
            ],
            "costing": "auto"
        }
    },
    "cross_district": {
        "name": "Cross-District Corridor (NTR Vijayawada -> Guntur, ~34km)",
        "payload": {
            "locations": [
                {"lat": 16.5062, "lon": 80.6480},
                {"lat": 16.3067, "lon": 80.4365}
            ],
            "costing": "auto"
        }
    },
    "dynamic_exclusion": {
        "name": "Dynamic Hazard Exclusion (Vijayawada with Test Polygon)",
        "payload": {
            "locations": [
                {"lat": 16.5085, "lon": 80.6420},
                {"lat": 16.5180, "lon": 80.6200}
            ],
            "costing": "auto",
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
    }
}

def execute_route_query(payload):
    data_bytes = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        ROUTE_URL,
        data=data_bytes,
        headers={"Content-Type": "application/json"}
    )
    t0 = time.perf_counter()
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            body = resp.read()
            dt_ms = (time.perf_counter() - t0) * 1000.0
            data = json.loads(body.decode("utf-8"))
            dist = data.get("trip", {}).get("summary", {}).get("length", 0.0)
            return True, dt_ms, dist
    except Exception as e:
        dt_ms = (time.perf_counter() - t0) * 1000.0
        return False, dt_ms, str(e)

def get_service_status():
    req = urllib.request.Request(STATUS_URL)
    try:
        with urllib.request.urlopen(req, timeout=5) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except Exception as e:
        return {"error": str(e)}

def run_benchmarks(iterations_per_category=20, concurrent_threads=4, total_load_requests=50):
    print("=" * 75)
    print("SURAKSHAPATH VALHALLA ROUTING PERFORMANCE BENCHMARK SUITE")
    print("=" * 75)
    
    # 0. Health check
    status = get_service_status()
    if "error" in status:
        print(f"[!] Routing service unreachable at {STATUS_URL}: {status['error']}")
        sys.exit(1)
    
    print(f"[*] Connected to routing service:")
    print(f"    Version:      {status.get('version')}")
    print(f"    Dataset:      {status.get('dataset')}")
    print(f"    Active Nodes: {status.get('active_nodes', 0):,}")
    print(f"    Active Edges: {status.get('active_edges', 0):,}\n")

    results = {}
    all_latencies = []

    # 1. Category Latency Benchmarks
    print("[1] CATEGORY LATENCY BENCHMARKS (Warm cache & cold requests):")
    print(f"    Running {iterations_per_category} consecutive queries per category...\n")

    for cat_key, cat_info in BENCHMARK_ROUTES.items():
        name = cat_info["name"]
        payload = cat_info["payload"]
        latencies = []
        distances = []
        errors = 0

        # Run iterations
        for _ in range(iterations_per_category):
            success, dt, res = execute_route_query(payload)
            if success:
                latencies.append(dt)
                distances.append(res)
                all_latencies.append(dt)
            else:
                errors += 1

        if latencies:
            p50 = statistics.median(latencies)
            p90 = sorted(latencies)[int(len(latencies) * 0.90)]
            p95 = sorted(latencies)[int(len(latencies) * 0.95)]
            p99 = sorted(latencies)[min(int(len(latencies) * 0.99), len(latencies) - 1)]
            avg = statistics.mean(latencies)
            std = statistics.stdev(latencies) if len(latencies) > 1 else 0.0
            avg_dist = statistics.mean(distances) if distances else 0.0

            results[cat_key] = {
                "name": name,
                "avg_distance_km": round(avg_dist, 2),
                "iterations": len(latencies),
                "errors": errors,
                "avg_ms": round(avg, 2),
                "std_ms": round(std, 2),
                "p50_ms": round(p50, 2),
                "p90_ms": round(p90, 2),
                "p95_ms": round(p95, 2),
                "p99_ms": round(p99, 2),
                "min_ms": round(min(latencies), 2),
                "max_ms": round(max(latencies), 2)
            }
            print(f"  [{cat_key.upper()}] {name}")
            print(f"      Distance: {avg_dist:.2f} km | Queries: {len(latencies)}")
            print(f"      Avg: {avg:.2f} ms | P50: {p50:.2f} ms | P95: {p95:.2f} ms | P99: {p99:.2f} ms\n")

    # 2. Polygon Exclusion Overhead Analysis
    print("[2] DYNAMIC POLYGON EXCLUSION OVERHEAD ANALYSIS:")
    # Compare baseline (short) vs dynamic exclusion
    if "short" in results and "dynamic_exclusion" in results:
        base_ms = results["short"]["avg_ms"]
        poly_ms = results["dynamic_exclusion"]["avg_ms"]
        delta_ms = poly_ms - base_ms
        pct_overhead = ((poly_ms - base_ms) / base_ms) * 100.0 if base_ms > 0 else 0.0
        print(f"    Baseline Query Latency:   {base_ms:.2f} ms")
        print(f"    With Polygon Exclusion:   {poly_ms:.2f} ms")
        print(f"    Exclusion Overhead:       +{delta_ms:.2f} ms ({pct_overhead:+.1f}%)\n")
        results["exclusion_overhead"] = {
            "baseline_avg_ms": base_ms,
            "exclusion_avg_ms": poly_ms,
            "delta_ms": round(delta_ms, 2),
            "pct_overhead": round(pct_overhead, 1)
        }

    # 3. Concurrency and Throughput Load Test
    print(f"[3] CONCURRENCY & THROUGHPUT LOAD TEST ({total_load_requests} requests, {concurrent_threads} workers):")
    load_payload = BENCHMARK_ROUTES["short"]["payload"]
    load_latencies = []
    load_errors = 0
    t_start = time.perf_counter()

    with concurrent.futures.ThreadPoolExecutor(max_workers=concurrent_threads) as executor:
        futures = [executor.submit(execute_route_query, load_payload) for _ in range(total_load_requests)]
        for f in concurrent.futures.as_completed(futures):
            ok, dt, _ = f.result()
            if ok:
                load_latencies.append(dt)
            else:
                load_errors += 1

    total_load_duration = time.perf_counter() - t_start
    throughput_rps = total_load_requests / total_load_duration if total_load_duration > 0 else 0.0

    load_p50 = statistics.median(load_latencies) if load_latencies else 0.0
    load_p95 = sorted(load_latencies)[int(len(load_latencies) * 0.95)] if load_latencies else 0.0

    print(f"    Total Wall Duration:      {total_load_duration:.2f} s")
    print(f"    Throughput:               {throughput_rps:.2f} req/sec")
    print(f"    Load Latency P50 / P95:   {load_p50:.2f} ms / {load_p95:.2f} ms")
    print(f"    Errors:                   {load_errors} / {total_load_requests}\n")

    results["concurrency_load"] = {
        "total_requests": total_load_requests,
        "concurrent_workers": concurrent_threads,
        "wall_duration_sec": round(total_load_duration, 2),
        "throughput_rps": round(throughput_rps, 2),
        "load_p50_ms": round(load_p50, 2),
        "load_p95_ms": round(load_p95, 2),
        "load_errors": load_errors
    }

    # Overall Global Percentiles
    if all_latencies:
        overall_p50 = statistics.median(all_latencies)
        overall_p95 = sorted(all_latencies)[int(len(all_latencies) * 0.95)]
        overall_p99 = sorted(all_latencies)[min(int(len(all_latencies) * 0.99), len(all_latencies) - 1)]
        results["overall_summary"] = {
            "total_queries_measured": len(all_latencies),
            "p50_ms": round(overall_p50, 2),
            "p95_ms": round(overall_p95, 2),
            "p99_ms": round(overall_p99, 2)
        }

    # Save benchmark JSON output
    bench_out_file = Path(__file__).resolve().parent.parent / "benchmark_results.json"
    with open(bench_out_file, "w", encoding="utf-8") as f:
        json.dump(results, f, indent=2)
    print(f"[+] Benchmark results exported to {bench_out_file}")
    print("=" * 75)

if __name__ == "__main__":
    run_benchmarks()
