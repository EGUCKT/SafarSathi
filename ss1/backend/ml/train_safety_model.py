"""
SafarSathi — Module 04: ML Safety Score Engine
Trains a Random Forest model on road segment features to predict
a Safety Index (0.0 to 1.0) for every road segment.

Run ONCE to train and save the model:
    cd saferoute/backend
    python ml/train_safety_model.py

The saved model is then loaded by the FastAPI backend (Module 6)
to score new segments and re-score existing ones in real time.
"""

import os
import sys
import joblib
import numpy as np
import pandas as pd
from datetime import datetime
from sqlalchemy import create_engine, text
from sklearn.ensemble import RandomForestRegressor, GradientBoostingRegressor
from sklearn.model_selection import train_test_split, cross_val_score
from sklearn.preprocessing import StandardScaler
from sklearn.metrics import mean_absolute_error, r2_score
from dotenv import load_dotenv

load_dotenv()

DATABASE_URL = os.getenv("DATABASE_URL")
MODEL_DIR    = os.path.join(os.path.dirname(__file__))
MODEL_PATH   = os.path.join(MODEL_DIR, "safety_model.joblib")
SCALER_PATH  = os.path.join(MODEL_DIR, "safety_scaler.joblib")

engine = create_engine(DATABASE_URL)

def log(msg): print(f"[ML] {msg}")


# ── Step 1: Feature engineering ───────────────────────────────────────────────

def build_features_from_db() -> pd.DataFrame:
    log("Loading pre-computed features for ML training...")
    
    query = "SELECT * FROM ml_training_features"
    
    with engine.connect() as conn:
        result = conn.execute(text(query))
        df = pd.DataFrame(result.fetchall(), columns=result.keys())
    
    # Clean up any lingering NaNs from the spatial joins
    df = df.fillna(0)
    
    log(f"Ready! Loaded {len(df)} segments with full spatial features.")
    return df


def engineer_features(df: pd.DataFrame) -> pd.DataFrame:
    """
    Converts raw DB columns into ML-ready numeric features.
    This is where domain knowledge becomes model input.
    """
    log("Engineering features...")

    # ── Highway type encoding ─────────────────────────────────────────────────
    # Map road types to numeric safety weight
    # (pedestrian paths are more vulnerable, major roads have more visibility)
    highway_safety = {
        "motorway": 0.85, "trunk": 0.80, "primary": 0.75,
        "secondary": 0.70, "tertiary": 0.65, "residential": 0.60,
        "living_street": 0.65, "pedestrian": 0.50, "service": 0.50,
        "footway": 0.35, "path": 0.30, "track": 0.25, "unclassified": 0.50,
    }
    df["highway_score"] = df["highway_type"].apply(
        lambda x: next((v for k,v in highway_safety.items() if k in str(x)), 0.50)
    )

    # ── Is isolated / footpath ────────────────────────────────────────────────
    isolated_types = ["footway", "path", "track", "pedestrian"]
    df["is_isolated"] = df["highway_type"].apply(
        lambda x: 1 if any(t in str(x) for t in isolated_types) else 0
    )

    # ── Normalize distances to 0-1 scale ─────────────────────────────────────
    # Closer to police = safer. Cap at 5000m (5km)
    df["dist_police_m"]   = df["dist_police_m"].fillna(5000).clip(0, 5000)
    df["dist_hospital_m"] = df["dist_hospital_m"].fillna(5000).clip(0, 5000)

    df["police_proximity"]   = 1.0 - (df["dist_police_m"] / 5000)
    df["hospital_proximity"] = 1.0 - (df["dist_hospital_m"] / 5000)

    # ── Report signals ────────────────────────────────────────────────────────
    df["nearby_reports"]     = df["nearby_reports"].fillna(0).clip(0, 10)
    df["nearby_bad_reports"] = df["nearby_bad_reports"].fillna(0).clip(0, 10)
    df["light_count"]        = df["light_count"].fillna(0).clip(0, 20)

    # Bad reports reduce safety, good reports (police_presence) increase it
    df["report_penalty"] = (df["nearby_bad_reports"] / 10.0)

    # ── Road length: very short or very long roads are slightly less safe ─────
    df["length_norm"] = df["length_meters"].fillna(50).clip(5, 1000) / 1000.0

    # ── Fill remaining NaNs ───────────────────────────────────────────────────
    for col in ["crime_density","lighting_score","crowd_score","user_rating"]:
        df[col] = df[col].fillna(0.5)

    log(f"  Features engineered: {len(df.columns)} columns")
    return df


