"""
SafarSathi — Download Mhow–Indore corridor roads
Fills the gap between Mhow and Indore so 30km routes work.

Run:
    cd safarsathi/backend
    python scripts/download_corridor.py
"""

import os, sys, time
import osmnx as ox
import networkx as nx
import pandas as pd
from sqlalchemy import create_engine, text
from dotenv import load_dotenv

load_dotenv()
DATABASE_URL = os.getenv("DATABASE_URL")
DATA_DIR = os.path.join(os.path.dirname(__file__), "..", "data", "processed")
engine = create_engine(DATABASE_URL)

def log(msg): print(f"[Corridor] {msg}")

def highway_safety(hw):
    m = {"primary":0.75,"secondary":0.70,"tertiary":0.65,"residential":0.60,
         "trunk":0.72,"motorway":0.80,"unclassified":0.50,"service":0.50}
    for k,v in m.items():
        if k in hw: return v
    return 0.50

# Points along the NH-52 / AB Road corridor Mhow → Indore
# Spaced ~5km apart so coverage overlaps
CORRIDOR = [
    (22.5560, 75.7640, 3000, "Mhow College"),
    (22.5800, 75.7900, 2000, "Mhow-Indore Road 1"),
    (22.6100, 75.8100, 2000, "Mhow-Indore Road 2"),
    (22.6400, 75.8300, 2000, "Mhow-Indore Road 3"),
    (22.6700, 75.8400, 2000, "Mhow-Indore Road 4"),
    (22.7000, 75.8500, 2000, "South Indore"),
    (22.7196, 75.8577, 3000, "Indore Center"),
    (22.7400, 75.8700, 2000, "Indore North"),
    (22.7533, 75.8877, 2000, "Vijay Nagar"),
]

def download():
    log("Downloading Mhow–Indore corridor...")
    graphs = []
    for lat, lng, radius, label in CORRIDOR:
        log(f"  {label}...")
        try:
            G = ox.graph_from_point((lat, lng), dist=radius,
                network_type="all", simplify=True, retain_all=False)
            log(f"    {len(G.edges)} edges")
            graphs.append(G)
        except Exception as e:
            log(f"    Skipped: {e}")
        time.sleep(1)

    combined = graphs[0]
    for g in graphs[1:]:
        combined = nx.compose(combined, g)
    log(f"Combined: {len(combined.nodes)} nodes, {len(combined.edges)} edges")
    return combined

def insert(G):
    edges = ox.graph_to_gdfs(G, nodes=False, edges=True).reset_index()
    segments = []
    seen = set()
    for _, row in edges.iterrows():
        try:
            geom = row.geometry
            if geom is None or geom.is_empty: continue
            hw = row.get("highway", "unclassified")
            if isinstance(hw, list): hw = hw[0]
            osm_id = row.get("osmid", None)
            if isinstance(osm_id, list): osm_id = osm_id[0]
            if osm_id in seen: continue
            seen.add(osm_id)
            name = row.get("name", None)
            if isinstance(name, list): name = name[0]
            safety = highway_safety(str(hw))
            segments.append({
                "osm_id": int(osm_id) if osm_id and not pd.isna(osm_id) else None,
                "name": str(name) if name and not pd.isna(name) else None,
                "highway_type": str(hw), "geom_wkt": geom.wkt,
                "crime_density": 0.4, "lighting_score": safety,
                "crowd_score": safety, "user_rating": 0.5,
                "safety_score": safety,
                "length_meters": float(row.get("length", 0) or 0),
            })
        except: continue

    log(f"Inserting {len(segments)} new segments (skipping duplicates)...")
    inserted = 0
    with engine.connect() as conn:
        for i in range(0, len(segments), 200):
            batch = segments[i:i+200]
            for s in batch:
                try:
                    conn.execute(text("""
                        INSERT INTO road_segments
                          (osm_id,name,highway_type,geom,crime_density,
                           lighting_score,crowd_score,user_rating,safety_score,length_meters)
                        VALUES (:osm_id,:name,:highway_type,
                           ST_GeomFromText(:geom_wkt,4326),
                           :crime_density,:lighting_score,:crowd_score,
                           :user_rating,:safety_score,:length_meters)
                        ON CONFLICT (osm_id) DO NOTHING
                    """), s)
                    inserted += 1
                except: continue
            conn.commit()
    log(f"Inserted {inserted} segments")
    return G

def save(G):
    path = os.path.join(DATA_DIR, "indore_mhow_graph.graphml")
    ox.save_graphml(G, path)
    log(f"Graph saved: {path}")

if __name__ == "__main__":
    if not DATABASE_URL:
        print("ERROR: DATABASE_URL not set"); sys.exit(1)
    G = download()
    insert(G)
    save(G)
    log("Done. Now re-run: python ml/train_safety_model.py")
    log("Then restart: uvicorn main:app --reload")
