"""
SafarSathi — SQLAlchemy ORM Models
These Python classes mirror every table in schema.sql
FastAPI uses these to read/write the database without raw SQL
"""
import uuid
from datetime import datetime
from sqlalchemy import (
    Column, String, Boolean, Float, Integer,
    Text, ARRAY, TIMESTAMP, BigInteger, ForeignKey
)
from sqlalchemy.dialects.postgresql import UUID
from geoalchemy2 import Geometry
from sqlalchemy.orm import relationship
from db import Base


class User(Base):
    __tablename__ = "users"

    id            = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name          = Column(String, nullable=False)
    phone         = Column(String, unique=True, nullable=False)
    email         = Column(String, unique=True)
    password_hash = Column(String, nullable=False)
    is_active     = Column(Boolean, default=True)
    created_at    = Column(TIMESTAMP(timezone=True), default=datetime.utcnow)

    emergency_contacts = relationship("EmergencyContact", back_populates="user", cascade="all, delete")
    sos_events         = relationship("SosEvent", back_populates="user")
    active_journeys    = relationship("ActiveJourney", back_populates="user")


class EmergencyContact(Base):
    __tablename__ = "emergency_contacts"

    id         = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id    = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    name       = Column(String, nullable=False)
    phone      = Column(String, nullable=False)     # WhatsApp number
    relation   = Column(String)
    created_at = Column(TIMESTAMP(timezone=True), default=datetime.utcnow)

    user = relationship("User", back_populates="emergency_contacts")


class RoadSegment(Base):
    __tablename__ = "road_segments"

    id             = Column(BigInteger, primary_key=True, autoincrement=True)
    osm_id         = Column(BigInteger, unique=True)
    name           = Column(Text)
    highway_type   = Column(Text)
    geom           = Column(Geometry("LINESTRING", srid=4326), nullable=False)

    crime_density  = Column(Float, default=0.5)
    lighting_score = Column(Float, default=0.5)
    crowd_score    = Column(Float, default=0.5)
    user_rating    = Column(Float, default=0.5)
    safety_score   = Column(Float, default=0.5)

    length_meters  = Column(Float)
    last_updated   = Column(TIMESTAMP(timezone=True), default=datetime.utcnow)


class Streetlight(Base):
    __tablename__ = "streetlights"

    id         = Column(BigInteger, primary_key=True, autoincrement=True)
    osm_id     = Column(BigInteger, unique=True)
    location   = Column(Geometry("POINT", srid=4326), nullable=False)
    is_working = Column(Boolean, default=True)
    created_at = Column(TIMESTAMP(timezone=True), default=datetime.utcnow)


class CrimeIncident(Base):
    __tablename__ = "crime_incidents"

    id          = Column(BigInteger, primary_key=True, autoincrement=True)
    crime_type  = Column(Text, nullable=False)
    location    = Column(Geometry("POINT", srid=4326), nullable=False)
    occurred_at = Column(TIMESTAMP(timezone=True))
    severity    = Column(Integer, default=1)
    verified    = Column(Boolean, default=False)
    created_at  = Column(TIMESTAMP(timezone=True), default=datetime.utcnow)


class CrowdReport(Base):
    __tablename__ = "crowd_reports"

    VALID_TYPES = [
        "poor_lighting", "harassment_incident", "unsafe_area",
        "safe_haven", "good_lighting", "police_presence"
    ]

    id          = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id     = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL"))
    report_type = Column(String, nullable=False)
    location    = Column(Geometry("POINT", srid=4326), nullable=False)
    description = Column(Text)
    upvotes     = Column(Integer, default=0)
    is_active   = Column(Boolean, default=True)
    expires_at  = Column(TIMESTAMP(timezone=True))
    created_at  = Column(TIMESTAMP(timezone=True), default=datetime.utcnow)


class SafeHaven(Base):
    __tablename__ = "safe_havens"

    id              = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name            = Column(Text, nullable=False)
    place_type      = Column(Text, nullable=False)
    location        = Column(Geometry("POINT", srid=4326), nullable=False)
    address         = Column(Text)
    phone           = Column(Text)
    is_24hr         = Column(Boolean, default=False)
    google_place_id = Column(Text)
    created_at      = Column(TIMESTAMP(timezone=True), default=datetime.utcnow)


class SosEvent(Base):
    __tablename__ = "sos_events"

    id                  = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id             = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL"))
    trigger_type        = Column(String, nullable=False)
    location_at_trigger = Column(Geometry("POINT", srid=4326))
    contacts_notified   = Column(ARRAY(Text))
    whatsapp_sent       = Column(Boolean, default=False)
    resolved_at         = Column(TIMESTAMP(timezone=True))
    created_at          = Column(TIMESTAMP(timezone=True), default=datetime.utcnow)

    user = relationship("User", back_populates="sos_events")


class ActiveJourney(Base):
    __tablename__ = "active_journeys"

    id               = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id          = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    origin           = Column(Geometry("POINT", srid=4326), nullable=False)
    destination      = Column(Geometry("POINT", srid=4326), nullable=False)
    safe_path        = Column(Geometry("LINESTRING", srid=4326))
    current_location = Column(Geometry("POINT", srid=4326))
    last_ping_at     = Column(TIMESTAMP(timezone=True), default=datetime.utcnow)
    started_at       = Column(TIMESTAMP(timezone=True), default=datetime.utcnow)
    ended_at         = Column(TIMESTAMP(timezone=True))
    sos_triggered    = Column(Boolean, default=False)

    user = relationship("User", back_populates="active_journeys")
