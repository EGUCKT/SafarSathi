"""
SafarSathi — Admin Panel Endpoints (no auth required for hackathon demo)
GET /api/admin/reports        → all active reports with coords
GET /api/admin/area-stats     → reports grouped by area with threshold flags
"""
import sys, os, math
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..'))
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import text
from db import get_db

router = APIRouter()

# Report type metadata for the admin panel
REPORT_META = {
    "poor_lighting":       {"label": "Poor Lighting",  "color": "#FF9500", "is_negative": True,  "weight": 1},
    "harassment_incident": {"label": "Harassment",     "color": "#FF3B30", "is_negative": True,  "weight": 3},
    "unsafe_area":         {"label": "Unsafe Area",    "color": "#FF3B30", "is_negative": True,  "weight": 2},
    "safe_haven":          {"label": "Safe Haven",     "color": "#30D158", "is_negative": False, "weight": 2},
    "good_lighting":       {"label": "Good Lighting",  "color": "#FFD60A", "is_negative": False, "weight": 1},
    "police_presence":     {"label": "Police Here",    "color": "#007AFF", "is_negative": False, "weight": 2},
}

# Area clustering radius in degrees (~200m at India's latitude)
CLUSTER_RADIUS = 0.002

BAD_THRESHOLD  = 3   # 3+ weighted bad points  → permanent bad marker
GOOD_THRESHOLD = 5   # 5+ weighted good points → permanent good marker


def _cluster_key(lat: float, lng: float) -> tuple:
    """Snap coordinates to a grid cell for grouping. Using floor for consistency with JS."""
    return (math.floor(lat / CLUSTER_RADIUS) * CLUSTER_RADIUS,
            math.floor(lng / CLUSTER_RADIUS) * CLUSTER_RADIUS)


@router.get("/reports")
def get_all_reports(db: Session = Depends(get_db)):
    """Return every active (non-expired) report for the live map feed."""
    rows = db.execute(text("""
        SELECT
            id, report_type, description, upvotes, created_at,
            ST_Y(location::geometry) AS lat,
            ST_X(location::geometry) AS lng
        FROM crowd_reports
        WHERE is_active = TRUE AND expires_at > NOW()
        ORDER BY created_at DESC
        LIMIT 200
    """)).fetchall()

    reports = []
    for r in rows:
        meta = REPORT_META.get(r.report_type, {"label": r.report_type, "color": "#8E8E93", "is_negative": True, "weight": 1})
        reports.append({
            "id":          str(r.id),
            "report_type": r.report_type,
            "label":       meta["label"],
            "color":       meta["color"],
            "is_negative": meta["is_negative"],
            "description": r.description,
            "upvotes":     r.upvotes,
            "lat":         r.lat,
            "lng":         r.lng,
            "created_at":  r.created_at.isoformat(),
        })
    return {"reports": reports}


@router.get("/area-stats")
def get_area_stats(db: Session = Depends(get_db)):
    """Return reports grouped by area cluster with threshold flags."""
    rows = db.execute(text("""
        SELECT
            id, report_type, description, upvotes, created_at,
            ST_Y(location::geometry) AS lat,
            ST_X(location::geometry) AS lng
        FROM crowd_reports
        WHERE is_active = TRUE AND expires_at > NOW()
        ORDER BY created_at DESC
        LIMIT 500
    """)).fetchall()

    # Group into area clusters
    clusters: dict = {}
    for r in rows:
        key = _cluster_key(r.lat, r.lng)
        if key not in clusters:
            clusters[key] = {
                "lat": key[0], "lng": key[1],
                "reports": [],
                "bad_score": 0, "good_score": 0,
            }
        meta = REPORT_META.get(r.report_type, {"label": r.report_type, "color": "#8E8E93", "is_negative": True, "weight": 1})
        clusters[key]["reports"].append({
            "id":          str(r.id),
            "report_type": r.report_type,
            "label":       meta["label"],
            "color":       meta["color"],
            "is_negative": meta["is_negative"],
            "created_at":  r.created_at.isoformat(),
        })
        if meta["is_negative"]:
            clusters[key]["bad_score"]  += meta["weight"]
        else:
            clusters[key]["good_score"] += meta["weight"]

    areas = []
    for key, data in clusters.items():
        bad  = data["bad_score"]
        good = data["good_score"]
        # Derive area name from most-repeated description or a coordinate label
        area_name = f"Area ({data['lat']:.4f}, {data['lng']:.4f})"

        permanent_marker = None
        if bad >= BAD_THRESHOLD and bad > good:
            permanent_marker = {"type": "danger", "color": "#FF3B30"}
        elif good >= GOOD_THRESHOLD and good > bad:
            permanent_marker = {"type": "safe",   "color": "#30D158"}

        areas.append({
            "id":               f"{key[0]:.4f}_{key[1]:.4f}",
            "area_name":        area_name,
            "lat":              data["lat"],
            "lng":              data["lng"],
            "report_count":     len(data["reports"]),
            "bad_score":        bad,
            "good_score":       good,
            "permanent_marker": permanent_marker,
            "reports":          data["reports"],
        })

    # Sort by most-reported first
    areas.sort(key=lambda a: a["report_count"], reverse=True)
    return {"areas": areas}
