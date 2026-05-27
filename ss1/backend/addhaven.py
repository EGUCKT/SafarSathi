import sys
import os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from db.models import SafeHaven
from dotenv import load_dotenv

load_dotenv()

DATABASE_URL = os.getenv("DATABASE_URL")
if not DATABASE_URL:
    print("No DATABASE_URL found in .env")
    sys.exit(1)

engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
db = SessionLocal()

locations = [
  ("Rau Police Station (Indore-Pithampur Rd, Rau)", "police_station", 22.6320, 75.8055),
  ("Kishanganj Police Station (A.B. Road, Mhow)", "police_station", 22.5650, 75.7600),
  ("Mhow Police Station (Main St, Cantonment Area)", "police_station", 22.5540, 75.7580),
  ("Rajendra Nagar Police Station (Near Reti Mandi)", "police_station", 22.6648, 75.8235),
  ("Bhanwarkuan Police Station (A.B. Road, Indore)", "police_station", 22.6934, 75.8671),
  ("Annapurna Police Station (Annapurna Rd, Indore)", "police_station", 22.6982, 75.8345),
  ("Pithampur Sector 1 Police Post (Industrial Area)", "police_station", 22.6135, 75.6833),
  ("Simrol Police Station (Khandwa Road, Simrol)", "police_station", 22.5284, 75.9123),
  ("Badgonda Police Station (Mhow-Mandleshwar Rd)", "police_station", 22.4850, 75.7210),
  ("Aerodrome Police Station (60 Feet Rd, Indore)", "police_station", 22.7215, 75.8201),

  ("Mewara Hospital (Rau-Pithampur Rd, Rau)", "hospital", 22.6300, 75.8040),
  ("Choithram Hospital (Manik Bagh Rd, Indore)", "hospital", 22.6850, 75.8450),
  ("Gokul Hospital (Mhow-Indore Hwy, Kishanganj)", "hospital", 22.5850, 75.7650),
  ("Mhow Civil Hospital (Dongargaon Rd, Mhow)", "hospital", 22.5582, 75.7531),
  ("Unique Super Specialty Hospital (Annapurna Rd)", "hospital", 22.6712, 75.8294),
  ("Life Line Hospital (New Siyaganj, Rau)", "hospital", 22.6321, 75.8085),
  ("Index Medical College Hospital (Nemawar Rd)", "hospital", 22.6654, 75.9682),
  ("Apple Hospital (Bhanwarkuan Square, Indore)", "hospital", 22.6912, 75.8682),
  ("ESI Hospital (Industrial Area, Pithampur)", "hospital", 22.6052, 75.6741),
  ("Medi-Caps Health Centre (A.B. Road, Pigdambar)", "hospital", 22.6154, 75.8012),

  ("Apollo Pharmacy (Station Rd, Rau)", "pharmacy", 22.6335, 75.8075),
  ("Medplus Pharmacy (A.B. Road, Kishanganj)", "pharmacy", 22.5665, 75.7625),
  ("Sanjeevani Medicals (Main Road, Umariya)", "pharmacy", 22.6000, 75.7850),
  ("Noble Plus Pharmacy (Rajendra Nagar, Indore)", "pharmacy", 22.6680, 75.8210),
  ("Wellness Forever (Bhanwarkuan Square)", "pharmacy", 22.6920, 75.8660),
  ("Mhow Medicos (Main Market, Mhow)", "pharmacy", 22.5560, 75.7595),
  ("Life Care Medical (Pigdambar, A.B. Road)", "pharmacy", 22.6180, 75.7990),
  ("Generic Aadhaar (Rau Circle, Indore)", "pharmacy", 22.6280, 75.8050),
  ("Pithampur Drug House (Housing Board Colony)", "pharmacy", 22.6110, 75.6790),
  ("Shraddha Medical Store (Near SDBC, Harnya Khedi)", "pharmacy", 22.5950, 75.7880),
]

try:
    for name, place_type, lat, lng in locations:
        haven = SafeHaven(
            name=name,
            place_type=place_type,
            location=f"SRID=4326;POINT({lng} {lat})",
            address="Hackathon Demo",
            is_24hr=True
        )
        db.add(haven)
        print(f"Added Safe Haven: {name} ({place_type})")
        
    db.commit()
    print("Successfully added all Safe Havens!")
except Exception as e:
    db.rollback()
    print(f"Error adding safe haven: {e}")
finally:
    db.close()
