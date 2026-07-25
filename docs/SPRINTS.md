# 📅 HydroFlow — 4-Week Sprint Plan

> **Duration:** 30 Days | **Daily Commitment:** 4–6 hours  
> **Methodology:** Agile (Scrum-lite) with 4 sprints  
> **Start Date:** Adjust to your actual start date

---

## 🧭 Sprint Overview

| Sprint | Days | Theme | Deliverable |
|--------|------|-------|-------------|
| Sprint 1 | 1–7 | **Foundation** | Backend server, DB schemas, Auth system live |
| Sprint 2 | 8–14 | **Core Intelligence** | IoT simulator, Predictive Thirst, Leak Detection APIs |
| Sprint 3 | 15–21 | **User Interfaces** | React Dashboard + Flutter app core screens wired to API |
| Sprint 4 | 22–30 | **Integration & Polish** | M-Pesa, Maps, SMS, testing, deployment, demo prep |

---

## ✅ Definition of Done (per task)

A task is only marked ✅ DONE when:
- [ ] Code is written and runs without errors
- [ ] Tested manually (Postman for API, browser/device for UI)
- [ ] Committed to GitHub with a meaningful commit message
- [ ] No console errors or unhandled promise rejections

---

---

# 🏃 SPRINT 1 — Foundation (Days 1–7)

**Goal:** A running backend with a database, user authentication, and a tank registration system.  
By end of Sprint 1, a user can register, log in, and register their water tank.

---

### 📆 Day 1 — Project Setup & Environment

**Theme:** Get everything installed and talking to each other.

| # | Task | Est. Time | Done? |
|---|------|-----------|-------|
| 1.1 | Create GitHub repo and push initial folder structure | 30 min | ☐ |
| 1.2 | Initialize `hydroflow-backend`: `npm init`, install Express, Nodemon, dotenv, cors | 30 min | ☐ |
| 1.3 | Create `server.js` with a basic `GET /health` route that returns `{ status: "ok" }` | 30 min | ☐ |
| 1.4 | Install and configure PostgreSQL locally, create `hydroflow_db` database | 45 min | ☐ |
| 1.5 | Install and start MongoDB locally | 20 min | ☐ |
| 1.6 | Set up `.env` file with DB connection strings and PORT | 15 min | ☐ |
| 1.7 | Test DB connections — log "PostgreSQL connected" and "MongoDB connected" on startup | 30 min | ☐ |
| 1.8 | Push to GitHub with commit: `feat: initial backend scaffold` | 10 min | ☐ |

**End-of-day check:** `npm run dev` starts the server, `/health` returns 200, both DBs connect. ✅

---

### 📆 Day 2 — Database Schema Design

**Theme:** Create all database tables and collections.

| # | Task | Est. Time | Done? |
|---|------|-----------|-------|
| 2.1 | Write PostgreSQL migration: `users` table (id, name, phone, email, password_hash, role, created_at) | 45 min | ☐ |
| 2.2 | Write PostgreSQL migration: `tanks` table (id, user_id, name, capacity_liters, location_lat, location_lng, created_at) | 30 min | ☐ |
| 2.3 | Write PostgreSQL migration: `orders` table (id, tank_id, user_id, driver_id, status, amount_ksh, escrow_status, created_at) | 45 min | ☐ |
| 2.4 | Write PostgreSQL migration: `drivers` table (id, user_id, vehicle_plate, is_verified, is_available, current_lat, current_lng) | 30 min | ☐ |
| 2.5 | Create MongoDB schema: `sensor_readings` (tank_id, water_level_percent, tds_ppm, timestamp) using Mongoose | 45 min | ☐ |
| 2.6 | Run all migrations, verify tables exist in pgAdmin or psql | 20 min | ☐ |
| 2.7 | Write `docs/DATABASE_SCHEMA.md` documenting every table/field | 30 min | ☐ |
| 2.8 | Commit: `feat: add database schemas and migrations` | 10 min | ☐ |

**End-of-day check:** All tables visible in PostgreSQL, Mongoose model importable without errors. ✅

---

### 📆 Day 3 — User Authentication

**Theme:** Secure registration and login with JWT tokens.

