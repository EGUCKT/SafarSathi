"""
SafarSathi — SOS Endpoints
POST /api/sos/trigger   → fire SOS, send WhatsApp to contacts
POST /api/sos/resolve   → mark SOS as resolved
GET  /api/sos/history   → past SOS events for this user
"""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..'))
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import text
from datetime import datetime
from db import get_db
from db.models import User, EmergencyContact, SosEvent
from db.schemas import SosRequest, SosResponse
from api.routes.auth import get_current_user
from core.config import get_settings
import uuid

router  = APIRouter()
settings = get_settings()


# ── SMS sender ───────────────────────────────────────────────────────────

def send_sms_alert(to_phone: str, message: str) -> bool:
    """
    Sends a standard SMS message via Twilio.
    to_phone must be in format: +919876543210
    """
    try:
        from twilio.rest import Client
        client = Client(settings.TWILIO_ACCOUNT_SID, settings.TWILIO_AUTH_TOKEN)

        from_num = settings.TWILIO_PHONE_NUMBER
        # Ensure no whatsapp prefix for standard SMS
        if from_num.startswith("whatsapp:"):
            from_num = from_num.replace("whatsapp:", "")

        to_num = to_phone.strip()
        if to_num.startswith("whatsapp:"):
            to_num = to_num.replace("whatsapp:", "")
        
        # Enforce E.164 formatting (required by Twilio SMS)
        if not to_num.startswith("+"):
            # Assume India (+91) if it's a 10 digit number
            if len(to_num) == 10:
                to_num = f"+91{to_num}"
            else:
                to_num = f"+{to_num}"

        client.messages.create(
            from_ = from_num,
            to    = to_num,
            body  = message,
        )
        return True
    except Exception as e:
        print(f"[SOS] SMS failed to {to_phone}: {e}")
        return False


def build_sos_message(user_name: str, lat: float, lng: float, trigger: str) -> str:
    """Builds the SMS message text sent to emergency contacts."""
    maps_link = f"https://maps.google.com/?q={lat},{lng}"

    # Using a highly compressed, emoji-free template to stay under Twilio Trial's
    # strict 1-segment limit (max 160 GSM-7 characters).
    return (
        f"SOS! {user_name} needs help ASAP. "
        f"Location: {lat},{lng} "
        f"Map: {maps_link}"
    )


# ── Trigger SOS ───────────────────────────────────────────────────────────────

@router.post("/trigger", response_model=SosResponse)
def trigger_sos(
    body: SosRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    # Get emergency contacts
    contacts = db.query(EmergencyContact).filter(
        EmergencyContact.user_id == current_user.id
    ).all()

    if not contacts:
        raise HTTPException(
            status_code=400,
            detail="No emergency contacts set up. Please add contacts in your profile."
        )

    # Build WhatsApp message
    message = build_sos_message(
        user_name = current_user.name,
        lat       = body.lat,
        lng       = body.lng,
        trigger   = body.trigger_type,
    )

    # Send SMS to all contacts
    notified  = []
    all_sent  = False
    for contact in contacts:
        if send_sms_alert(contact.phone, message):
            notified.append(contact.phone)
            all_sent = True

    # Find nearest safe haven
    nearest_haven = db.execute(text("""
        SELECT name, place_type, address,
               ST_Y(location::geometry) AS lat,
               ST_X(location::geometry) AS lng,
               ST_Distance(
                   ST_Transform(location::geometry, 32643),
                   ST_Transform(ST_SetSRID(ST_MakePoint(:lng, :lat), 4326), 32643)
               ) AS distance_m
        FROM safe_havens
        ORDER BY distance_m ASC
        LIMIT 1
    """), {"lat": body.lat, "lng": body.lng}).fetchone()

    # Log SOS event
    sos_event = SosEvent(
        user_id             = current_user.id,
        trigger_type        = body.trigger_type,
        contacts_notified   = notified,
        whatsapp_sent       = all_sent,
    )
    db.add(sos_event)
    db.flush()

    # Set geometry
    db.execute(text("""
        UPDATE sos_events
        SET location_at_trigger = ST_SetSRID(ST_MakePoint(:lng, :lat), 4326)
        WHERE id = :sid
    """), {"lat": body.lat, "lng": body.lng, "sid": str(sos_event.id)})
    db.commit()

    haven_dict = None
    if nearest_haven:
        haven_dict = {
            "name":       nearest_haven.name,
            "place_type": nearest_haven.place_type,
            "address":    nearest_haven.address,
            "lat":        nearest_haven.lat,
            "lng":        nearest_haven.lng,
            "distance_m": round(nearest_haven.distance_m),
        }

    return SosResponse(
        sos_id              = str(sos_event.id),
        whatsapp_sent       = all_sent,
        contacts_notified   = notified,
        nearest_safe_haven  = haven_dict,
        message             = (
            f"SOS sent to {len(notified)} contact(s) via WhatsApp."
            if all_sent else
            "SOS logged. WhatsApp delivery failed — check Twilio config."
        ),
    )


# ── Resolve SOS ───────────────────────────────────────────────────────────────

@router.post("/resolve/{sos_id}")
def resolve_sos(
    sos_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    db.execute(text("""
        UPDATE sos_events
        SET resolved_at = NOW()
        WHERE id = :sid AND user_id = :uid
    """), {"sid": sos_id, "uid": str(current_user.id)})
    db.commit()

    # Send "I'm safe" message to contacts
    contacts = db.query(EmergencyContact).filter(
        EmergencyContact.user_id == current_user.id
    ).all()
    safe_msg = (
        f"✅ *SafarSathi Update*\n\n"
        f"*{current_user.name}* has marked themselves as safe.\n"
        f"The SOS alert has been resolved.\n\n"
        f"_Thank you for your concern._"
    )
    for c in contacts:
        send_whatsapp_alert(c.phone, safe_msg)

    return {"message": "SOS resolved. Your contacts have been notified you are safe."}


# ── SOS history ───────────────────────────────────────────────────────────────

@router.get("/history")
def sos_history(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    events = db.query(SosEvent).filter(
        SosEvent.user_id == current_user.id
    ).order_by(SosEvent.created_at.desc()).limit(20).all()

    return {
        "events": [
            {
                "id":               str(e.id),
                "trigger_type":     e.trigger_type,
                "whatsapp_sent":    e.whatsapp_sent,
                "contacts_count":   len(e.contacts_notified or []),
                "resolved":         e.resolved_at is not None,
                "created_at":       e.created_at.isoformat(),
            }
            for e in events
        ]
    }
