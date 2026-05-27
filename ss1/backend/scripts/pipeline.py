"""
SafarSathi — Pipeline v3 (Completely Free, Mhow College Focused)
No Google Maps, No API keys, No card needed.
Uses OpenStreetMap + Overpass API (both 100% free).
Focused on Sushila Devi Bansal College of Engineering, Mhow (453331)

Run:
    cd saferoute/backend
    python scripts/pipeline.py
"""

import os, sys, time, random
import osmnx as ox
import pandas as pd
import httpx
import networkx as nx
from sqlalchemy import create_engine, text
from dotenv import load_dotenv

load_dotenv()

DATABASE_URL = os.getenv("DATABASE_URL")
DATA_DIR = os.path.join(os.path.dirname(__file__), "..", "data", "processed")
os.makedirs(DATA_DIR, exist_ok=True)
engine = create_engine(DATABASE_URL)

# FOCAL POINT: Sushila Devi Bansal College of Engineering, Mhow
COLLEGE_LAT = 22.5560
COLLEGE_LNG = 75.7640

# Midpoint between Mhow and Indore to cover both in a single continuous graph
# This ensures routing works across the highway connecting the two.
COVERAGE_MIDPOINT = (22.6500, 75.8200)
COVERAGE_RADIUS = 15000  # 15km radius covers both Mhow and Indore perfectly

def log(msg): print(f"[SafarSathi] {msg}")

def highway_safety_estimate(hw):
    m = {"primary":0.75,"secondary":0.70,"tertiary":0.65,"residential":0.60,
         "living_street":0.65,"pedestrian":0.55,"footway":0.45,"path":0.40,
         "service":0.50,"trunk":0.70,"motorway":0.80,"unclassified":0.50}
    for k,v in m.items():
        if k in hw: return v
    return 0.50

def download_street_network():
    log("Downloading continuous street network for Indore & Mhow region...")
    try:
        # A single continuous graph is required for Dijkstra routing between cities
        G = ox.graph_from_point(COVERAGE_MIDPOINT, dist=COVERAGE_RADIUS,
            network_type="all", simplify=True, retain_all=False)
        log(f"  Graph downloaded: {len(G.nodes)} nodes, {len(G.edges)} edges")
        return G
    except Exception as e:
        raise RuntimeError(f"Graph download failed: {e}")

def extract_road_segments(G):
    log("Extracting road segments...")
    edges = ox.graph_to_gdfs(G, nodes=False, edges=True).reset_index()
    segments = []
    seen = set()
    for _,row in edges.iterrows():
        try:
            geom = row.geometry
            if geom is None or geom.is_empty: continue
            hw = row.get("highway","unclassified")
            if isinstance(hw,list): hw = hw[0]
            osm_id = row.get("osmid",None)
            if isinstance(osm_id,list): osm_id = osm_id[0]
            if osm_id in seen: continue
            seen.add(osm_id)
            name = row.get("name",None)
            if isinstance(name,list): name = name[0]
            safety = highway_safety_estimate(str(hw))
            segments.append({
                "osm_id": int(osm_id) if osm_id and not pd.isna(osm_id) else None,
                "name": str(name) if name and not pd.isna(name) else None,
                "highway_type": str(hw), "geom_wkt": geom.wkt,
                "crime_density":0.5,"lighting_score":safety,"crowd_score":safety,
                "user_rating":0.5,"safety_score":safety,
                "length_meters":float(row.get("length",0) or 0),
            })
        except: continue
    log(f"  {len(segments)} valid segments")
    return segments