| # | Task | Est. Time | Done? |
|---|------|-----------|-------|
| 3.1 | Install: `bcryptjs`, `jsonwebtoken`, `zod` | 10 min | ☐ |
| 3.2 | Create `authController.js` with `register()` function (hash password, save to DB) | 60 min | ☐ |
| 3.3 | Create `authController.js` with `login()` function (compare hash, return JWT) | 45 min | ☐ |
| 3.4 | Create `authMiddleware.js` — verifies JWT on protected routes | 30 min | ☐ |
| 3.5 | Add Zod validation schemas for register/login request bodies | 30 min | ☐ |
| 3.6 | Create `routes/auth.routes.js` and wire to `server.js` | 20 min | ☐ |
| 3.7 | Test in Postman: register a user, log in, get back a JWT token | 30 min | ☐ |
| 3.8 | Test that protected route returns 401 without token, 200 with valid token | 20 min | ☐ |
| 3.9 | Commit: `feat: add JWT authentication (register + login)` | 10 min | ☐ |

**End-of-day check:** Can register, login, and hit a protected route with a JWT. ✅

---

### 📆 Day 4 — Tank Management API

**Theme:** Let users register their water tanks.

| # | Task | Est. Time | Done? |
|---|------|-----------|-------|
| 4.1 | Create `tankController.js` with `createTank()` — register a new tank for logged-in user | 45 min | ☐ |
| 4.2 | Add `getTankById()` — return tank details + latest sensor reading | 45 min | ☐ |
| 4.3 | Add `getUserTanks()` — return all tanks belonging to logged-in user | 30 min | ☐ |
| 4.4 | Create `routes/tank.routes.js` — all routes protected by `authMiddleware` | 20 min | ☐ |
| 4.5 | Test all 3 endpoints in Postman with a real JWT token | 30 min | ☐ |
| 4.6 | Add error handling — 404 if tank not found, 403 if tank belongs to different user | 30 min | ☐ |
| 4.7 | Create global `errorHandler` middleware in `middleware/errorHandler.js` | 30 min | ☐ |
| 4.8 | Commit: `feat: tank registration and retrieval API` | 10 min | ☐ |

**End-of-day check:** Can create a tank, list tanks, and get individual tank details via API. ✅

---

### 📆 Day 5 — IoT Sensor Data Ingestion API

**Theme:** Build the endpoint that receives data from the (simulated) ESP32.

| # | Task | Est. Time | Done? |
|---|------|-----------|-------|
| 5.1 | Create `sensorController.js` with `ingestSensorData()` — saves to MongoDB `sensor_readings` | 60 min | ☐ |
| 5.2 | The ingestion endpoint: `POST /api/tank/:id/sensor-data` — body: `{ water_level_percent, tds_ppm }` | 30 min | ☐ |
| 5.3 | Add API key auth for IoT endpoint (separate from JWT — a static device key in `.env`) | 30 min | ☐ |
| 5.4 | Create `getSensorHistory()` — returns last 100 readings for a tank (from MongoDB) | 30 min | ☐ |
| 5.5 | Create `getLatestReading()` — returns only the most recent reading | 20 min | ☐ |
| 5.6 | Test by manually POSTing fake sensor data via Postman | 30 min | ☐ |
| 5.7 | Verify data is appearing in MongoDB | 15 min | ☐ |
| 5.8 | Commit: `feat: IoT sensor data ingestion endpoint` | 10 min | ☐ |

**End-of-day check:** Fake sensor data POSTed via Postman shows up in MongoDB. ✅

---

### 📆 Day 6 — Driver API + Buffer Day

**Theme:** Driver profile management + catch up on anything behind.

| # | Task | Est. Time | Done? |
|---|------|-----------|-------|
| 6.1 | Create `driverController.js` with `updateDriverLocation()` — updates lat/lng in drivers table | 45 min | ☐ |
| 6.2 | Add `getNearbyDrivers()` — returns verified, available drivers sorted by distance to a given lat/lng | 60 min | ☐ |
| 6.3 | Add `toggleAvailability()` — driver sets themselves online/offline | 20 min | ☐ |
| 6.4 | Create `routes/driver.routes.js` | 20 min | ☐ |
| 6.5 | Test nearby drivers endpoint with sample lat/lng values | 20 min | ☐ |
| 6.6 | **Buffer:** Review all Sprint 1 work, fix any failing Postman tests | 60 min | ☐ |
| 6.7 | Commit: `feat: driver location and availability API` | 10 min | ☐ |

