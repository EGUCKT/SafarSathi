import sys
import os

# Tells Python that backend/ is the root for all imports
# Must be before any other imports
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
from core.config import get_settings

settings = get_settings()

@asynccontextmanager
async def lifespan(app: FastAPI):
    print("[SafarSathi] Starting up...")
    from ml.safety_scorer import scorer
    scorer.load()
    from services.route_optimizer import router as route_optimizer
    route_optimizer.load()
    print("[SafarSathi] Ready!")
    yield
    print("[SafarSathi] Shutting down...")

app = FastAPI(
    title       = "SafarSathi API",
    description = "Intelligent safety navigation — Indore & Mhow",
    version     = "1.0.0",
    lifespan    = lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], allow_credentials=True,
    allow_methods=["*"], allow_headers=["*"],
)

from api.routes import auth, routes, sos, reports, admin
app.include_router(auth.router,    prefix="/api/auth",    tags=["Auth"])
app.include_router(routes.router,  prefix="/api/routes",  tags=["Routes"])
app.include_router(sos.router,     prefix="/api/sos",     tags=["SOS"])
app.include_router(reports.router, prefix="/api/reports", tags=["Reports"])
app.include_router(admin.router,   prefix="/api/admin",   tags=["Admin"])

@app.get("/health", tags=["Health"])
def health():
    from services.route_optimizer import router as ro
    from ml.safety_scorer import scorer
    return {
        "status":       "ok",
        "service":      "SafarSathi API",
        "route_engine": "ready" if ro.loaded     else "not loaded",
        "ml_model":     "ready" if scorer.loaded else "not loaded",
        "focus_area":   "Indore + Mhow",
    }

@app.get("/")
def home():
    return {"status": "SafarSathi API is Online", "version": "1.0.0"}