def get_feature_columns():
    """Returns the exact list of features used to train and predict."""
    return [
        "crime_density",       # C: historical crime (0=safe, 1=dangerous)
        "lighting_score",      # L: streetlight density (0=dark, 1=well lit)
        "crowd_score",         # P: crowd/popularity (0=isolated, 1=busy)
        "user_rating",         # R: crowd feedback (0=bad, 1=good)
        "highway_score",       # road type safety weight
        "is_isolated",         # 1 if footpath/track
        "police_proximity",    # 0-1, closer to police = higher
        "hospital_proximity",  # 0-1, closer to hospital = higher
        "report_penalty",      # 0-1, more bad reports = higher penalty
        "light_count",         # raw count of nearby lights
        "length_norm",         # normalized road length
    ]


# ── Step 2: Generate training labels ─────────────────────────────────────────

def generate_training_labels(df: pd.DataFrame) -> pd.Series:
    """
    Since we don't have ground-truth safety labels from humans,
    we use the existing safety_score (computed by formula in schema.sql)
    as our training target, then augment with domain-specific adjustments.

    This is called "weak supervision" — a common ML technique when
    labeled data doesn't exist.

    When you get real data (police reports, user surveys), replace this
    with those ground-truth labels for better accuracy.
    """
    log("Generating training labels (weak supervision)...")

    # Base: existing formula-based safety score
    y = df["safety_score"].copy()

    # Apply domain adjustments on top:

    # 1. Footpaths/tracks are inherently less safe regardless of other factors
    y = y - (df["is_isolated"] * 0.15)

    # 2. Proximity to police boosts safety
    y = y + (df["police_proximity"] * 0.10)

    # 3. Bad crowd reports reduce safety
    y = y - (df["report_penalty"] * 0.20)

    # 4. High crime density is the strongest negative signal
    y = y - (df["crime_density"] * 0.15)

    # 5. Good lighting boosts safety
    y = y + (df["lighting_score"] * 0.05)

    # Clip to valid range
    y = y.clip(0.05, 0.99)

    log(f"  Label stats — min: {y.min():.2f}, max: {y.max():.2f}, mean: {y.mean():.2f}")
    return y


# ── Step 3: Train model ───────────────────────────────────────────────────────

def train_model(X: pd.DataFrame, y: pd.Series):
    """
    Trains a Random Forest Regressor on the safety features.
    Random Forest chosen because:
    - Handles mixed feature types well
    - Doesn't need GPU
    - Fast to train on small datasets
    - Gives feature importance (explainability for judges!)
    """
    log("Training Random Forest model...")
    log(f"  Training data: {len(X)} samples, {len(X.columns)} features")

    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42
    )

    # Scale features
    scaler = StandardScaler()
    X_train_scaled = scaler.fit_transform(X_train)
    X_test_scaled  = scaler.transform(X_test)

    # Random Forest
    model = RandomForestRegressor(
        n_estimators=200,       # 200 trees
        max_depth=10,           # prevent overfitting
        min_samples_split=5,
        min_samples_leaf=2,
        random_state=42,
        n_jobs=-1,              # use all CPU cores
    )
    model.fit(X_train_scaled, y_train)

    # Evaluate
    y_pred = model.predict(X_test_scaled)
    mae    = mean_absolute_error(y_test, y_pred)
    r2     = r2_score(y_test, y_pred)

    log(f"  Model trained!")
    log(f"  MAE (Mean Absolute Error): {mae:.4f}  ← lower is better")
    log(f"  R² Score:                  {r2:.4f}  ← closer to 1.0 is better")

    # Feature importance — great for your presentation!
    log("\n  Feature Importance (what the model learned matters most):")
    importance = sorted(
        zip(X.columns, model.feature_importances_),
        key=lambda x: x[1], reverse=True
    )
    for feat, imp in importance:
        bar = "█" * int(imp * 40)
        log(f"    {feat:<25} {bar} {imp:.3f}")

    return model, scaler


# ── Step 4: Update DB with ML-predicted scores ────────────────────────────────