---

### 📆 Day 7 — Sprint 1 Review & Cleanup

**Theme:** Polish, document, and prepare for Sprint 2.

| # | Task | Est. Time | Done? |
|---|------|-----------|-------|
| 7.1 | Write `docs/API.md` documenting all Sprint 1 endpoints with request/response examples | 90 min | ☐ |
| 7.2 | Write `docs/SETUP.md` — how to get the project running from scratch | 60 min | ☐ |
| 7.3 | Create `.env.example` with all required keys (empty values) | 20 min | ☐ |
| 7.4 | Run through every Postman test from Days 1–6 and confirm all pass | 45 min | ☐ |
| 7.5 | Commit all outstanding files: `docs: sprint 1 complete — API and setup docs` | 10 min | ☐ |
| 7.6 | Create GitHub Issues for Sprint 2 tasks | 20 min | ☐ |

**Sprint 1 Completion Criteria:**
- [ ] Server starts with zero errors
- [ ] User can register and login
- [ ] User can create and retrieve a tank
- [ ] Sensor data can be POSTed and stored in MongoDB
- [ ] Driver location API works
- [ ] All endpoints documented in API.md

---

---

# 🏃 SPRINT 2 — Core Intelligence (Days 8–14)

**Goal:** The Python simulator is running and feeding the backend. The Predictive Thirst engine
and Night Watch Leak Detection are fully working and returning correct alerts.

---

### 📆 Day 8 — Python IoT Simulator

**Theme:** Build the brain substitute for the ESP32 sensors.

| # | Task | Est. Time | Done? |
|---|------|-----------|-------|
| 8.1 | Create `hydroflow-simulator/` folder, initialize with `pip install requests schedule` | 20 min | ☐ |
| 8.2 | Write `simulator.py` — simulates a tank starting at 80% full, dropping ~3% every 15 min | 90 min | ☐ |
| 8.3 | Add TDS simulation — normally 350 PPM (fresh), with a flag to simulate salty delivery (1200 PPM) | 45 min | ☐ |
| 8.4 | Add `--scenario` flag: `normal`, `leak`, `salty_delivery`, `low_battery` | 45 min | ☐ |
| 8.5 | `leak` scenario: between 2AM–4AM, drops 1% every 5 min even though usage should be 0 | 30 min | ☐ |
| 8.6 | POST readings to `POST /api/tank/:id/sensor-data` every 60 seconds (dev mode — not 15 min) | 20 min | ☐ |
| 8.7 | Verify data flowing into MongoDB from simulator | 20 min | ☐ |
| 8.8 | Write `hydroflow-simulator/README.md` | 20 min | ☐ |
| 8.9 | Commit: `feat: Python IoT sensor simulator with scenario modes` | 10 min | ☐ |

**End-of-day check:** Run `python simulator.py --scenario normal` and see MongoDB filling up with readings. ✅

---

### 📆 Day 9 — Predictive Thirst Engine

**Theme:** Build the algorithm that predicts when the tank will run dry.

| # | Task | Est. Time | Done? |
|---|------|-----------|-------|
| 9.1 | Create `services/predictiveService.js` | 15 min | ☐ |
| 9.2 | Write `calculateDailyUsageRate(tankId)` — queries last 7 days of readings, calculates average % drop per day | 90 min | ☐ |
| 9.3 | Write `predictEmptyDate(tankId)` — uses current level + usage rate to calculate date of depletion | 60 min | ☐ |
| 9.4 | Return: `{ current_level_percent, daily_usage_rate, estimated_empty_date, days_remaining }` | 30 min | ☐ |
| 9.5 | Add `GET /api/tank/:id/prediction` endpoint wired to predictive service | 30 min | ☐ |
| 9.6 | Test: run simulator for 10 min, then call prediction endpoint | 20 min | ☐ |
| 9.7 | Edge case: handle < 7 days of data (use available data, flag as low-confidence) | 30 min | ☐ |
| 9.8 | Commit: `feat: predictive thirst engine with empty-date forecasting` | 10 min | ☐ |

**End-of-day check:** `/api/tank/:id/prediction` returns a real estimated empty date based on simulator data. ✅

---

### 📆 Day 10 — Night Watch Leak Detection

**Theme:** Build the algorithm that detects hidden leaks.

