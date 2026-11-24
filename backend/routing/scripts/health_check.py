#!/usr/bin/env python3
"""
SurakshaPath Routing Test Suite: Health Check Script
Verifies Valhalla HTTP daemon is listening on port 8002 and reports healthy status.
"""

import sys
import json
import urllib.request

STATUS_URL = "http://127.0.0.1:8002/status"

def check_health():
    print(f"[*] Checking Valhalla service status at: {STATUS_URL}...")
    try:
        req = urllib.request.Request(STATUS_URL)
        with urllib.request.urlopen(req, timeout=5) as res:
            if res.status != 200:
                print(f"[FAIL] Unexpected HTTP status: {res.status}", file=sys.stderr)
                return False
            data = json.loads(res.read().decode("utf-8"))
            print(f"[SUCCESS] Valhalla Service is Healthy:")
            print(f"    - Version: {data.get('version')}")
            print(f"    - Status: {data.get('status')}")
            print(f"    - Dataset: {data.get('dataset')}")
            print(f"    - Active Nodes: {data.get('active_nodes', 0):,}")
            print(f"    - Active Edges: {data.get('active_edges', 0):,}")
            return True
    except Exception as e:
        print(f"[FAIL] Valhalla service unreachable: {e}", file=sys.stderr)
        return False

if __name__ == "__main__":
    if check_health():
        sys.exit(0)
    else:
        sys.exit(1)