def insert_road_segments(segments):
    log("Inserting road segments...")
    with engine.connect() as conn:
        conn.execute(text("DELETE FROM road_segments"))
        conn.commit()
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
                        ON CONFLICT (osm_id) DO UPDATE
                          SET safety_score=EXCLUDED.safety_score,last_updated=NOW()
                    """), s)
                    inserted += 1
                except: continue
            conn.commit()
            log(f"  {min(100,round((i+200)/len(segments)*100))}% — {inserted} inserted")
    log(f"Road segments done: {inserted}")

def generate_and_insert_streetlights():
    log("Generating realistic streetlights based on road types...")
    log("  (OSM has no streetlight data for Mhow — generating from road network)")
    with engine.connect() as conn:
        conn.execute(text("DELETE FROM streetlights"))
        conn.commit()
        result = conn.execute(text(
            "SELECT id,highway_type,ST_AsText(geom) as geom_wkt,length_meters FROM road_segments"
        ))
        roads = result.fetchall()
    log(f"  Processing {len(roads)} road segments...")
    spacing_map = {
        "primary":35,"secondary":40,"tertiary":50,"residential":80,
        "living_street":70,"pedestrian":60,"service":100,
        "footway":200,"path":300,"unclassified":90,"trunk":30,
    }
    from shapely import wkt as swkt
    lights = []
    for road in roads:
        try:
            hw = road.highway_type or "unclassified"
            spacing = 90
            for k,v in spacing_map.items():
                if k in hw: spacing = v; break
            length = road.length_meters or 0
            if length < 20: continue
            line = swkt.loads(road.geom_wkt)
            n = max(1, int(length/spacing))
            for i in range(n):
                pt = line.interpolate((i+0.5)/n, normalized=True)
                lights.append({
                    "lat": pt.y + random.gauss(0,0.00003),
                    "lng": pt.x + random.gauss(0,0.00003),
                })
        except: continue
    log(f"  Generated {len(lights)} streetlights")
    inserted = 0
    with engine.connect() as conn:
        for lt in lights:
            try:
                conn.execute(text("""
                    INSERT INTO streetlights (location)
                    VALUES (ST_SetSRID(ST_MakePoint(:lng,:lat),4326))
                """), lt)
                inserted += 1
            except: continue
        conn.commit()
    log(f"  Streetlights inserted: {inserted}")

def fetch_safe_havens_overpass():
    log("Fetching safe havens via Overpass API (free, no key needed)...")
    query = f"""
    [out:json][timeout:30];
    (
      node["amenity"="police"](around:15000,{COLLEGE_LAT},{COLLEGE_LNG});
      node["amenity"="hospital"](around:15000,{COLLEGE_LAT},{COLLEGE_LNG});
      node["amenity"="clinic"](around:15000,{COLLEGE_LAT},{COLLEGE_LNG});
      node["amenity"="pharmacy"](around:15000,{COLLEGE_LAT},{COLLEGE_LNG});
      node["amenity"="fire_station"](around:15000,{COLLEGE_LAT},{COLLEGE_LNG});
      way["amenity"="police"](around:15000,{COLLEGE_LAT},{COLLEGE_LNG});
      way["amenity"="hospital"](around:15000,{COLLEGE_LAT},{COLLEGE_LNG});
    );
    out center;
    """
    amenity_to_type = {
        "police":"police_station","hospital":"hospital","clinic":"hospital",
        "pharmacy":"pharmacy","fire_station":"fire_station","doctors":"hospital",
    }
    elements = []
    try:
        resp = httpx.post("https://overpass-api.de/api/interpreter",
                          data={"data":query}, timeout=40)
        elements = resp.json().get("elements",[])
        log(f"  Overpass returned {len(elements)} places")
    except Exception as e:
        log(f"  Overpass failed: {e} — using hardcoded only")

    with engine.connect() as conn:
        conn.execute(text("DELETE FROM safe_havens"))
        conn.commit()
        inserted = 0
        for el in elements:
            try:
                tags = el.get("tags",{})
                name = tags.get("name") or tags.get("name:en") or "Unknown"
                amenity = tags.get("amenity","")
                ptype = amenity_to_type.get(amenity,"hospital")
                lat = el["lat"] if el["type"]=="node" else el.get("center",{}).get("lat")
                lng = el["lon"] if el["type"]=="node" else el.get("center",{}).get("lon")
                if not lat: continue
                is24 = ptype in ("police_station","hospital","fire_station")
                conn.execute(text("""
                    INSERT INTO safe_havens (name,place_type,location,address,is_24hr)
                    VALUES (:name,:place_type,ST_SetSRID(ST_MakePoint(:lng,:lat),4326),:address,:is_24hr)
                    ON CONFLICT DO NOTHING
                """), {"name":name,"place_type":ptype,"lat":lat,"lng":lng,
                       "address":tags.get("addr:street",""),"is_24hr":is24})
                inserted += 1
            except: continue

        # Hardcoded verified Mhow locations — always inserted
        hardcoded = [
            ("Sushila Devi Bansal College of Engineering","safe_haven",22.5560,75.7640,"Mhow 453331",False),
            ("Mhow Police Station","police_station",22.5523,75.7580,"Mhow, MP",True),
            ("Mhow Civil Hospital","hospital",22.5510,75.7620,"Mhow, MP",True),
            ("Mhow Cantonment Hospital","hospital",22.5650,75.7720,"Cantonment, Mhow",True),
            ("Mhow Fire Station","fire_station",22.5530,75.7600,"Mhow, MP",True),
            ("Mhow Bus Stand","safe_haven",22.5545,75.7568,"Mhow Bus Stand",False),
            ("Military Hospital Mhow","hospital",22.5680,75.7740,"Cantonment, Mhow",True),
            ("Mhow Railway Station","safe_haven",22.5498,75.7542,"Mhow Station Road",False),
            ("Mhow Market Police Chowki","police_station",22.5540,75.7570,"Mhow Market",True),
            ("Govt Higher Sec School Mhow","safe_haven",22.5530,75.7650,"Mhow",False),
            ("Vijay Nagar Police Station","police_station",22.7533,75.8877,"Vijay Nagar, Indore",True),
            ("MB Hospital Indore","hospital",22.7196,75.8681,"Residency, Indore",True),
        ]
        for name,ptype,lat,lng,addr,is24 in hardcoded:
            try:
                conn.execute(text("""
                    INSERT INTO safe_havens (name,place_type,location,address,is_24hr)
                    VALUES (:name,:place_type,ST_SetSRID(ST_MakePoint(:lng,:lat),4326),:address,:is_24hr)
                    ON CONFLICT DO NOTHING
                """), {"name":name,"place_type":ptype,"lat":lat,"lng":lng,
                       "address":addr,"is_24hr":is24})
            except: continue
        conn.commit()
    log(f"  Safe havens done: {inserted} from OSM + {len(hardcoded)} hardcoded")

def update_lighting_scores():
    """
    Runs in small batches of 500 segments to avoid Supabase's statement timeout.
    Each batch processes 500 road segments at a time.
    """
    log("Updating lighting scores in batches (timeout-safe)...")

    # Get all segment IDs first
    with engine.connect() as conn:
        result = conn.execute(text("SELECT id FROM road_segments ORDER BY id"))
        all_ids = [row[0] for row in result.fetchall()]

    log(f"  Processing {len(all_ids)} segments in batches of 500...")

    BATCH = 500
    updated = 0

    for i in range(0, len(all_ids), BATCH):
        batch_ids = all_ids[i:i + BATCH]
        id_list = ",".join(str(x) for x in batch_ids)

        try:
            with engine.connect() as conn:
                # Set timeout to 60s per batch
                conn.execute(text("SET statement_timeout = '60000'"))
                conn.execute(text(f"""
                    WITH lc AS (
                        SELECT rs.id, COUNT(sl.id) AS n
                        FROM road_segments rs
                        LEFT JOIN streetlights sl
                          ON ST_DWithin(
                              rs.geom::geography,
                              sl.location::geography,
                              50
                          )
                        WHERE rs.id IN ({id_list})
                        GROUP BY rs.id
                    )
                    UPDATE road_segments rs
                    SET lighting_score = LEAST(1.0, 0.1 + (lc.n::float / 5.0) * 0.9),
                        last_updated   = NOW()
                    FROM lc
                    WHERE rs.id = lc.id
                """))
                conn.commit()
                updated += len(batch_ids)

            pct = min(100, round(updated / len(all_ids) * 100))
            log(f"  {pct}% lighting updated ({updated}/{len(all_ids)})")

        except Exception as e:
            log(f"  Batch {i//BATCH + 1} failed: {e} — skipping")
            continue

    log(f"  Lighting scores updated for {updated} segments")

def save_graph(G):
    path = os.path.join(DATA_DIR, "indore_mhow_graph.graphml")
    ox.save_graphml(G, path)
    log(f"Graph saved: {path}")

def main():
    t = time.time()
    log("="*60)
    log("SafarSathi Pipeline v3 — Mhow College Focus, 100% Free")
    log("="*60)
    if not DATABASE_URL:
        log("ERROR: DATABASE_URL not set in .env"); sys.exit(1)
    G = download_street_network()
    segments = extract_road_segments(G)
    insert_road_segments(segments)
    generate_and_insert_streetlights()
    fetch_safe_havens_overpass()
    update_lighting_scores()
    save_graph(G)
    log("="*60)
    log(f"Done in {round(time.time()-t,1)}s")
    log("Next: python scripts/seed_crime_data.py")
    log("="*60)

if __name__ == "__main__":
    main()