| # | Task | Est. Time | Done? |
|---|------|-----------|-------|
| 10.1 | Create `services/leakDetectionService.js` | 15 min | ☐ |
| 10.2 | Write `analyzeNightUsage(tankId)` — queries readings between 2:00–4:00 AM from last 3 nights | 90 min | ☐ |
| 10.3 | Algorithm: if average drop > 2% during night window AND no order was placed → flag as LEAK | 60 min | ☐ |
| 10.4 | Return: `{ leak_detected: true/false, confidence: "high/medium/low", avg_night_drop_percent, recommendation }` | 30 min | ☐ |
| 10.5 | Add `GET /api/tank/:id/leak-check` endpoint | 20 min | ☐ |
| 10.6 | Test with `--scenario leak` simulator — verify leak is detected | 30 min | ☐ |
| 10.7 | Test with `--scenario normal` — verify NO false alarm is triggered | 20 min | ☐ |
| 10.8 | Commit: `feat: night watch leak detection algorithm` | 10 min | ☐ |

**End-of-day check:** Leak scenario correctly triggers `leak_detected: true`. Normal scenario returns `false`. ✅

---

### 📆 Day 11 — Notification Service

**Theme:** Fire alerts when Predictive Thirst or Leak Detection triggers.

| # | Task | Est. Time | Done? |
|---|------|-----------|-------|
| 11.1 | Create `services/notificationService.js` | 15 min | ☐ |
| 11.2 | Sign up for Africa's Talking free sandbox account, get API credentials | 20 min | ☐ |
| 11.3 | Install `africastalking` npm package | 10 min | ☐ |
| 11.4 | Write `sendSMS(phone, message)` function using Africa's Talking | 45 min | ☐ |
| 11.5 | Write `checkAndNotify(tankId)` — runs prediction + leak check, fires SMS if thresholds breached | 60 min | ☐ |
| 11.6 | Thresholds: SMS if `days_remaining <= 3` OR `leak_detected === true` | 20 min | ☐ |
| 11.7 | Create a scheduled job using `node-cron` that runs `checkAndNotify` every hour | 30 min | ☐ |
| 11.8 | Test: manually trigger the check and verify SMS arrives in Africa's Talking sandbox | 30 min | ☐ |
| 11.9 | Commit: `feat: automated SMS notifications for low water and leak alerts` | 10 min | ☐ |

**End-of-day check:** SMS notification fires when tank is low or leak is detected. ✅

---

### 📆 Day 12 — Orders API

**Theme:** Full order lifecycle from placement to completion.

| # | Task | Est. Time | Done? |
|---|------|-----------|-------|
| 12.1 | Create `orderController.js` with `createOrder()` — creates order record with status `PENDING` | 60 min | ☐ |
| 12.2 | Add `assignDriver()` — calls `getNearbyDrivers()`, assigns first available, status → `ASSIGNED` | 45 min | ☐ |
| 12.3 | Add `confirmDelivery()` — driver marks delivery started, status → `IN_PROGRESS` | 30 min | ☐ |
| 12.4 | Add `verifyAndComplete()` — checks TDS reading is < 1000 PPM, if OK status → `COMPLETED` | 45 min | ☐ |
| 12.5 | Add `cancelOrder()` — status → `CANCELLED`, refund escrow | 20 min | ☐ |
| 12.6 | Create `routes/order.routes.js` | 20 min | ☐ |
| 12.7 | Test full order lifecycle in Postman | 30 min | ☐ |
| 12.8 | Commit: `feat: full order lifecycle API` | 10 min | ☐ |

---

### 📆 Day 13 — Quality Verification Logic

**Theme:** The TDS-based verification gate that controls M-Pesa escrow.

| # | Task | Est. Time | Done? |
|---|------|-----------|-------|
| 13.1 | Create `services/qualityService.js` | 15 min | ☐ |
| 13.2 | Write `verifyWaterQuality(tankId)` — gets latest TDS reading, returns `{ is_fresh, tds_ppm, verdict }` | 60 min | ☐ |
| 13.3 | Verdict thresholds: < 500 PPM = FRESH ✅, 500–1000 = BORDERLINE ⚠️, > 1000 = SALINE ❌ | 30 min | ☐ |
| 13.4 | Wire `verifyWaterQuality` into `verifyAndComplete()` order function | 30 min | ☐ |
| 13.5 | If water is SALINE: order status → `QUALITY_FAILED`, escrow NOT released, SMS sent to user | 45 min | ☐ |
| 13.6 | Add `GET /api/tank/:id/quality` endpoint | 20 min | ☐ |
| 13.7 | Test with `--scenario salty_delivery` simulator — verify escrow is blocked | 30 min | ☐ |
| 13.8 | Commit: `feat: TDS quality verification gate for order completion` | 10 min | ☐ |

