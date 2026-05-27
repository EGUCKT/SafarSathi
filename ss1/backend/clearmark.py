import sys
import os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from dotenv import load_dotenv
load_dotenv()

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from db.models import SafeHaven

DATABASE_URL = os.getenv("DATABASE_URL")
if not DATABASE_URL:
    print("No DATABASE_URL found in .env")
    sys.exit(1)

engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
db = SessionLocal()

try:
    deleted = db.query(SafeHaven).filter(SafeHaven.address == "Hackathon Demo").delete(synchronize_session=False)
    db.commit()
    print(f"Successfully deleted {deleted} hackathon demo points.")
except Exception as e:
    db.rollback()
    print(f"Error: {e}")
finally:
    db.close()
