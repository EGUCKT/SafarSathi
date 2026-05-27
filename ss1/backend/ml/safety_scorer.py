"""
SafarSathi — Safety Scorer (Runtime)
Loaded by FastAPI to predict safety scores for road segments
without hitting the database for every request.

This is separate from train_safety_model.py:
  - train_safety_model.py  → run ONCE offline to create the model files
  - safety_scorer.py       → loaded by FastAPI on startup, used for every request
"""

import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
import os
import joblib
import numpy as np
from datetime import datetime
from functools import lru_cache

MODEL_PATH  = os.path.join(os.path.dirname(__file__), "safety_model.joblib")
SCALER_PATH = os.path.join(os.path.dirname(__file__), "safety_scaler.joblib")


class SafetyScorer:
    """
    Singleton class that holds the trained model in memory.
    FastAPI loads this once on startup and reuses it for every route request.
    """

    def __init__(self):
        self.model  = None
        self.scaler = None
        self.loaded = False

    def load(self):
        """Load model files from disk. Called once at FastAPI startup."""
        if self.loaded:
            return
        try:
            self.model  = joblib.load(MODEL_PATH)
            self.scaler = joblib.load(SCALER_PATH)
            self.loaded = True
            print("[SafetyScorer] Model loaded successfully")
        except FileNotFoundError:
            print("[SafetyScorer] WARNING: Model files not found.")
            print("[SafetyScorer] Run: python ml/train_safety_model.py")
            print("[SafetyScorer] Using formula-based fallback scoring.")
            self.loaded = False

    def predict(self, features: dict) -> float:
        """
        Predicts safety score (0.0–1.0) for a single road segment.

        Args:
            features: dict with keys matching get_feature_columns()
                      from train_safety_model.py

        Returns:
            float: safety score 0.0 (very unsafe) to 1.0 (very safe)
        """
        if not self.loaded:
            # Fallback: weighted formula (same as schema.sql)
            return self._formula_fallback(features)

        try:
            feature_order = [
                "crime_density", "lighting_score", "crowd_score", "user_rating",
                "highway_score", "is_isolated", "police_proximity",
                "hospital_proximity", "report_penalty", "light_count", "length_norm",
            ]
            X = np.array([[features.get(f, 0.5) for f in feature_order]])
            X_scaled = self.scaler.transform(X)
            score = float(self.model.predict(X_scaled)[0])
            return max(0.05, min(0.99, score))
        except Exception as e:
            print(f"[SafetyScorer] Prediction error: {e}")
            return self._formula_fallback(features)

    def predict_with_time(self, features: dict, hour: int = None) -> float:
        """
        Same as predict() but adjusts weights based on time of day.
        Use this in the route endpoint for real-time scoring.
        """
        if hour is None:
            hour = datetime.now().hour

        base_score = self.predict(features)

        # Time-of-day adjustment
        # At night, lighting matters more so we pull the score closer
        # to the lighting component
        lighting = features.get("lighting_score", 0.5)
        crime    = features.get("crime_density", 0.5)

        if 22 <= hour or hour < 5:   # Night — lighting is critical
            adjustment = (lighting - 0.5) * 0.15 - (crime * 0.1)
        elif 18 <= hour < 22:        # Evening — moderate lighting weight
            adjustment = (lighting - 0.5) * 0.08 - (crime * 0.05)
        else:                        # Daytime — minimal lighting adjustment
            adjustment = -(crime * 0.05)

        return max(0.05, min(0.99, base_score + adjustment))

    def _formula_fallback(self, features: dict) -> float:
        """
        Formula-based safety score used when ML model isn't loaded yet.
        S = 0.4*(1-C) + 0.3*L + 0.2*P + 0.1*R
        """
        C = features.get("crime_density", 0.5)
        L = features.get("lighting_score", 0.5)
        P = features.get("crowd_score", 0.5)
        R = features.get("user_rating", 0.5)
        return max(0.05, min(0.99,
            0.4 * (1.0 - C) +
            0.3 * L +
            0.2 * P +
            0.1 * R
        ))

    def score_label(self, score: float) -> dict:
        """
        Converts a numeric score to a human-readable label and color.
        Used by the Flutter app to show safety indicators.
        """
        if score >= 0.75:
            return {"label": "Very Safe",   "color": "#2ECC71", "emoji": "✅"}
        elif score >= 0.55:
            return {"label": "Safe",        "color": "#A8D5A2", "emoji": "🟢"}
        elif score >= 0.40:
            return {"label": "Moderate",    "color": "#F39C12", "emoji": "🟡"}
        elif score >= 0.25:
            return {"label": "Caution",     "color": "#E67E22", "emoji": "🟠"}
        else:
            return {"label": "Avoid",       "color": "#E74C3C", "emoji": "🔴"}


# Singleton instance — imported by FastAPI
scorer = SafetyScorer()