**End-of-day check:** Salty delivery correctly blocks order completion. Fresh delivery passes through. ✅

---

### 📆 Day 14 — Sprint 2 Review

**Theme:** Full backend integration test.

| # | Task | Est. Time | Done? |
|---|------|-----------|-------|
| 14.1 | Run simulator in `normal` mode for 30 min, verify full data pipeline works end-to-end | 45 min | ☐ |
| 14.2 | Run simulator in `leak` mode, verify leak SMS fires | 20 min | ☐ |
| 14.3 | Run simulator in `salty_delivery` mode, verify order quality-fails | 20 min | ☐ |
| 14.4 | Update `docs/API.md` with all Sprint 2 endpoints | 45 min | ☐ |
| 14.5 | Write at least 5 Jest unit tests for the predictive service | 60 min | ☐ |
| 14.6 | Fix any failing tests or broken endpoints | 45 min | ☐ |
| 14.7 | Commit: `test: sprint 2 integration tests and API docs update` | 10 min | ☐ |

**Sprint 2 Completion Criteria:**
- [ ] Simulator pumps data into backend continuously
- [ ] Prediction endpoint returns accurate `days_remaining`
- [ ] Leak detection correctly identifies the `leak` scenario
- [ ] Order lifecycle completes end-to-end in Postman
- [ ] Quality gate blocks salty water deliveries
- [ ] SMS notifications fire correctly

---

---

# 🏃 SPRINT 3 — User Interfaces (Days 15–21)

**Goal:** A working React dashboard for drivers/admins and core Flutter screens for residents.
Everything wired to the real backend API.

---

### 📆 Day 15 — React Dashboard Setup

| # | Task | Est. Time | Done? |
|---|------|-----------|-------|
| 15.1 | Initialize React app with Vite: `npm create vite@latest hydroflow-frontend` | 20 min | ☐ |
| 15.2 | Install: Tailwind CSS, React Router, Zustand, Axios, Recharts, React Query | 30 min | ☐ |
| 15.3 | Set up React Router with routes: `/login`, `/dashboard`, `/orders`, `/map` | 45 min | ☐ |
| 15.4 | Create `services/api.js` — Axios instance with JWT interceptor | 45 min | ☐ |
| 15.5 | Build Login page — POST to `/api/auth/login`, store token in Zustand | 60 min | ☐ |
| 15.6 | Add protected route component (redirect to /login if no token) | 30 min | ☐ |
| 15.7 | Commit: `feat: react dashboard scaffold with auth` | 10 min | ☐ |

---

### 📆 Day 16 — Driver Map Dashboard

| # | Task | Est. Time | Done? |
|---|------|-----------|-------|
| 16.1 | Set up Google Maps API key in `.env` | 15 min | ☐ |
| 16.2 | Install `@react-google-maps/api` | 10 min | ☐ |
| 16.3 | Build Map page — shows map of Juja centered at JKUAT coordinates | 60 min | ☐ |
| 16.4 | Fetch nearby tanks from `/api/drivers/nearby` and place pins on map | 45 min | ☐ |
| 16.5 | Clicking a pin shows order details popup (address, water level, order status) | 45 min | ☐ |
| 16.6 | Add driver toggle: "Go Online / Go Offline" button | 30 min | ☐ |
| 16.7 | Commit: `feat: driver map dashboard with live order pins` | 10 min | ☐ |

---

### 📆 Day 17 — Orders Management Page

| # | Task | Est. Time | Done? |
|---|------|-----------|-------|
| 17.1 | Build Orders page — table of all active orders with status badges | 60 min | ☐ |
| 17.2 | "Accept Order" button — calls `assignDriver` API, updates status in UI | 45 min | ☐ |
| 17.3 | "Mark Delivered" button — calls `confirmDelivery`, triggers quality check | 45 min | ☐ |
| 17.4 | Real-time polling: refresh orders table every 30 seconds | 30 min | ☐ |
| 17.5 | Quality result banner: green "Water Verified ✅" or red "SALTY WATER DETECTED ❌" | 45 min | ☐ |
| 17.6 | Commit: `feat: orders management page with quality verification UI` | 10 min | ☐ |

