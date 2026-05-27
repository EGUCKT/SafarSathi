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

# List of locations from user
locations = [
  ("[BAD LIGHTING] Umariya (Inner Village Lane — West of AB Road)", 22.60080000, 75.78380000),
  ("[BAD LIGHTING] Umariya (Farmland Kachchi Track — South SDBC)", 22.59200000, 75.78700000),
  ("[BAD LIGHTING] Umariya (Back Gate Track — West Wall SDBC)", 22.59780000, 75.78450000),
  ("[BAD LIGHTING] Umariya (Abandoned Plot Road near College)", 22.59950000, 75.78900000),
  ("[BAD LIGHTING] Umariya (Nala/Drain Side Path)", 22.59450000, 75.78880000),
  ("[BAD LIGHTING] Umariya (Old Diversion Road — Pre Bypass)", 22.60100000, 75.78700000),
  ("[BAD LIGHTING] Umariya (Umaria–Santer Kachchi Road)", 22.60400000, 75.78580000),
  ("[BAD LIGHTING] Umariya (Farmland Boundary Road — North Umaria)", 22.60500000, 75.78400000),
  ("[BAD LIGHTING] Umariya (Open Ground Track Near Bus Stop)", 22.59580000, 75.78750000),
  ("[BAD LIGHTING] Umariya (Construction Site Road — North East)", 22.60250000, 75.79200000),
  ("[BAD LIGHTING] Harnya Khedi (Agricultural Field Track)", 22.59200000, 75.78200000),
  ("[BAD LIGHTING] Harnya Khedi (Harnya Khedi–Rasalpura Kachchi Path)", 22.58880000, 75.78400000),
  ("[BAD LIGHTING] Harnya Khedi (Unnamed Road — Emerald Green Back)", 22.58958470, 75.77674250),
  ("[BAD LIGHTING] Harnya Khedi (Forested/Plantation Track West NH)", 22.59750000, 75.78300000),
  ("[BAD LIGHTING] Harnya Khedi (Inner Village Lanes)", 22.59125010, 75.78075250),
  ("[BAD LIGHTING] Rasalpura (Post Office Area Lane)", 22.58492930, 75.78386030),
  ("[BAD LIGHTING] Haranya Kheri (Railway Station Area Road)", 22.58460990, 75.77718000),
  ("[BAD LIGHTING] Pigdambar (Agricultural Field Tracks – East of AB Road)", 22.61800000, 75.80800000),
  ("[BAD LIGHTING] Rau-Pithampur Road (IIM Back Forest Track)", 22.62800000, 75.78500000),
  ("[BAD LIGHTING] Santer Village (Rural Link Road)", 22.60800000, 75.78900000),
  ("[BAD LIGHTING] Bilawali Area (Lake Side Kachchi Road)", 22.61900000, 75.77600000),
  ("[BAD LIGHTING] Tihi Village (Internal Roads – West of Rau)", 22.60984400, 75.72842600),
  ("[BAD LIGHTING] Tihi (Railway Track Parallel Road)", 22.6105, 75.7285),
  ("[BAD LIGHTING] Pithampur (Sector 1 Industrial Back Lane)", 22.6185, 75.6720),
  ("[BAD LIGHTING] Rau (Rangwasa Back Road)", 22.6415, 75.7950),
  ("[BAD LIGHTING] Mhow (Dongargaon Secluded Stretch)", 22.5680, 75.7410),
  ("[BAD LIGHTING] Silicon City (Phase 4 Dark Zone)", 22.6450, 75.8150),
  ("[BAD LIGHTING] Sonway (Lake Side Unlit Path)", 22.6240, 75.7610),
  ("[BAD LIGHTING] Kodariya (Rural Link Path)", 22.5315, 75.7550),
  ("[BAD LIGHTING] Pithampur (Labor Colony Unlit Square)", 22.6145, 75.6690),
  ("[BAD LIGHTING] Mhow (Military Area Outer Fence Road)", 22.5485, 75.7625),
  ("[BAD LIGHTING] Pithampur (Bagdoon Industrial Stretch)", 22.5995, 75.6585),
  ("[BAD LIGHTING] Rau (Canal Side Dark Path)", 22.6265, 75.8125),
  ("[BAD LIGHTING] Mhow (Bercha Lake Entry Road)", 22.5115, 75.7885),
  ("[BAD LIGHTING] Rau (Industrial Plot 55 Boundary)", 22.6295, 75.7935),
  ("[DULL ZONE] Sonway-Tihi Link Road (Isolated Industrial stretch)", 22.6145, 75.7420),
  ("[DULL ZONE] Harnya Khedi Canal Bank (Unlit service track)", 22.5820, 75.8010),
  ("[DULL ZONE] Pithampur Sector 3 Edge (Low activity warehouse zone)", 22.6310, 75.6950),
  ("[DULL ZONE] Gawli Palasia Outer Track (Isolated rural connector)", 22.5710, 75.7890),
  ("[DULL ZONE] Rau-Bypass Connection (Undeveloped colony outskirts)", 22.6520, 75.8250),
  ("[LIGHT ZONE] Rau North Hub (Silicon City, CAPS Town, DPS Road Area)", 22.6350, 75.8100),
  ("[LIGHT ZONE] Rau-Pithampur Corridor (IIM Indore & Mega City Access)", 22.6270, 75.7980),
  ("[LIGHT ZONE] Umariya Safety Corridor (SDBC College & Samarth Park)", 22.6000, 75.7930),
  ("[LIGHT ZONE] Mhow Transit Hub (Dr. Ambedkar Nagar Station & Heritage)", 22.5595, 75.7560),
  ("[LIGHT ZONE] Mhow Central (Cantonment Board & Civil Hospital Area)", 22.5550, 75.7560),
  ("[LIGHT ZONE] Pithampur Industrial Hub (Main Square & Bus Stand)", 22.6110, 75.6760),
  ("[LIGHT ZONE] Kishanganj Residential (Vidhut Nagar & Emerald Green)", 22.5860, 75.7750),
  ("[BLIND SPOT] Sonway (Toll Plaza Back Road)", 22.61214151, 75.77646288),
  ("[BLIND SPOT] Umariya–Rau (Dhanshri Plot Area AB Road)", 22.61628804, 75.80000353),
  ("[BLIND SPOT] Rau (Circle Flyover Southern Underpass)", 22.62553298, 75.80445440),
  ("[BLIND SPOT] Rau (Railway Station Back Lane)", 22.63531437, 75.80694855),
  ("[BLIND SPOT] Harnya Khedi (South Boundary Kachchi Track)", 22.59120000, 75.78080000),
  ("[BLIND SPOT] Sonway (Sarthak Greens Unpaved Approach)", 22.62122299, 75.76325422),
  ("[BLIND SPOT] Rau–Pithampur (Industrial Plot Side Lane)", 22.62910000, 75.79420000),
  ("[CROWDED] Umariya Locality (All day activity) Busy daytime", 22.60394900, 75.79237700),
  ("[DESERTED] Umariya Inner Village Area (Deserted after 9:00 PM)", 22.60468935, 75.78837869),
  ("[DESERTED] Anandam Samarth Park Colony (Very quiet - no fixed public hours)", 22.60246277, 75.79744311),
  ("[DESERTED] Rudraksh Greens Colony (Undeveloped - Deserted after 6:00 PM)", 22.60809219, 75.79419822),
  ("[DESERTED] Keshav Park Colony (Very low traffic after dark)", 22.60670604, 75.79533888),
  ("[DESERTED] South SS Greens (Roads not built - very few residents)", 22.57952723, 75.79038124),
  ("[DESERTED] West New Sarthak Greens (Undeveloped - road not made yet)", 22.62124280, 75.76330787),
  ("[DESERTED] West Glamour Highway City (No shops/doctors/general stores)", 22.61228428, 75.75931308),
  ("[DESERTED] North Rau Railway Station (Very quiet - local DEMU trains only)", 22.63366750, 75.80518876),
  ("[HARASSMENT] CAT Road Secluded Stretch (Recent reports of stalking/harassment)", 22.63150000, 75.80120000),
  ("[HARASSMENT] Rau-Pithampur Side Road (Isolated industrial corridor, low patrol)", 22.62880000, 75.79250000),
  ("[HARASSMENT] Harnya Khedi Outer Perimeter (High secluded activity after dark)", 22.59250000, 75.78200000),
  ("[HARASSMENT] Near Medicaps/MITM Back Lane (Quiet student corridor, poorly lit)", 22.61750000, 75.79950000),
  ("[CRIME ZONE] Rajendra Nagar Bridge Underpass (High Snatching Risk)", 22.6685, 75.8240),
  ("[CRIME ZONE] Pithampur Sector 1 Labor Colony (Frequent Vehicle Theft)", 22.6155, 75.6680),
  ("[CRIME ZONE] Rau-Indore Highway Secluded Patch (Night High-Alert Zone)", 22.6580, 75.8420),
  ("[CRIME ZONE] Mhow Hari Phatak Railway Perimeter (Isolated/Unsafe)", 22.5568, 75.7420),
  ("[CRIME ZONE] Kishanganj Warehouse Back-Alley (Low Patrol/Theft Area)", 22.5720, 75.7655),
  ("[CAUTION ZONE] Rau Circle Market (Heavy Crowd - High Awareness Required)", 22.6292, 75.8075),
  ("[CAUTION ZONE] Kishanganj A.B. Road Crossing (High Traffic/Friction Area)", 22.5665, 75.7610),
  ("[CAUTION ZONE] Pithampur-Mhow Main Road (Industrial Transit/Heavy Vehicles)", 22.5950, 75.7250),
  ("[CAUTION ZONE] Sonway Junction (Construction Area/Poor Road Condition)", 22.6220, 75.7680),
  ("[CAUTION ZONE] Mhow Dongargaon Entry (Transitional Footfall Zone)", 22.5620, 75.7380),
  ("[CCTV] HDFC Bank ATM (Open 24 hrs) Ph: 1800 1601", 22.63632470, 75.80911410),
  ("[CCTV] SBI ATM (Open 24 hrs) Ph: 1800 1234", 22.63590900, 75.80994800),
  ("[CCTV] Canara Bank ATM (Open 24 hrs) Ph: 1800 425 0018", 22.61493410, 75.79699910),
  ("[CAFE] Janta Dhaba (Daily: 11AM–12AM) High foot traffic", 22.60031333, 75.79601968),
  ("[CAFE] Rajput Dhaba (Daily: 6AM–3AM) 24/7 Availability", 22.62225408, 75.80229718),
  ("[CAFE] Chai Kapi (12PM–12AM) Medium but CAFE", 22.59552785, 75.78739551),
  ("[CAFE] Mudoven Restaurant (Daily: 11AM–12:30AM) Popular", 22.61999120, 75.79834359),
  ("[CAFE] SHRI SETH KRIPA (Daily: 7AM–11:30PM) Massive footfall", 22.62070489, 75.80092562),
  ("[CAFE] The Waterfall Restaurant (Daily: 11AM–11:30PM)", 22.61838883, 75.80100610),
  ("[CINEMA] Fundore Park & Cinema (Daily: 11AM–9PM) Massive", 22.61952807, 75.80091554),
  ("[CINEMA] Fortune cinemas, Mhow bypass road", 22.60709247306767, 75.79444815605108),
  ("[CAFE] Bhanwarilal Mithaiwala (Daily: 8:30AM–10PM)", 22.58496650, 75.77684250),
  ("[MALL] Vikram Mall (24/7)", 22.60673591203055, 75.79420139283138),
  ("[TEMPLE] Mata Mandir (24/7 open)", 22.59405388, 75.78728633),
  ("[STATION] Rau Railway Station (Active DEMU)", 22.6353, 75.8069),
  ("[STATION] Mhow (Dr. Ambedkar Nagar) Station", 22.5594, 75.7562),
  ("[STATION] Indore Junction (Main Hub)", 22.7164, 75.8712),
  ("[STATION] Saifee Nagar Railway Station", 22.6954, 75.8541),
  ("[STATION] Devi Ahilya Bai Holkar Airport", 22.7214, 75.8065),
  ("[BUS STOP] Sarwate Bus Stand (Central)", 22.7142, 75.8694),
  ("[BUS STOP] Gangwal Bus Stand", 22.7095, 75.8412),
  ("[CROWDED] Rajwada Market (High Activity)", 22.7185, 75.8542),
  ("[CROWDED] Sarafa Night Food Bazaar", 22.7192, 75.8535),
  ("[CROWDED] Treasure Island Mall", 22.7231, 75.8785),
  ("[CROWDED] Phoenix Citadel Mall (Highway)", 22.7421, 76.0012),
  ("[CROWDED] Pithampur Bus Stand", 22.6105, 75.6754),
  ("[CROWDED] Chhappan Dukan (Food Hub)", 22.7254, 75.8732),
  ("[LANDMARK] IIM Indore Main Gate (Pithampur Road)", 22.625765, 75.792718),
  ("[LANDMARK] MDPI Gate (Mhow Road)", 22.5793, 75.7665),
  ("[LANDMARK] Mhow Bus Stand (Dr. Ambedkar Nagar)", 22.5574, 75.7558),
  ("[LANDMARK] Holkar Stadium", 22.7283, 75.8852),
  ("[LANDMARK] Indore Airport (Devi Ahilya Bai Holkar)", 22.7214, 75.8065),
  ("[LANDMARK] Old Palasia Square", 22.7389, 75.8745),
  ("[LANDMARK] Rasalpura Square (Near Harnya Khedi)", 22.5949, 75.7753),
  ("[LANDMARK] GLS University Gate (Bypass Road)", 22.6294, 75.8103),
  ("[LANDMARK] Sanskriti School (Nipania)", 22.7088, 75.9002),
  ("[LANDMARK] Maheshwari School (Near Emerald Green)", 22.5892, 75.7715),
  ("[LANDMARK] St. Arnold High School (Sainik Nagar)", 22.5831, 75.7560),
  ("[LANDMARK] Holy Cross School (Tapasya Nagar)", 22.5805, 75.7537),
  ("[LANDMARK] Rustomjee Cambridge School (Khatipura)", 22.6062, 75.7522),
  ("[LANDMARK] Emerald Greens Gate (Ab Road)", 22.5898, 75.7711),
  ("[BUS STOP] Umariya (SDBC Stop, Ab Road)", 22.5969, 75.7880),
  ("[BUS STOP] Pigdambar Main Chowk (Ab Road)", 22.6210, 75.8038),
  ("[BUS STOP] Rau Bypass (Near CAPS Town)", 22.6175, 75.8015),
  ("[BUS STOP] Harnya Khedi Square (Ab Road)", 22.5910, 75.7788),
  ("[BUS STOP] Mhow Stand (In City)", 22.5585, 75.7550),
  ("[BUS STOP] Teen Pulia (Mhow Road)", 22.5855, 75.7640),
  ("[BUS STOP] Sanwer Road Chouraha", 22.6354, 75.7585),
  ("[BUS STOP] Jethpura Road Intersection", 22.6443, 75.8310),
  ("[TEMPLE] Harnya Khedi Mata Mandir", 22.5925, 75.7800),
  ("[TEMPLE] Pigdambar Temple (Near AB Road)", 22.6220, 75.8050),
  ("[TEMPLE] Sonway Balaji Mandir", 22.6255, 75.7600),
  ("[TEMPLE] Bicholi Mardana Shiv Temple", 22.6678, 75.8252),
  ("[TEMPLE] Khajrana Ganesh Temple (Indore)", 22.6831, 75.8352),
  ("[TEMPLE] Kanch Mandir (Indore City)", 22.7175, 75.8515),
  ("[TEMPLE] Omkareshwar Jyotirlinga (Mhow Nearby)", 22.2487, 76.0108),
  ("[CCTV] HDFC Bank ATM (Ab Road, Pigdambar)", 22.6188, 75.8005),
  ("[CCTV] ATM (Sonway, Near Pithampur Road)", 22.6245, 75.7620),
  ("[CCTV] ATM (Mhow Main Road)", 22.5570, 75.7555),
  ("[CCTV] ATM (Rau Bypass)", 22.6168, 75.8010),
  ("[CCTV] ATM (Near GLS University)", 22.6289, 75.8100),
  ("[CCTV] ATM (Teen Pulia)", 22.5850, 75.7635),
  ("[CCTV] ATM (Bicholi Mardana Square)", 22.6670, 75.8240),
  ("[CCTV] ATM (Rajwada Area)", 22.7180, 75.8530),
  ("[CCTV] ATM (Manik Bagh Road)", 22.6955, 75.8380),
  ("[CCTV] ATM (Airport Road)", 22.7200, 75.8070)
]

try:
    for name, lat, lng in locations:
        haven = SafeHaven(
            name=name,
            place_type="police_station",
            location=f"SRID=4326;POINT({lng} {lat})",
            address="Hackathon Demo",
            is_24hr=True
        )
        db.add(haven)
        print(f"Added: {name}")
    db.commit()
    print("Successfully added all havens and POIs")
except Exception as e:
    db.rollback()
    print(f"Error adding havens: {e}")
finally:
    db.close()
