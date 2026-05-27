import sys
import os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from db.models import User
from dotenv import load_dotenv

load_dotenv()

DATABASE_URL = os.getenv("DATABASE_URL")
if not DATABASE_URL:
    print("No DATABASE_URL found in .env")
    sys.exit(1)

engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
db = SessionLocal()

try:
    print("⚠️ WARNING: This will delete ALL registered users and their associated data.")
    confirm = input("Are you sure? (y/n): ")
    if confirm.lower() == 'y':
        # Deleting users will cascade to reports, contacts, etc. depending on DB constraints
        deleted = db.query(User).delete()
        db.commit()
        print(f"Successfully deleted {deleted} users.")
    else:
        print("Operation cancelled.")
except Exception as e:
    db.rollback()
    print(f"Error clearing users: {e}")
finally:
    db.close()