---

### 📆 Day 18 — Flutter App Setup & Auth

| # | Task | Est. Time | Done? |
|---|------|-----------|-------|
| 18.1 | Verify Flutter is installed: `flutter doctor` all green | 20 min | ☐ |
| 18.2 | Navigate to `hydroflow-mobile`, run `flutter create .` if needed | 15 min | ☐ |
| 18.3 | Install packages: `dio`, `riverpod`, `flutter_secure_storage`, `go_router` | 20 min | ☐ |
| 18.4 | Create `services/api_service.dart` — Dio instance pointing to backend URL | 45 min | ☐ |
| 18.5 | Build Login screen — phone + password fields, POST to `/api/auth/login` | 60 min | ☐ |
| 18.6 | Store JWT in `flutter_secure_storage` | 30 min | ☐ |
| 18.7 | Set up `go_router` with `/login` and `/home` routes, auto-redirect logic | 30 min | ☐ |
| 18.8 | Commit: `feat: flutter app with auth flow` | 10 min | ☐ |

---

### 📆 Day 19 — Flutter Tank Status Screen (Main Screen)

**Theme:** The "fuel gauge" screen — the most important screen in the app.

| # | Task | Est. Time | Done? |
|---|------|-----------|-------|
| 19.1 | Build Home screen with a circular water level gauge widget (0–100%) | 90 min | ☐ |
| 19.2 | Fetch live data from `GET /api/tank/:id/status` | 30 min | ☐ |
| 19.3 | Display: water level %, TDS PPM, quality verdict (FRESH/SALINE badge) | 45 min | ☐ |
| 19.4 | Display prediction card: "Estimated Empty: Tuesday, Apr 15 (3 days)" | 45 min | ☐ |
| 19.5 | Leak alert card: shows red warning banner if leak detected | 30 min | ☐ |
| 19.6 | Pull-to-refresh functionality | 20 min | ☐ |
| 19.7 | Commit: `feat: main tank status screen with gauge and predictions` | 10 min | ☐ |

**End-of-day check:** App loads, shows live data from simulator, gauge updates on refresh. ✅

---

### 📆 Day 20 — Flutter Order Flow

| # | Task | Est. Time | Done? |
|---|------|-----------|-------|
| 20.1 | Build "Order Water" screen — shows estimated cost, nearest driver distance | 60 min | ☐ |
| 20.2 | "Confirm Order" button — POST to `/api/orders` | 30 min | ☐ |
| 20.3 | Build Order tracking screen — shows order status with progress steps | 60 min | ☐ |
| 20.4 | Status steps: Placed → Driver Assigned → In Progress → Quality Check → Completed | 30 min | ☐ |
| 20.5 | Quality result screen: big GREEN ✅ or RED ❌ with TDS reading | 45 min | ☐ |
| 20.6 | Build Notifications screen — list of past alerts | 30 min | ☐ |
| 20.7 | Commit: `feat: order placement and tracking screens` | 10 min | ☐ |

---

### 📆 Day 21 — Sprint 3 Review & UI Polish

| # | Task | Est. Time | Done? |
|---|------|-----------|-------|
| 21.1 | Run simulator + open Flutter app — do full user journey end-to-end | 45 min | ☐ |
| 21.2 | Fix any UI bugs or API connection errors | 60 min | ☐ |
| 21.3 | React dashboard: add a simple analytics panel showing daily usage chart | 60 min | ☐ |
| 21.4 | Ensure app works on real Android device (not just emulator) | 30 min | ☐ |
| 21.5 | Commit: `fix: sprint 3 UI polish and end-to-end testing` | 10 min | ☐ |

**Sprint 3 Completion Criteria:**
- [ ] Flutter app shows live tank gauge, TDS reading, and prediction
- [ ] User can place an order and track its status in the app
- [ ] React dashboard shows orders map and quality verification UI
- [ ] Both interfaces connected to real backend (not dummy data)

---

---

