SafarSathi is an intelligent safety navigation platform designed to protect users during journeys
between Indore and Mhow. Built with a Flutter frontend and a FastAPI backend, it integrates open-source
OSM street graphs with a weak-supervision Random Forest ML model to predict real-time road safety scores.
The app offers dynamic safe-routing preferences, persistent background tracking with automatic route
deviation and inactivity alerts, local audio-based scream triggers, and a SOS system that dispatches alerts via Twilio SMS integration.

AI-Powered Safety Scoring: The backend (train_safety_model.py/safety_scorer.py) uses a Random Forest
Regressor trained on crime density, lighting data, crowd presence, and local feedback to predict safety ratings (0.0 to 1.0) for every street segment.

Dynamic Route Optimization: In route_optimizer.py, a custom Dijkstra's routing engine modifies edge
weights based on safety scores: weight = distance × (1 / safety_score). It offers Safest, Balanced,
and Shortest routes, adjusting safety weights based on the time of day (e.g., prioritizing streetlights at night).

Standby Guardian Service: The Flutter daemon (guardian_service.dart) monitors journeys in the background
to detect:
Route Deviation: Off-track by 150m.
Dead-man Switch: Lack of movement or response for several minutes.
Scream Detection: Microphone input exceeding $85\text{dB}$ for over a second.
Fail-Safe SOS System: In sos_screen.dart, users can hold the button for  3 seconds to trigger SOS.
It notifies emergency contacts via streams real-time GPS locations via Firebase Realtime Database, and logs events through FastAPI to send Twilio alerts.
