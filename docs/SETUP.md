# 🛠️ HydroFlow — Local Setup Guide

Follow this guide from top to bottom to get the full HydroFlow system running on your machine.

---

## Prerequisites

Install these before starting:

| Tool | Version | Download |
|------|---------|---------|
| Node.js | v20+ | https://nodejs.org |
| Python | 3.10+ | https://python.org |
| Flutter | 3.x | https://flutter.dev |
| PostgreSQL | 15+ | https://postgresql.org |
| MongoDB | 7+ | https://mongodb.com |
| Git | Any | https://git-scm.com |
| Postman | Any | https://postman.com |

---

## Step 1: Clone the Repository

```bash
git clone https://github.com/YOUR_USERNAME/HydroFlow.git
cd HydroFlow
```

---

## Step 2: Set Up Environment Variables

```bash
cp .env.example .env
```

Open `.env` and fill in:
- `POSTGRES_PASSWORD` — your local PostgreSQL password
- `JWT_SECRET` — any random string (e.g., run `openssl rand -base64 32`)
- `IOT_DEVICE_API_KEY` — any random string (e.g., `hydroflow-dev-device-key-123`)
- Leave M-Pesa, Africa's Talking, and Google Maps keys empty for now (Sprint 4)

---

## Step 3: Set Up PostgreSQL

```bash
# Connect to PostgreSQL
psql -U postgres

# Create the database
CREATE DATABASE hydroflow_db;
\q
```

---

## Step 4: Start the Backend

```bash
cd hydroflow-backend
npm install
npm run dev
```

You should see:
```
[HydroFlow] Server running on port 3000
[HydroFlow] PostgreSQL connected
[HydroFlow] MongoDB connected
```

Test it:
```bash
curl http://localhost:3000/api/health
# Returns: {"status":"ok","timestamp":"..."}
```

---

## Step 5: Start the IoT Simulator

Open a **new terminal tab**:

```bash
cd hydroflow-simulator
pip install -r requirements.txt

# Normal usage simulation (tank slowly depletes)
python simulator.py --tank-id YOUR_TANK_ID --scenario normal

# Simulate a leak (drops at night)
python simulator.py --tank-id YOUR_TANK_ID --scenario leak

# Simulate salty delivery
python simulator.py --tank-id YOUR_TANK_ID --scenario salty_delivery
```

To get a `tank_id`, first register a user and create a tank via Postman (see API.md).

---

## Step 6: Start the React Dashboard

Open a **new terminal tab**:

```bash
cd hydroflow-frontend
npm install
npm run dev
```

Open browser: `http://localhost:5173`

---

## Step 7: Run the Flutter Mobile App

```bash
cd hydroflow-mobile
flutter pub get

# Start an Android emulator first, then:
flutter run
```

Make sure the API base URL in Flutter points to `http://10.0.2.2:3000` (Android emulator's 
localhost alias) instead of `http://localhost:3000`.

---

## Step 8: Run Tests

```bash
cd hydroflow-backend
npm test
```

---

## Quick Reference — All Running Services

| Service | Command | URL |
|---------|---------|-----|
| Backend API | `npm run dev` in `hydroflow-backend/` | http://localhost:3000 |
| React Dashboard | `npm run dev` in `hydroflow-frontend/` | http://localhost:5173 |
| IoT Simulator | `python simulator.py` in `hydroflow-simulator/` | — (pushes to backend) |
| Flutter App | `flutter run` in `hydroflow-mobile/` | Android emulator |

---

## Troubleshooting

**"PostgreSQL connection refused"**  
→ Make sure PostgreSQL service is running: `sudo service postgresql start`

**"MongoDB connection refused"**  
→ Make sure MongoDB service is running: `sudo service mongod start`

**"Port 3000 already in use"**  
→ Kill the process: `lsof -ti:3000 | xargs kill`

**Flutter "No devices found"**  
→ Start Android emulator from Android Studio first, then run `flutter devices`