# 🏃 SPRINT 4 — Integration & Deployment (Days 22–30)

**Goal:** M-Pesa payments integrated, app deployed, fully tested, demo-ready.

---

### 📆 Day 22 — M-Pesa Integration (Backend)

| # | Task | Est. Time | Done? |
|---|------|-----------|-------|
| 22.1 | Create Safaricom Developer account, get Daraja sandbox credentials | 30 min | ☐ |
| 22.2 | Create `services/mpesaService.js` | 15 min | ☐ |
| 22.3 | Write `getAccessToken()` — authenticates with Daraja API | 45 min | ☐ |
| 22.4 | Write `initiateSTKPush(phone, amount, orderId)` — triggers M-Pesa prompt on user's phone | 90 min | ☐ |
| 22.5 | Create `POST /api/payments/callback` — Safaricom calls this after user pays | 60 min | ☐ |
| 22.6 | On successful callback: update order `escrow_status` → `HELD` | 30 min | ☐ |
| 22.7 | Test with Safaricom sandbox simulator | 30 min | ☐ |
| 22.8 | Commit: `feat: M-Pesa STK push payment initiation` | 10 min | ☐ |

---

### 📆 Day 23 — M-Pesa Escrow Release

| # | Task | Est. Time | Done? |
|---|------|-----------|-------|
| 23.1 | Write `releaseEscrow(orderId)` — simulates paying driver (B2C in sandbox) | 60 min | ☐ |
| 23.2 | Wire `releaseEscrow` into `verifyAndComplete()` — only fires when quality check passes | 45 min | ☐ |
| 23.3 | Wire `refundEscrow(orderId)` into `cancelOrder()` and quality-fail path | 45 min | ☐ |
| 23.4 | Add `GET /api/orders/:id/payment-status` endpoint | 20 min | ☐ |
| 23.5 | Test full payment lifecycle: pay → hold → salty delivery → refund | 45 min | ☐ |
| 23.6 | Test full payment lifecycle: pay → hold → fresh delivery → release to driver | 30 min | ☐ |
| 23.7 | Commit: `feat: M-Pesa escrow hold and release on quality verification` | 10 min | ☐ |

---

### 📆 Day 24 — Payment UI in Flutter

| # | Task | Est. Time | Done? |
|---|------|-----------|-------|
| 24.1 | Add payment screen to Flutter app — shows amount and M-Pesa number | 45 min | ☐ |
| 24.2 | "Pay with M-Pesa" button — calls `initiateSTKPush`, shows "Check your phone" dialog | 45 min | ☐ |
| 24.3 | Poll payment status every 5 seconds until confirmed | 45 min | ☐ |
| 24.4 | On payment confirmed: navigate to order tracking screen | 30 min | ☐ |
| 24.5 | On quality fail: show refund screen with "Your money has been refunded" | 30 min | ☐ |
| 24.6 | Commit: `feat: M-Pesa payment UI in Flutter app` | 10 min | ☐ |

---

### 📆 Day 25 — Deployment Setup

| # | Task | Est. Time | Done? |
|---|------|-----------|-------|
| 25.1 | Create `Dockerfile` for backend | 45 min | ☐ |
| 25.2 | Create `docker-compose.yml` for local dev (backend + PostgreSQL + MongoDB) | 45 min | ☐ |
| 25.3 | Deploy backend to Railway.app (free tier) — connect PostgreSQL and MongoDB Atlas | 60 min | ☐ |
| 25.4 | Deploy React dashboard to Vercel (free tier) — update API URL to production | 30 min | ☐ |
| 25.5 | Update Flutter app's base URL to production backend | 15 min | ☐ |
| 25.6 | Verify simulator can reach production backend | 20 min | ☐ |
| 25.7 | Commit: `deploy: backend on Railway, dashboard on Vercel` | 10 min | ☐ |

---

### 📆 Day 26 — Testing Sprint

| # | Task | Est. Time | Done? |
|---|------|-----------|-------|
| 26.1 | Write Jest unit tests for `predictiveService` (at least 5 tests) | 60 min | ☐ |
| 26.2 | Write Jest unit tests for `leakDetectionService` (at least 5 tests) | 60 min | ☐ |
| 26.3 | Write Jest unit tests for `qualityService` (at least 3 tests) | 30 min | ☐ |
| 26.4 | Write integration test for full order lifecycle | 60 min | ☐ |
| 26.5 | Aim for >60% test coverage on services | 30 min | ☐ |
| 26.6 | Commit: `test: unit and integration test suite` | 10 min | ☐ |

