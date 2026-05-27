"""
SafarSathi — Route Endpoints
POST /api/routes/find         → find safest route between two points
POST /api/routes/alternatives → get 3 route options (safest/balanced/shortest)
GET  /api/routes/safe-havens  → nearest police stations / hospitals
POST /api/routes/journey/start   → begin a tracked journey
POST /api/routes/journey/ping    → send live location update
POST /api/routes/journey/end     → end journey
"""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..'))
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import text
from datetime import datetime
from db import get_db
from db.models import User, ActiveJourney, SafeHaven
from db.schemas import RouteRequest, RouteResponse, JourneyStart, LocationPing, JourneyPingResponse
from api.routes.auth import get_current_user
from services.route_optimizer import router as route_optimizer
import uuid
import json

router = APIRouter()


# ── Find safest route ─────────────────────────────────────────────────────────

@router.post("/find")
def find_route(body: RouteRequest, current_user: User = Depends(get_current_user)):
    if not route_optimizer.loaded:
        raise HTTPException(status_code=503, detail="Route engine not ready")

    try:
        hour = datetime.now().hour
        result = route_optimizer.find_safest_route(
            origin_lat  = body.origin.lat,
            origin_lng  = body.origin.lng,
            dest_lat    = body.destination.lat,
            dest_lng    = body.destination.lng,
            preference  = body.preference,
            hour        = hour,
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Routing error: {e}")

    return {
        "route_id":             str(uuid.uuid4()),
        "preference":           body.preference,
        "total_distance_m":     result["total_distance_m"],
        "walk_minutes":         result["walk_minutes"],
        "drive_minutes":        result["drive_minutes"],
        "overall_safety_score": result["overall_safety_score"],
        "safety_label":         result["safety_label"],
        "coordinates":          result["coordinates"],
        "segments":             result["segments"],
        "computed_at_hour":     hour,
    }


# ── Alternative routes ────────────────────────────────────────────────────────

@router.post("/alternatives")
def find_alternatives(body: RouteRequest, current_user: User = Depends(get_current_user)):
    if not route_optimizer.loaded:
        raise HTTPException(status_code=503, detail="Route engine not ready")

    try:
        routes = route_optimizer.find_alternative_routes(
            origin_lat = body.origin.lat,
            origin_lng = body.origin.lng,
            dest_lat   = body.destination.lat,
            dest_lng   = body.destination.lng,
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

    # Attach a route_id to each
    for r in routes:
        r["route_id"] = str(uuid.uuid4())

    return {"routes": routes, "count": len(routes)}


# ── Nearby safe havens ────────────────────────────────────────────────────────

@router.get("/safe-havens")
def get_safe_havens(
    lat: float,
    lng: float,
    radius_m: float = 2000,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Returns safe havens within radius_m metres of the given coordinate."""
    results = db.execute(text("""
        SELECT
            id, name, place_type, address, is_24hr,
            ST_Y(location::geometry) AS lat,
            ST_X(location::geometry) AS lng,
            ST_Distance(
                ST_Transform(location::geometry, 32643),
                ST_Transform(ST_SetSRID(ST_MakePoint(:lng, :lat), 4326), 32643)
            ) AS distance_m
        FROM safe_havens
        WHERE ST_DWithin(
            ST_Transform(location::geometry, 32643),
            ST_Transform(ST_SetSRID(ST_MakePoint(:lng, :lat), 4326), 32643),
            :radius
        )
        ORDER BY distance_m ASC
        LIMIT 500
    """), {"lat": lat, "lng": lng, "radius": radius_m}).fetchall()

    return {
        "safe_havens": [
            {
                "id":          str(r.id),
                "name":        r.name,
                "place_type":  r.place_type,
                "address":     r.address,
                "is_24hr":     r.is_24hr,
                "lat":         r.lat,
                "lng":         r.lng,
                "distance_m":  round(r.distance_m),
            }
            for r in results
        ]
    }


# ── Start journey (enables dead-man switch) ───────────────────────────────────

@router.post("/journey/start")
def start_journey(
    body: JourneyStart,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    # End any existing active journey for this user
    db.execute(text("""
        UPDATE active_journeys
        SET ended_at = NOW()
        WHERE user_id = :uid AND ended_at IS NULL
    """), {"uid": str(current_user.id)})

    # Build route path geometry from coordinates
    route = route_optimizer.find_safest_route(
        body.origin.lat, body.origin.lng,
        body.destination.lat, body.destination.lng,
        preference="balanced",
    )
    coords = route["coordinates"]

    # Build WKT linestring from route coordinates
    wkt_points = ", ".join(f"{c['lng']} {c['lat']}" for c in coords)
    path_wkt   = f"LINESTRING({wkt_points})"

    journey = ActiveJourney(
        user_id        = current_user.id,
        origin         = f"SRID=4326;POINT({body.origin.lng} {body.origin.lat})",
        destination    = f"SRID=4326;POINT({body.destination.lng} {body.destination.lat})",
    )
    db.add(journey)
    db.flush()

    # Set safe_path geometry
    db.execute(text("""
        UPDATE active_journeys
        SET safe_path = ST_GeomFromText(:wkt, 4326)
        WHERE id = :jid
    """), {"wkt": path_wkt, "jid": str(journey.id)})

    db.commit()

    return {
        "journey_id":    str(journey.id),
        "route":         route,
        "message":       "Journey started. Stay safe!",
        "deadman_active": True,
    }


# ── Location ping (dead-man switch check) ─────────────────────────────────────

@router.post("/journey/ping", response_model=JourneyPingResponse)
def ping_location(
    body: LocationPing,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    journey = db.query(ActiveJourney).filter(
        ActiveJourney.id      == uuid.UUID(body.journey_id),
        ActiveJourney.user_id == current_user.id,
        ActiveJourney.ended_at == None,
    ).first()

    if not journey:
        raise HTTPException(status_code=404, detail="Active journey not found")

    # Update current location and ping time
    db.execute(text("""
        UPDATE active_journeys
        SET current_location = ST_SetSRID(ST_MakePoint(:lng, :lat), 4326),
            last_ping_at     = NOW()
        WHERE id = :jid
    """), {"lat": body.lat, "lng": body.lng, "jid": str(journey.id)})
    db.commit()

    # Check deviation from safe path
    path_result = db.execute(text("""
        SELECT ST_Distance(
            ST_Transform(ST_SetSRID(ST_MakePoint(:lng, :lat), 4326), 32643),
            ST_Transform(safe_path, 32643)
        ) AS deviation_m
        FROM active_journeys WHERE id = :jid
    """), {"lat": body.lat, "lng": body.lng, "jid": str(journey.id)}).fetchone()

    deviation_m = float(path_result.deviation_m) if path_result and path_result.deviation_m else 0

    if deviation_m > 150:   # 150m deviation threshold
        return JourneyPingResponse(
            status          = "deviation_warning",
            deviation_meters = round(deviation_m, 1),
            message         = f"You are {round(deviation_m)}m from your safe route. Are you okay?",
        )

    return JourneyPingResponse(status="on_track", deviation_meters=round(deviation_m, 1))


# ── End journey ───────────────────────────────────────────────────────────────

@router.post("/journey/end")
def end_journey(
    journey_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    db.execute(text("""
        UPDATE active_journeys
        SET ended_at = NOW()
        WHERE id = :jid AND user_id = :uid
    """), {"jid": journey_id, "uid": str(current_user.id)})
    db.commit()
    return {"message": "Journey ended. Glad you're safe!"}
