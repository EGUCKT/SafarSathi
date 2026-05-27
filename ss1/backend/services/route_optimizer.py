"""
SafarSathi — Module 05: Route Optimizer
Loads the Indore+Mhow street graph, assigns safety-weighted edge costs,
and finds the optimal route between two coordinates.

Edge weight formula:
    weight = distance_metres × (1 / safety_score)

A road with safety_score=0.2 costs 5× more than one with score=1.0
So Dijkstra naturally avoids unsafe roads even if they are shorter.

This module is imported by FastAPI (Module 6) — not run directly.
"""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
import os
import math
import time
import osmnx as ox
import networkx as nx
import numpy as np
from typing import Optional
from sqlalchemy import create_engine, text
from dotenv import load_dotenv

load_dotenv()

DATABASE_URL = os.getenv("DATABASE_URL")
DATA_DIR     = os.path.join(os.path.dirname(__file__), "..", "data", "processed")
GRAPH_PATH   = os.path.join(DATA_DIR, "indore_mhow_graph.graphml")

engine = create_engine(DATABASE_URL)


class RouteOptimizer:
    """
    Singleton that holds the street graph in memory.
    FastAPI loads this once on startup — graph stays in RAM.
    Finding a route then takes ~50ms instead of 5 seconds.
    """

    def __init__(self):
        self.G           = None   # original OSMnx graph
        self.G_weighted  = None   # graph with safety weights applied
        self.loaded      = False
        self.node_safety = {}     # cache: osm_node_id → safety_score

    # ── Load graph ────────────────────────────────────────────────────────────

    def load(self):
        """Load graph from disk and apply safety weights from DB."""
        if self.loaded:
            return

        print("[Router] Loading street graph...")
        t = time.time()

        if not os.path.exists(GRAPH_PATH):
            print(f"[Router] ERROR: Graph file not found at {GRAPH_PATH}")
            print("[Router] Run: python scripts/pipeline.py first")
            return

        # Load the saved OSMnx graph
        self.G = ox.load_graphml(GRAPH_PATH)
        print(f"[Router] Graph loaded: {len(self.G.nodes)} nodes, {len(self.G.edges)} edges")

        # Apply safety weights from database
        self._apply_safety_weights()

        self.loaded = True
        print(f"[Router] Ready in {round(time.time()-t, 2)}s")

    def _apply_safety_weights(self):
        """
        Fetches safety scores from DB and sets edge weights on the graph.
        weight = length_metres × (1 / safety_score)
        """
        print("[Router] Fetching safety scores from database...")

        with engine.connect() as conn:
            result = conn.execute(text("""
                SELECT osm_id, safety_score, length_meters,
                       crime_density, lighting_score
                FROM road_segments
                WHERE osm_id IS NOT NULL
            """))
            rows = result.fetchall()

        # Build lookup: osm_id → safety data
        safety_lookup = {}
        for row in rows:
            safety_lookup[row.osm_id] = {
                "safety_score":  max(0.05, float(row.safety_score or 0.5)),
                "length_meters": float(row.length_meters or 50),
                "crime_density": float(row.crime_density or 0.5),
                "lighting_score": float(row.lighting_score or 0.5),
            }

        print(f"[Router] Applying weights to {len(self.G.edges)} edges...")

        # Apply weights to each edge in the graph
        weighted_edges = 0
        for u, v, key, data in self.G.edges(data=True, keys=True):
            osm_id   = data.get("osmid")
            length   = data.get("length", 50)

            # Handle list osmids (OSMnx sometimes returns lists)
            if isinstance(osm_id, list):
                osm_id = osm_id[0]

            if osm_id and osm_id in safety_lookup:
                sd = safety_lookup[osm_id]
                safety = sd["safety_score"]
                weighted_edges += 1
            else:
                safety = 0.5  # default for unmapped edges
                length = data.get("length", 50)

            # THE CORE FORMULA:
            # weight = distance × (1 / safety)
            # → unsafe road (safety=0.1): weight = distance × 10
            # → safe road   (safety=1.0): weight = distance × 1
            safety_weight = float(length) * (1.0 / safety)

            self.G.edges[u, v, key]["safety_weight"] = safety_weight
            self.G.edges[u, v, key]["safety_score"]  = safety
            self.G.edges[u, v, key]["length"]        = float(length)

        print(f"[Router] Weighted {weighted_edges}/{len(self.G.edges)} edges from DB")
        self.G_weighted = self.G

    def refresh_weights(self):
        """
        Call this after new crowd reports come in to re-apply weights.
        Takes ~2 seconds — call in background thread, not in request handler.
        """
        print("[Router] Refreshing safety weights...")
        self._apply_safety_weights()
        print("[Router] Weights refreshed")


    # ── Core routing ──────────────────────────────────────────────────────────

    def find_nearest_node(self, lat: float, lng: float) -> int:
        """Snaps a coordinate to the nearest graph node."""
        if not self.loaded:
            raise RuntimeError("Router not loaded. Call load() first.")
        return ox.distance.nearest_nodes(self.G, X=lng, Y=lat)

    def find_safest_route(
        self,
        origin_lat: float,
        origin_lng: float,
        dest_lat: float,
        dest_lng: float,
        preference: str = "balanced",   # "safest" | "shortest" | "balanced"
        hour: int = None,
        avoid_nodes: set = None,
    ) -> Optional[dict]:
        """
        Main routing function. Returns a route dict with:
        - coordinates: list of (lat, lng) points forming the path
        - total_distance_m: total distance in metres
        - safety_score: average safety score of the route (0-1)
        - segments: per-segment safety data for map coloring
        - duration_minutes: estimated walking/travel time

        Args:
            preference: "safest"   → pure safety weight (avoids any unsafe road)
                        "shortest" → pure distance (ignores safety)
                        "balanced" → 70% safety + 30% distance (recommended)
        """
        if not self.loaded:
            raise RuntimeError("Router not loaded. Call load() first.")

        if hour is None:
            from datetime import datetime
            hour = datetime.now().hour

        # Snap coordinates to nearest graph nodes
        try:
            origin_node = self.find_nearest_node(origin_lat, origin_lng)
            dest_node   = self.find_nearest_node(dest_lat, dest_lng)
        except Exception as e:
            raise ValueError(f"Could not find nodes near coordinates: {e}")

        if origin_node == dest_node:
            raise ValueError("Origin and destination are the same location.")

        # Choose weight function based on preference
        weight_key = self._get_weight_key(preference, hour)

        def weight_func(u, v, d):
            base_w = min((edge_data.get(weight_key, 999999) for edge_data in d.values()), default=999999)
            if avoid_nodes and (u in avoid_nodes or v in avoid_nodes):
                return base_w * 10.0  # Increased from 3x to 10x for stronger detours
            return base_w

        try:
            # Run Dijkstra's algorithm
            node_path = nx.shortest_path(
                self.G_weighted,
                source=origin_node,
                target=dest_node,
                weight=weight_func,
            )
        except nx.NetworkXNoPath:
            # Fallback to OSRM Public API for inter-city/disconnected routes
            import requests
            try:
                res = requests.get(f"https://router.project-osrm.org/route/v1/driving/{origin_lng},{origin_lat};{dest_lng},{dest_lat}?overview=full&geometries=geojson")
                data = res.json()
                if data.get("code") != "Ok":
                    raise ValueError("No path found between these two locations.")
                
                route_coords = [{"lat": c[1], "lng": c[0]} for c in data["routes"][0]["geometry"]["coordinates"]]
                dist_m = data["routes"][0]["distance"]
                dur_m  = data["routes"][0]["duration"] / 60.0
                
                return {
                    "coordinates":          route_coords,
                    "total_distance_m":     round(dist_m, 1),
                    "overall_safety_score": 0.5, # Default moderate safety
                    "safety_label":         self._safety_label(0.5),
                    "walk_minutes":         max(1, round(dist_m / 80)),
                    "drive_minutes":        max(1, round(dur_m)),
                    "segments":             [{
                        "from_lat": route_coords[0]["lat"],
                        "from_lng": route_coords[0]["lng"],
                        "safety_score": 0.5,
                        "length_m": round(dist_m, 1),
                        "road_name": "Intercity Route",
                        "color": "#F39C12" # Moderate orange
                    }],
                    "node_count":           len(route_coords),
                }
            except Exception as e:
                raise ValueError("No path found between these two locations.")
        except nx.NodeNotFound as e:
            raise ValueError(f"Node not found in graph: {e}")

        # Build response from node path
        return self._build_route_response(node_path, preference)

    def find_alternative_routes(
        self,
        origin_lat: float, origin_lng: float,
        dest_lat: float,   dest_lng: float,
    ) -> list[dict]:
        """
        Returns distinct route options: Safest, Balanced, Shortest.
        Uses soft edge penalties and deduplication to ensure variety.
        If fewer than 3 routes are found, it tries a 'Deep Search' workaround.
        """
        unique_routes = []
        seen_sigs = set()
        avoid_nodes = set()

        # 1. Standard search for Safest, Balanced, Shortest
        for preference in ["safest", "balanced", "shortest"]:
            try:
                route = self.find_safest_route(
                    origin_lat, origin_lng,
                    dest_lat,   dest_lng,
                    preference=preference,
                    avoid_nodes=avoid_nodes
                )
                route["preference"] = preference
                
                # Deduplication signature
                coords = route["coordinates"]
                step = max(1, len(coords) // 10)
                sig = tuple((round(c["lat"], 5), round(c["lng"], 5)) for c in coords[::step])
                
                if sig not in seen_sigs:
                    seen_sigs.add(sig)
                    unique_routes.append(route)
                    
                    # Add nodes to avoid list for the next preference
                    path_nodes = route.get("node_path", [])
                    if len(path_nodes) > 10:
                        avoid_nodes.update(path_nodes[3:-3])
                    elif len(path_nodes) > 4:
                        avoid_nodes.update(path_nodes[1:-1])

            except Exception as e:
                print(f"[Router] {preference} route failed: {e}")

        # 2. Workaround: If we have < 3 routes, force a "Deep Search" detour
        # We use a massive 50x penalty to find any possible alternative path
        if len(unique_routes) < 3 and len(unique_routes) > 0:
            try:
                route = self.find_safest_route(
                    origin_lat, origin_lng,
                    dest_lat,   dest_lng,
                    preference="balanced",
                    avoid_nodes=avoid_nodes # Already contains nodes from first 1-2 routes
                )
                route["preference"] = "workaround"
                
                coords = route["coordinates"]
                step = max(1, len(coords) // 10)
                sig = tuple((round(c["lat"], 5), round(c["lng"], 5)) for c in coords[::step])
                
                if sig not in seen_sigs:
                    seen_sigs.add(sig)
                    unique_routes.append(route)
            except:
                pass # No more paths physically possible

        return unique_routes[:3] # Ensure we don't return too many

    def _get_weight_key(self, preference: str, hour: int) -> str:
        """Returns which edge weight attribute to use for routing."""
        if preference == "safest":
            return "safety_weight"   # pure safety weighting
        elif preference == "shortest":
            return "length"          # pure distance
        else:
            # "balanced" — we pre-compute a blended weight below
            self._apply_balanced_weights(hour)
            return "balanced_weight"

    def _apply_balanced_weights(self, hour: int):
        """
        Blends safety and distance based on time of day.
        Night: 80% safety, 20% distance
        Day:   60% safety, 40% distance
        """
        if 20 <= hour or hour < 6:   # night
            safety_w, dist_w = 0.80, 0.20
        elif 6 <= hour < 9:          # early morning
            safety_w, dist_w = 0.70, 0.30
        else:                        # day / evening
            safety_w, dist_w = 0.60, 0.40

        for u, v, key, data in self.G_weighted.edges(data=True, keys=True):
            length       = data.get("length", 50)
            safety       = data.get("safety_score", 0.5)
            safety_cost  = length * (1.0 / safety)    # safety component
            dist_cost    = length                      # distance component

            blended = (safety_w * safety_cost) + (dist_w * dist_cost)
            self.G_weighted.edges[u, v, key]["balanced_weight"] = blended

    def _build_route_response(self, node_path: list, preference: str) -> dict:
        """
        Converts a list of OSMnx node IDs into a rich route response dict.
        """
        coordinates      = []
        total_distance   = 0.0
        safety_scores    = []
        segments         = []

        for i in range(len(node_path) - 1):
            u = node_path[i]
            v = node_path[i + 1]

            # Get node coordinates (fallback)
            u_data = self.G.nodes[u]
            
            # Get edge data
            edge_data   = self._get_best_edge(u, v)
            
            # If the edge has a geometry LineString, use it for perfect road curvature
            if "geometry" in edge_data:
                for pt in edge_data["geometry"].coords:
                    coordinates.append({"lat": pt[1], "lng": pt[0]})
            else:
                coordinates.append({"lat": u_data["y"], "lng": u_data["x"]})

            length      = edge_data.get("length", 50)
            safety      = edge_data.get("safety_score", 0.5)
            name        = edge_data.get("name", "Unknown Road")
            hw_type     = edge_data.get("highway", "road")

            total_distance += length
            safety_scores.append(safety)

            segments.append({
                "from_lat":     u_data["y"],
                "from_lng":     u_data["x"],
                "safety_score": round(safety, 3),
                "length_m":     round(length, 1),
                "road_name":    str(name) if name else "Unknown Road",
                "color":        self._safety_color(safety),
            })

        # Add final destination node
        last = self.G.nodes[node_path[-1]]
        coordinates.append({"lat": last["y"], "lng": last["x"]})

        avg_safety = float(np.mean(safety_scores)) if safety_scores else 0.5

        # Estimate duration: walking ~80m/min, vehicle ~500m/min
        walk_minutes  = round(total_distance / 80)
        drive_minutes = round(total_distance / 500)

        return {
            "coordinates":          coordinates,
            "total_distance_m":     round(total_distance, 1),
            "overall_safety_score": round(avg_safety, 3),
            "safety_label":         self._safety_label(avg_safety),
            "walk_minutes":         max(1, walk_minutes),
            "drive_minutes":        max(1, drive_minutes),
            "segments":             segments,
            "node_count":           len(node_path),
            "node_path":            node_path,  # Passed back for alternative route penalties
        }

    def _get_best_edge(self, u: int, v: int) -> dict:
        """Gets edge data between two nodes (handles multigraph)."""
        edges = self.G_weighted[u][v]
        if not edges:
            return {}
        # If multiple edges, pick the one with best safety
        best = max(edges.values(), key=lambda d: d.get("safety_score", 0))
        return best

    def _safety_color(self, score: float) -> str:
        """Returns hex color for map polyline coloring."""
        if score >= 0.75: return "#2ECC71"   # green
        elif score >= 0.55: return "#A8D5A2" # light green
        elif score >= 0.40: return "#F39C12" # orange
        elif score >= 0.25: return "#E67E22" # dark orange
        else: return "#E74C3C"               # red

    def _safety_label(self, score: float) -> str:
        if score >= 0.75: return "Very Safe"
        elif score >= 0.55: return "Safe"
        elif score >= 0.40: return "Moderate"
        elif score >= 0.25: return "Caution"
        else: return "Avoid if Possible"

    # ── Dead-man switch helper ────────────────────────────────────────────────

    def is_deviation(
        self,
        current_lat: float,
        current_lng: float,
        route_coords: list[dict],
        threshold_m: float = 100.0,
    ) -> tuple[bool, float]:
        """
        Checks if the user has deviated from the planned safe route.
        Used by the dead-man switch in the SOS module.

        Returns:
            (is_deviated: bool, min_distance_m: float)
        """
        if not route_coords:
            return False, 0.0

        min_dist = float("inf")
        for coord in route_coords:
            dist = self._haversine(
                current_lat, current_lng,
                coord["lat"], coord["lng"]
            )
            if dist < min_dist:
                min_dist = dist

        return (min_dist > threshold_m), round(min_dist, 1)

    def _haversine(self, lat1, lng1, lat2, lng2) -> float:
        """Calculates distance in metres between two lat/lng points."""
        R = 6371000  # Earth radius in metres
        phi1, phi2 = math.radians(lat1), math.radians(lat2)
        dphi = math.radians(lat2 - lat1)
        dlam = math.radians(lng2 - lng1)
        a = math.sin(dphi/2)**2 + math.cos(phi1)*math.cos(phi2)*math.sin(dlam/2)**2
        return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))


# Singleton instance — imported by FastAPI
router = RouteOptimizer()