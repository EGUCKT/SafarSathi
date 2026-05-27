from pydantic_settings import BaseSettings
from functools import lru_cache
from typing import Optional

class Settings(BaseSettings):
    # Database
    DATABASE_URL: str
    SUPABASE_URL: Optional[str] = ""
    SUPABASE_KEY: Optional[str] = ""

    # Firebase
    FIREBASE_CREDENTIALS_PATH: str = "./firebase-credentials.json"
    FIREBASE_DATABASE_URL: Optional[str] = ""

    # Twilio (SMS alerts)
    TWILIO_ACCOUNT_SID: str
    TWILIO_AUTH_TOKEN: str
    TWILIO_PHONE_NUMBER: str

    # Mapping
    GOOGLE_MAPS_API_KEY: Optional[str] = ""
    GOOGLE_PLACES_API_KEY: Optional[str] = ""

    # JWT Auth
    SECRET_KEY: str = "56b44622f5b9567bbbe7ac711418aad1187d47b28c3873a57dbf5568cedc124e"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 1440

    # ML Model
    MODEL_PATH: str = "./ml/safety_model.joblib"
    CITY_NAME: str = "Indore, India"

    class Config:
        env_file = ".env"
        case_sensitive = True


@lru_cache()
def get_settings() -> Settings:
    return Settings()