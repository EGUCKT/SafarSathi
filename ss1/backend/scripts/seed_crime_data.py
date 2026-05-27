"""
SafarSathi — Crime Data Seeder for Indore + Mhow

Since live crime APIs for India require special permissions,
this script does two things:
1. Seeds realistic synthetic crime data for Indore (for development/demo)
2. Shows you exactly how to plug in real data when you get it

Run after pipeline.py:
    cd saferoute/backend
    python scripts/seed_crime_data.py
"""

import os
import random
import numpy as np
from datetime import datetime, timedelta
from sqlalchemy import create_engine, text
from dotenv import load_dotenv

load_dotenv()

DATABASE_URL = os.getenv("DATABASE_URL")
engine = create_engine(DATABASE_URL)

# ── Real high-risk areas in Indore (based on public reports) ─────────────────
# Source: News reports, public safety surveys
# Format: (lat, lng, risk_level, area_name)

INDORE_RISK_ZONES = [
    # Higher risk areas (crowded markets, isolated roads at night)
    (22.7196, 75.8577, "high",   "Khajrana area"),
    (22.7063, 75.8416, "high",   "Chandan Nagar isolated stretch"),
    (22.7350, 75.8820, "medium", "Rajwada market night"),
    (22.7179, 75.8673, "medium", "MG Road late night"),
    (22.6900, 75.8500, "high",   "Sanwer Road isolated"),
    (22.7533, 75.8877, "low",    "Vijay Nagar main road"),
    (22.7400, 75.8900, "low",    "Scheme 54 residential"),
    (22.7250, 75.8750, "medium", "Palasia junction"),
    (22.7100, 75.8600, "high",   "Lohamandi isolated lanes"),
    (22.7300, 75.8400, "medium", "Annapurna Road"),
    # Mhow areas
    (22.5523, 75.7640, "medium", "Mhow main market"),
    (22.5400, 75.7500, "high",   "Mhow outskirts"),
    (22.5600, 75.7700, "low",    "Mhow cantonment area"),
]

CRIME_TYPES = [
    ("theft",           1),
    ("harassment",      2),
    ("chain_snatching", 2),
    ("assault",         3),
    ("eve_teasing",     2),
    ("robbery",         3),
    ("suspicious",      1),
]

RISK_TO_COUNT = {"high": 40, "medium": 20, "low": 8}


def log(msg):
    print(f"[CrimeSeed] {msg}")


def generate_synthetic_crime_data():
    """
    Generates realistic-looking crime incidents clustered around
    known risk zones in Indore. This is for development and demo.
    Replace with real data when available.
    """
    log("Generating synthetic crime data for Indore + Mhow...")
    records = []

    for lat, lng, risk, area in INDORE_RISK_ZONES:
        count = RISK_TO_COUNT[risk]
        for _ in range(count):
            # Scatter incidents within ~500m of the zone center
            offset_lat = random.gauss(0, 0.003)
            offset_lng = random.gauss(0, 0.003)

            crime_type, severity = random.choice(CRIME_TYPES)
            if risk == "high":
                severity = min(3, severity + 1)

            # Random time in last 6 months, weighted toward night
            days_ago = random.randint(1, 180)
            hour = random.choices(
                range(24),
                weights=[1,1,1,1,1,1,2,2,3,3,3,3,3,3,3,3,4,4,5,5,6,6,5,3],
                k=1
            )[0]
            occurred = datetime.now() - timedelta(days=days_ago, hours=(23 - hour))

            records.append({
                "crime_type":  crime_type,
                "lat":         lat + offset_lat,
                "lng":         lng + offset_lng,
                "occurred_at": occurred,
                "severity":    severity,
                "verified":    risk in ("high", "medium"),
            })

    log(f"  Generated {len(records)} synthetic crime incidents")
    return records


def insert_crime_data(records):
    """Inserts crime records into the crime_incidents table."""
    log("Inserting into database...")
    inserted = 0

    with engine.connect() as conn:
        for r in records:
            try:
                conn.execute(text("""
                    INSERT INTO crime_incidents
                        (crime_type, location, occurred_at, severity, verified)
                    VALUES (
                        :crime_type,
                        ST_SetSRID(ST_MakePoint(:lng, :lat), 4326),
                        :occurred_at,
                        :severity,
                        :verified
                    )
                """), r)
                inserted += 1
            except Exception as e:
                continue
        conn.commit()

    log(f"Inserted {inserted} crime records")


def update_crime_density_scores():
    """
    For each road segment, calculates crime density from nearby incidents.
    Uses PostGIS to count incidents within 200m, normalizes to 0-1.
    Higher crime_density = MORE dangerous (inverse of safety).
    """
    log("Updating crime_density scores for all road segments...")
    log("  (PostGIS spatial query — takes ~1 minute)")

    with engine.connect() as conn:
        conn.execute(text("""
            WITH crime_counts AS (
                SELECT
                    rs.id,
                    COUNT(ci.id) AS crime_count,
                    SUM(ci.severity) AS severity_sum
                FROM road_segments rs
                LEFT JOIN crime_incidents ci
                    ON ST_DWithin(
                        rs.geom::geography,
                        ci.location::geography,
                        200         -- 200 metre radius
                    )
                    AND ci.occurred_at > NOW() - INTERVAL '6 months'
                GROUP BY rs.id
            ),
            normalized AS (
                SELECT
                    id,
                    crime_count,
                    -- Normalize: 0 incidents = 0.0, 10+ = 1.0
                    LEAST(1.0, COALESCE(severity_sum, 0)::float / 20.0) AS crime_density
                FROM crime_counts
            )
            UPDATE road_segments rs
            SET crime_density = n.crime_density,
                -- Recompute safety score with updated crime data
                -- S = 0.4*(1-C) + 0.3*L + 0.2*P + 0.1*R
                safety_score = GREATEST(0.05,
                    0.4 * (1.0 - n.crime_density) +
                    0.3 * rs.lighting_score +
                    0.2 * rs.crowd_score +
                    0.1 * rs.user_rating
                ),
                last_updated = NOW()
            FROM normalized n
            WHERE rs.id = n.id
        """))
        conn.commit()

    log("Crime density scores updated")
    log("Safety scores recalculated for all segments")


def show_real_data_instructions():
    """Prints instructions for plugging in real crime data."""
    log("")
    log("=" * 55)
    log("HOW TO USE REAL CRIME DATA (when available)")
    log("=" * 55)
    log("Option 1: data.gov.in")
    log("  → Search 'crime statistics Madhya Pradesh'")
    log("  → Download CSV → map columns to our schema")
    log("  → Replace generate_synthetic_crime_data() with CSV reader")
    log("")
    log("Option 2: Indore Police Portal")
    log("  → Contact Indore Police Commissionerate for data sharing")
    log("  → They often share anonymized data for research projects")
    log("")
    log("Option 3: Manual entry via Admin Dashboard")
    log("  → Module 9 (Admin Dashboard) has a crime entry form")
    log("  → Local volunteers / NGOs can add verified incidents")
    log("=" * 55)


if __name__ == "__main__":
    if not DATABASE_URL:
        print("ERROR: DATABASE_URL not set in .env")
        exit(1)

    records = generate_synthetic_crime_data()
    insert_crime_data(records)
    update_crime_density_scores()
    show_real_data_instructions()

    print("\n[CrimeSeed] Done! crime_incidents table is populated.")
    print("[CrimeSeed] road_segments.crime_density and safety_score updated.")
    print("[CrimeSeed] Ready for Module 4 — ML Safety Score training.")
