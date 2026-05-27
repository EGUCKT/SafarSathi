"""
SafarSathi — Pydantic Schemas
These define what data the API accepts and returns.
Think of them as "contracts" between Flutter app and backend.
"""
from pydantic import BaseModel, EmailStr
from typing import Optional, List
from datetime import datetime
import uuid


# ── Auth ──────────────────────────────────────────────────────────────────────

class UserRegister(BaseModel):
    name: str
    phone: str          # e.g. "+919876543210"
    email: Optional[EmailStr] = None
    password: str

class UserLogin(BaseModel):
    phone: str
    password: str

class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user_id: str
    name: str

class UserOut(BaseModel):
    id: uuid.UUID
    name: str
    phone: str
    email: Optional[str]
    created_at: datetime
    class Config:
        from_attributes = True


# ── Emergency contacts ────────────────────────────────────────────────────────

class EmergencyContactCreate(BaseModel):
    name: str
    phone: str          # WhatsApp number with country code
    relation: Optional[str] = None

class EmergencyContactOut(EmergencyContactCreate):
    id: uuid.UUID
    class Config:
        from_attributes = True


# ── Route request / response ──────────────────────────────────────────────────

class Coordinate(BaseModel):
    lat: float
    lng: float

class RouteRequest(BaseModel):
    origin: Coordinate
    destination: Coordinate
    preference: str = "balanced"    # "safest" | "shortest" | "balanced"

class RouteSegmentOut(BaseModel):
    safety_score: float
    distance_meters: float
    coordinates: List[Coordinate]   # the polyline points

class RouteResponse(BaseModel):
    route_id: str
    total_distance_meters: float
    estimated_minutes: int
    overall_safety_score: float
    segments: List[RouteSegmentOut]
    safe_havens_nearby: List[dict]  # nearest police/hospital on route


# ── Crowd reports ─────────────────────────────────────────────────────────────

class CrowdReportCreate(BaseModel):
    report_type: str    # "poor_lighting" | "harassment_incident" etc.
    lat: float
    lng: float
    description: Optional[str] = None

class CrowdReportOut(BaseModel):
    id: uuid.UUID
    report_type: str
    lat: float
    lng: float
    description: Optional[str]
    created_at: datetime
    expires_at: datetime
    class Config:
        from_attributes = True


# ── SOS ───────────────────────────────────────────────────────────────────────

class SosRequest(BaseModel):
    lat: float
    lng: float
    trigger_type: str = "manual_button"  # "manual_button"|"voice_trigger"|"deadman_switch"

class SosResponse(BaseModel):
    sos_id: str
    whatsapp_sent: bool
    contacts_notified: List[str]
    nearest_safe_haven: Optional[dict]
    message: str


# ── Journey ───────────────────────────────────────────────────────────────────

class JourneyStart(BaseModel):
    origin: Coordinate
    destination: Coordinate
    route_id: str           # from RouteResponse

class LocationPing(BaseModel):
    journey_id: str
    lat: float
    lng: float

class JourneyPingResponse(BaseModel):
    status: str             # "on_track" | "deviation_warning" | "sos_triggered"
    deviation_meters: Optional[float] = None
    message: Optional[str] = None