---

### 📆 Day 27 — Bug Fixes & Edge Cases

| # | Task | Est. Time | Done? |
|---|------|-----------|-------|
| 27.1 | Test: What happens if user places order with no available drivers? | 30 min | ☐ |
| 27.2 | Test: What if network drops mid-simulation? (simulator offline mode) | 30 min | ☐ |
| 27.3 | Test: What if TDS sensor gives 0 PPM? (invalid reading) | 20 min | ☐ |
| 27.4 | Test: What if the same user places two orders simultaneously? | 20 min | ☐ |
| 27.5 | Fix all bugs found above | 120 min | ☐ |
| 27.6 | Commit: `fix: edge case handling for offline, invalid readings, concurrent orders` | 10 min | ☐ |

---

### 📆 Day 28 — GitHub CI/CD Pipeline

| # | Task | Est. Time | Done? |
|---|------|-----------|-------|
| 28.1 | Create `.github/workflows/test.yml` — runs Jest tests on every push to `main` | 45 min | ☐ |
| 28.2 | Add a GitHub Action badge to README | 10 min | ☐ |
| 28.3 | Create GitHub Issue templates for Bug Reports and Feature Requests | 30 min | ☐ |
| 28.4 | Create `CONTRIBUTING.md` with branching strategy and commit conventions | 45 min | ☐ |
| 28.5 | Ensure all tests pass in the CI pipeline | 30 min | ☐ |
| 28.6 | Commit: `ci: add GitHub Actions test pipeline` | 10 min | ☐ |

---

### 📆 Day 29 — Demo Preparation

| # | Task | Est. Time | Done? |
|---|------|-----------|-------|
| 29.1 | Create a demo seed script — `npm run seed` populates DB with realistic test data | 60 min | ☐ |
| 29.2 | Write out the demo script (what you will show and in what order) | 45 min | ☐ |
| 29.3 | Demo flow: Register → View tank gauge → Simulator triggers low alert → SMS fires → Place order → M-Pesa → Quality check → Complete | — | ☐ |
| 29.4 | Record a short screen recording of the demo using OBS or Loom | 60 min | ☐ |
| 29.5 | Update README with the production URLs and demo video link | 20 min | ☐ |
| 29.6 | Commit: `docs: demo script and seed data` | 10 min | ☐ |

---

### 📆 Day 30 — Final Commit & Review

| # | Task | Est. Time | Done? |
|---|------|-----------|-------|
| 30.1 | Final review of all code — remove all `console.log` debug statements | 30 min | ☐ |
| 30.2 | Ensure `.env.example` is complete and no real secrets in repo | 20 min | ☐ |
| 30.3 | Final README review — all links work, setup steps are accurate | 30 min | ☐ |
| 30.4 | Run full test suite one final time — all green | 20 min | ☐ |
| 30.5 | Tag the release: `git tag v1.0.0 && git push --tags` | 10 min | ☐ |
| 30.6 | Final commit: `release: v1.0.0 — HydroFlow MVP complete` | 10 min | ☐ |

---

## 📋 Sprint Summary

| Sprint | Key Output |
|--------|-----------|
| Sprint 1 ✅ | Running backend, Auth, Tank + Driver APIs, Sensor ingestion |
| Sprint 2 ✅ | Python Simulator, Predictive Thirst, Leak Detection, Quality Gate, Orders API |
| Sprint 3 ✅ | React Dashboard (Map + Orders), Flutter App (Gauge + Order Flow) |
| Sprint 4 ✅ | M-Pesa payments, Deployment, Tests, CI/CD, Demo-ready |

---

## 🚨 Risk Register

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| M-Pesa Daraja sandbox issues | Medium | High | Start M-Pesa on Day 22 not Day 30; use mock if needed |
| Flutter setup issues on Windows | Low | Medium | Use Android emulator as fallback |
| GCP/Railway deployment issues | Low | Medium | Keep local demo as backup |
| Feature scope creep | Medium | High | Stick strictly to sprint tasks; park new ideas |
| Lost time (illness, exams) | Medium | High | Days 6 & 14 are buffer days — protect them |
