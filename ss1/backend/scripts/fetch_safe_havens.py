"""
SafarSathi — Safe Havens Fetcher (Google Places API)
Fetches police stations, hospitals, pharmacies etc. near Indore + Mhow
and inserts them into the safe_havens table.

Run after pipeline.py:
    cd saferoute/backend
    python scripts/fetch_safe_havens.py
"""

import os
import httpx
import time
from sqlalchemy import create_engine, text
from dotenv import load_dotenv

load_dotenv()

DATABASE_URL      = os.getenv("DATABASE_URL")
GOOGLE_PLACES_KEY = os.getenv("GOOGLE_PLACES_API_KEY")
engine            = create_engine(DATABASE_URL)

# Search centers: Indore city center + Mhow
SEARCH_CENTERS = [
    {"lat": 22.7196, "lng": 75.8577, "label": "Indore"},
    {"lat": 22.5523, "lng": 75.7640, "label": "Mhow"},
]

PLACE_TYPES = [
    ("police",           "police_station"),
    ("hospital",         "hospital"),
    ("pharmacy",         "pharmacy"),
    ("fire_station",     "fire_station"),
]

RADIUS = 10000  # 10km radius from each center


def log(msg):
    print(f"[SafeHavens] {msg}")


def fetch_places(lat, lng, place_type, api_type):
    """Calls Google Places Nearby Search API."""
    url = "https://maps.googleapis.com/maps/api/place/nearbysearch/json"
    params = {
        "location": f"{lat},{lng}",
        "radius":   RADIUS,
        "type":     api_type,
        "key":      GOOGLE_PLACES_KEY,
    }
    try:
        response = httpx.get(url, params=params, timeout=10)
        data = response.json()
        if data.get("status") not in ("OK", "ZERO_RESULTS"):
            log(f"  API error: {data.get('status')} — {data.get('error_message', '')}")
            return []
        return data.get("results", [])
    except Exception as e:
        log(f"  Request failed: {e}")
        return []


def insert_safe_havens(places, place_type):
    """Inserts fetched places into safe_havens table."""
    inserted = 0
    with engine.connect() as conn:
        for place in places:
            try:
                loc  = place["geometry"]["location"]
                name = place.get("name", "Unknown")
                addr = place.get("vicinity", "")
                pid  = place.get("place_id", "")
                # Consider 24hr if open_now or opening_hours not restricted
                hours = place.get("opening_hours", {})
                is_24 = place_type in ("police_station", "hospital", "fire_station")

                conn.execute(text("""
                    INSERT INTO safe_havens
                        (name, place_type, location, address, is_24hr, google_place_id)
                    VALUES (
                        :name, :place_type,
                        ST_SetSRID(ST_MakePoint(:lng, :lat), 4326),
                        :address, :is_24hr, :google_place_id
                    )
                    ON CONFLICT DO NOTHING
                """), {
                    "name":            name,
                    "place_type":      place_type,
                    "lat":             loc["lat"],
                    "lng":             loc["lng"],
                    "address":         addr,
                    "is_24hr":         is_24,
                    "google_place_id": pid,
                })
                inserted += 1
            except Exception:
                continue
        conn.commit()
    return inserted


def main():
    log("Fetching safe havens for Indore + Mhow...")

    if not GOOGLE_PLACES_KEY:
        log("WARNING: GOOGLE_PLACES_API_KEY not set")
        log("Skipping Google Places fetch — using seeded data from schema.sql only")
        log("Add your API key to .env and re-run to get full data")
        return

    total = 0
    for center in SEARCH_CENTERS:
        log(f"\nSearching near {center['label']}...")
        for api_type, db_type in PLACE_TYPES:
            log(f"  Fetching {api_type}s...")
            places = fetch_places(center["lat"], center["lng"], db_type, api_type)
            count  = insert_safe_havens(places, db_type)
            log(f"  Inserted {count} {db_type}s")
            total += count
            time.sleep(0.2)  # be polite to the API

    log(f"\nDone! Total safe havens inserted: {total}")
    log("View them in Supabase → Table Editor → safe_havens")


if __name__ == "__main__":
    main()
