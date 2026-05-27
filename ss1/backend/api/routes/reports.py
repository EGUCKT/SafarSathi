"""
SafarSathi — Crowd Report Endpoints
POST /api/reports/       → submit a new crowd report (pin drop)
GET  /api/reports/nearby → get active reports near a location
POST /api/reports/{id}/upvote → upvote a report
"""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..'))
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import text
from datetime import datetime, timedelta
from geoalchemy2.elements import WKTElement
from db import get_db
from db.models import User, CrowdReport
from db.schemas import CrowdReportCreate, CrowdReportOut
from api.routes.auth import get_current_user
import uuid

router = APIRouter()


@router.post("/", response_model=CrowdReportOut, status_code=201)
def submit_report(
    body: CrowdReportCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if body.report_type not in CrowdReport.VALID_TYPES:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid report type. Must be one of: {CrowdReport.VALID_TYPES}"
        )

    expires = datetime.utcnow() + timedelta(hours=24)
    report  = CrowdReport(
        user_id     = current_user.id,
        report_type = body.report_type,
        location    = WKTElement(f"POINT({body.lng} {body.lat})", srid=4326),
        description = body.description,
        expires_at  = expires,
        is_active   = True,
    )
    db.add(report)
    db.commit()
    db.refresh(report)

    # Return with lat/lng extracted
    return {
        "id":          report.id,
        "report_type": report.report_type,
        "lat":         body.lat,
        "lng":         body.lng,
        "description": report.description,
        "created_at":  report.created_at,
        "expires_at":  report.expires_at,
    }


@router.get("/nearby")
def get_nearby_reports(
    lat: float,
    lng: float,
    radius_m: float = 500,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    results = db.execute(text("""
        SELECT
            id, report_type, description, upvotes, created_at, expires_at,
            ST_Y(location::geometry) AS lat,
            ST_X(location::geometry) AS lng,
            ST_Distance(
                ST_Transform(location::geometry, 32643),
                ST_Transform(ST_SetSRID(ST_MakePoint(:lng, :lat), 4326), 32643)
            ) AS distance_m
        FROM crowd_reports
        WHERE is_active = TRUE
          AND expires_at > NOW()
          AND ST_DWithin(
              ST_Transform(location::geometry, 32643),
              ST_Transform(ST_SetSRID(ST_MakePoint(:lng, :lat), 4326), 32643),
              :radius
          )
        ORDER BY distance_m ASC
        LIMIT 50
    """), {"lat": lat, "lng": lng, "radius": radius_m}).fetchall()

    return {
        "reports": [
            {
                "id":          str(r.id),
                "report_type": r.report_type,
                "description": r.description,
                "upvotes":     r.upvotes,
                "lat":         r.lat,
                "lng":         r.lng,
                "distance_m":  round(r.distance_m),
                "created_at":  r.created_at.isoformat(),
                "expires_at":  r.expires_at.isoformat(),
            }
            for r in results
        ]
    }


@router.post("/{report_id}/upvote")
def upvote_report(
    report_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    db.execute(text("""
        UPDATE crowd_reports SET upvotes = upvotes + 1 WHERE id = :rid
    """), {"rid": report_id})
    db.commit()
    return {"message": "Upvoted"}
