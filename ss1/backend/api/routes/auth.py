"""
SafarSathi — Auth Routes
POST /api/auth/register  → create account
POST /api/auth/login     → get JWT token
GET  /api/auth/me        → get current user profile
"""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..'))
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import text
from db import get_db
from db.models import User, EmergencyContact
from db.schemas import UserRegister, UserLogin, TokenResponse, UserOut, EmergencyContactCreate, EmergencyContactOut
from core.security import hash_password, verify_password, create_access_token, decode_token
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from typing import List
import uuid

router = APIRouter()
bearer = HTTPBearer()


# ── Dependency: get current user from JWT ─────────────────────────────────────

def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(bearer),
    db: Session = Depends(get_db),
) -> User:
    token = credentials.credentials
    try:
        payload = decode_token(token)
        user_id = payload.get("sub")
        if not user_id:
            raise HTTPException(status_code=401, detail="Invalid token")
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid or expired token")

    user = db.query(User).filter(User.id == uuid.UUID(user_id)).first()
    if not user or not user.is_active:
        raise HTTPException(status_code=401, detail="User not found or inactive")
    return user


# ── Register ──────────────────────────────────────────────────────────────────

@router.post("/register", response_model=TokenResponse, status_code=201)
def register(body: UserRegister, db: Session = Depends(get_db)):
    # Check duplicate phone
    existing = db.query(User).filter(User.phone == body.phone).first()
    if existing:
        raise HTTPException(status_code=400, detail="Phone number already registered")

    user = User(
        name          = body.name,
        phone         = body.phone,
        email         = body.email,
        password_hash = hash_password(body.password),
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    token = create_access_token({"sub": str(user.id)})
    return TokenResponse(access_token=token, user_id=str(user.id), name=user.name)


# ── Login ─────────────────────────────────────────────────────────────────────

@router.post("/login", response_model=TokenResponse)
def login(body: UserLogin, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.phone == body.phone).first()
    if not user or not verify_password(body.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Invalid phone or password")

    token = create_access_token({"sub": str(user.id)})
    return TokenResponse(access_token=token, user_id=str(user.id), name=user.name)


# ── Get current user ──────────────────────────────────────────────────────────

@router.get("/me", response_model=UserOut)
def get_me(current_user: User = Depends(get_current_user)):
    return current_user


# ── Emergency contacts ────────────────────────────────────────────────────────

@router.post("/contacts", response_model=EmergencyContactOut, status_code=201)
def add_contact(
    body: EmergencyContactCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    # Max 3 contacts per user
    count = db.query(EmergencyContact).filter(
        EmergencyContact.user_id == current_user.id
    ).count()
    if count >= 3:
        raise HTTPException(status_code=400, detail="Maximum 3 emergency contacts allowed")

    contact = EmergencyContact(
        user_id  = current_user.id,
        name     = body.name,
        phone    = body.phone,
        relation = body.relation,
    )
    db.add(contact)
    db.commit()
    db.refresh(contact)
    return contact


@router.get("/contacts", response_model=List[EmergencyContactOut])
def get_contacts(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return db.query(EmergencyContact).filter(
        EmergencyContact.user_id == current_user.id
    ).all()


@router.delete("/contacts/{contact_id}", status_code=204)
def delete_contact(
    contact_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    contact = db.query(EmergencyContact).filter(
        EmergencyContact.id      == uuid.UUID(contact_id),
        EmergencyContact.user_id == current_user.id,
    ).first()
    if not contact:
        raise HTTPException(status_code=404, detail="Contact not found")
    db.delete(contact)
    db.commit()
