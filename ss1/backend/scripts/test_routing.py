"""
SafarSathi — Route Optimizer Test
Run this to verify routing works before building the FastAPI endpoint.

    cd saferoute/backend
    python scripts/test_routing.py
"""

import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from services.route_optimizer import router


def test_routing():
    print("=" * 55)
    print("SafarSathi — Route Optimizer Test")
    print("=" * 55)

    # Load the graph
    router.load()

    if not router.loaded:
        print("FAILED: Router could not load. Check graph file exists.")
        return

    # Test route: Mhow College → Mhow Police Station
    print("\nTest 1: College → Police Station (Mhow)")
    print("-" * 40)
    try:
        route = router.find_safest_route(
            origin_lat=22.5560, origin_lng=75.7640,   # College
            dest_lat=22.5523,   dest_lng=75.7580,     # Police Station
            preference="balanced",
        )
        print(f"  Distance:     {route['total_distance_m']}m")
        print(f"  Walk time:    ~{route['walk_minutes']} min")
        print(f"  Safety score: {route['overall_safety_score']} ({route['safety_label']})")
        print(f"  Route points: {route['node_count']} nodes")
        print(f"  First coord:  {route['coordinates'][0]}")
        print(f"  Last coord:   {route['coordinates'][-1]}")
        print("  PASSED ✓")
    except Exception as e:
        print(f"  FAILED: {e}")

    # Test 2: Alternative routes
    print("\nTest 2: Alternative routes (safest vs balanced vs shortest)")
    print("-" * 40)
    try:
        routes = router.find_alternative_routes(
            origin_lat=22.5560, origin_lng=75.7640,
            dest_lat=22.5510,   dest_lng=75.7620,   # Civil Hospital
        )
        for r in routes:
            pref = r.get("preference", "unknown")
            dist = r["total_distance_m"]
            safe = r["overall_safety_score"]
            print(f"  [{pref:<10}] {dist}m — safety {safe} ({r['safety_label']})")
        print("  PASSED ✓")
    except Exception as e:
        print(f"  FAILED: {e}")

    # Test 3: Deviation detection
    print("\nTest 3: Dead-man switch deviation detection")
    print("-" * 40)
    try:
        route = router.find_safest_route(
            22.5560, 75.7640, 22.5523, 75.7580, preference="balanced"
        )
        coords = route["coordinates"]

        # Simulate: user is on route
        on_route_lat = coords[len(coords)//2]["lat"]
        on_route_lng = coords[len(coords)//2]["lng"]
        deviated, dist = router.is_deviation(on_route_lat, on_route_lng, coords)
        print(f"  On-route check:  deviated={deviated}, distance={dist}m")

        # Simulate: user is 500m away from route
        off_lat = on_route_lat + 0.005   # ~500m north
        deviated2, dist2 = router.is_deviation(off_lat, on_route_lng, coords)
        print(f"  Off-route check: deviated={deviated2}, distance={dist2}m")
        print("  PASSED ✓")
    except Exception as e:
        print(f"  FAILED: {e}")

    print("\n" + "=" * 55)
    print("All tests done. Ready for Module 6 — FastAPI endpoints.")
    print("=" * 55)


if __name__ == "__main__":
    test_routing()