def update_db_with_predictions(df: pd.DataFrame, model, scaler):
    """
    Runs the trained model on ALL road segments and updates their
    safety_score in the database with the ML-predicted value.
    """
    log("\nUpdating database with ML-predicted safety scores...")

    feature_cols = get_feature_columns()
    X_all = df[feature_cols].fillna(0.5)
    X_scaled = scaler.transform(X_all)
    predictions = model.predict(X_scaled).clip(0.05, 0.99)

    df["ml_safety_score"] = predictions

    updated = 0
    with engine.connect() as conn:
        for _, row in df.iterrows():
            try:
                conn.execute(text("""
                    UPDATE road_segments
                    SET safety_score = :score,
                        last_updated = NOW()
                    WHERE id = :id
                """), {"score": float(row["ml_safety_score"]), "id": int(row["id"])})
                updated += 1
            except:
                continue
        conn.commit()

    log(f"  Updated {updated} road segments with ML safety scores")

    # Print score distribution
    bins = [0, 0.2, 0.4, 0.6, 0.8, 1.0]
    labels = ["Very Unsafe", "Unsafe", "Moderate", "Safe", "Very Safe"]
    df["safety_band"] = pd.cut(df["ml_safety_score"], bins=bins, labels=labels)
    dist = df["safety_band"].value_counts().sort_index()
    log("\n  Safety Score Distribution across Indore + Mhow:")
    for band, count in dist.items():
        pct = round(count / len(df) * 100)
        bar = "█" * (pct // 2)
        log(f"    {band:<12} {bar} {count} segments ({pct}%)")


# ── Step 5: Save model ────────────────────────────────────────────────────────

def save_model(model, scaler):
    joblib.dump(model,  MODEL_PATH)
    joblib.dump(scaler, SCALER_PATH)
    log(f"\nModel saved:  {MODEL_PATH}")
    log(f"Scaler saved: {SCALER_PATH}")
    log("FastAPI backend will load these files automatically.")


# ── Step 6: Time-of-day weight adjuster (used at inference time) ──────────────

def get_time_weights(hour: int) -> dict:
    """
    Returns weight multipliers based on time of day.
    Used by the FastAPI route endpoint — NOT during training.

    At 2 AM: lighting matters most.
    At 2 PM: crime history and crowd matter more.

    Example usage (in route engine):
        weights = get_time_weights(datetime.now().hour)
        score = (weights['crime'] * (1 - crime_density) +
                 weights['lighting'] * lighting_score + ...)
    """
    if 22 <= hour or hour < 5:      # Night (10 PM – 5 AM)
        return {"crime": 0.30, "lighting": 0.40, "crowd": 0.20, "rating": 0.10}
    elif 5 <= hour < 9:             # Early morning
        return {"crime": 0.35, "lighting": 0.30, "crowd": 0.25, "rating": 0.10}
    elif 9 <= hour < 18:            # Daytime
        return {"crime": 0.40, "lighting": 0.15, "crowd": 0.30, "rating": 0.15}
    else:                           # Evening (6 PM – 10 PM)
        return {"crime": 0.35, "lighting": 0.30, "crowd": 0.25, "rating": 0.10}


# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    log("=" * 55)
    log("SafarSathi — Safety Score ML Engine")
    log("=" * 55)

    if not DATABASE_URL:
        log("ERROR: DATABASE_URL not set in .env")
        sys.exit(1)

    # 1. Load data from DB
    df = build_features_from_db()

    if len(df) < 10:
        log("ERROR: Not enough data. Run pipeline.py first.")
        sys.exit(1)

    # 2. Engineer features
    df = engineer_features(df)

    # 3. Prepare training data
    feature_cols = get_feature_columns()
    X = df[feature_cols].fillna(0.5)
    y = generate_training_labels(df)

    # 4. Train model
    model, scaler = train_model(X, y)

    # 5. Update DB with ML scores
    update_db_with_predictions(df, model, scaler)

    # 6. Save model files
    save_model(model, scaler)

    log("\n" + "=" * 55)
    log("ML engine done! Two files created in backend/ml/:")
    log("  safety_model.joblib  ← the trained Random Forest")
    log("  safety_scaler.joblib ← the feature scaler")
    log("Next: Build Module 5 — Route optimizer (NetworkX)")
    log("=" * 55)


if __name__ == "__main__":
    main()
