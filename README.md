# 💧 HydroFlow — Integrated Smart Water Delivery & Quality Monitoring System

---

## 📌 Project Overview

HydroFlow is an IoT-powered smart water management ecosystem designed for residential households
in Juja, Kenya. It solves three critical water management failures:

| Problem | HydroFlow Solution |
|---|---|
| 🚱 **Supply Uncertainty** — tank runs dry before user notices | **Predictive Thirst Engine** — predicts empty date, auto-prompts order |
| 🧪 **Quality Fraud** — salty borehole water sold as fresh council water | **TDS Sensor Verification** — money held in escrow until quality confirmed |
| 💧 **Silent Wastage** — hidden leaks go undetected for months | **Night Watch Algorithm** — monitors 2AM–4AM for leak patterns |

---

## 🏗️ System Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                     HydroFlow ECOSYSTEM                        │
├──────────────┬───────────────────┬───────────────────────────┤
│  IoT Layer   │   Cloud Backend   │      User Layer           │
│              │                   │                           │
│ ESP32 Chip   │  Node.js/Express  │  Flutter Mobile App       │
│ Ultrasonic   │  PostgreSQL       │  (Android — Residents)    │
│ Sensor       │  MongoDB          │                           │
│ TDS Sensor   │  Google Cloud     │  React.js Web Dashboard   │
│              │                   │  (Drivers & Admins)       │
│ [Simulated   │  M-Pesa Daraja    │                           │
│  via Python  │  Africa's Talking │                           │
│  during dev] │  Google Maps API  │                           │
└──────────────┴───────────────────┴───────────────────────────┘
```

---

## 📁 Repository Structure

```
HydroFlow/
├── 📂 hydroflow-backend/          # Node.js + Express REST API
│   ├── src/
│   │   ├── config/               # DB connections, env config
│   │   ├── controllers/          # Route handler logic
│   │   ├── middleware/           # Auth, error handling
│   │   ├── models/               # PostgreSQL + MongoDB schemas
│   │   ├── routes/               # API route definitions
│   │   ├── services/             # Business logic (Predictive Thirst, Leak Detection)
│   │   └── utils/                # Helpers, constants
│   └── tests/                    # Jest unit + integration tests
│
├── 📂 hydroflow-frontend/         # React.js Driver & Admin Dashboard
│   └── src/
│       ├── components/           # Reusable UI components
│       ├── pages/                # Route-level page components
│       ├── hooks/                # Custom React hooks
│       ├── services/             # API calls
│       └── store/                # State management (Zustand)
│
├── 📂 hydroflow-mobile/           # Flutter Mobile App (Residents)
│   └── lib/
│       ├── screens/              # App screens
│       ├── widgets/              # Reusable widgets
│       ├── services/             # API + local services
│       ├── models/               # Data models
│       └── providers/            # State (Riverpod)
│
├── 📂 hydroflow-simulator/        # Python IoT Sensor Simulator
│   ├── simulator.py              # Main simulation engine
│   ├── scenarios/                # Preset test scenarios
│   └── README.md                 # How to run the simulator
│
├── 📂 docs/                      # Project documentation
│   ├── SPRINTS.md                # Full 4-week sprint plan
│   ├── API.md                    # API endpoint reference
│   ├── DATABASE_SCHEMA.md        # DB schema documentation
│   └── SETUP.md                  # Full local setup guide
│
├── 📂 .github/
│   ├── ISSUE_TEMPLATE/           # Bug + feature templates
│   └── workflows/                # CI/CD GitHub Actions
│
├── .env.example                  # Template for environment variables
├── docker-compose.yml            # Local dev environment
├── CONTRIBUTING.md               # How to work on this project
└── README.md                     # This file
```

---

## 🛠️ Tech Stack

### Backend
- **Runtime:** Node.js v20+
- **Framework:** Express.js
- **Primary DB:** PostgreSQL (users, orders, payments)
- **Sensor DB:** MongoDB (time-series sensor data)
- **Auth:** JWT + bcrypt
- **Validation:** Zod

### Frontend (Web Dashboard)
- **Framework:** React.js 18
- **State:** Zustand
- **Styling:** Tailwind CSS
- **Maps:** Google Maps API
- **Charts:** Recharts

### Mobile App
- **Framework:** Flutter 3 (Dart)
- **State:** Riverpod
- **HTTP:** Dio

### IoT Simulation
- **Language:** Python 3.10+
- **Libraries:** requests, faker, schedule

### Integrations
- **Payments:** Safaricom M-Pesa Daraja API
- **SMS:** Africa's Talking API
- **Maps:** Google Maps Platform
- **Cloud:** Google Cloud Platform (GCP)

---

## 🚀 Quick Start

### Prerequisites
- Node.js v20+
- Python 3.10+
- Flutter 3.x
- PostgreSQL 15+
- MongoDB 7+
- Git

### 1. Clone the repository
```bash
git clone https://github.com/YOUR_USERNAME/HydroFlow.git
cd HydroFlow
```

### 2. Set up environment variables
```bash
cp .env.example .env
# Edit .env with your actual keys
```

### 3. Start the backend
```bash
cd hydroflow-backend
npm install
npm run dev
```

### 4. Start the IoT Simulator (replaces physical sensors)
```bash
cd hydroflow-simulator
pip install -r requirements.txt
python simulator.py
```

### 5. Start the web dashboard
```bash
cd hydroflow-frontend
npm install
npm run dev
```

### 6. Run the Flutter mobile app
```bash
cd hydroflow-mobile
flutter pub get
flutter run
```

> 📘 See [docs/SETUP.md](docs/SETUP.md) for the full detailed setup guide.

---

## 🔑 Key Features

### 🔮 Predictive Thirst Engine
Analyzes rolling 7-day water consumption to calculate the exact date the tank will run empty.
Sends push notifications **3 days before** to prompt a refill order.

### 🧪 Real-Time Quality Verification (TDS)
TDS sensor readings are taken the moment a delivery truck begins pumping. If salinity exceeds
**1000 PPM**, the app triggers a red alert and **M-Pesa escrow is NOT released** to the driver.

### 🔍 Night Watch Leak Detection
Between **2:00 AM – 4:00 AM**, the system checks for steady water level drops.
If >2% drop occurs with no user activity, a leak alert is fired via push notification + SMS.

### 💳 M-Pesa Escrow Payments
Customer pays into a system-held escrow. Funds are only released to the driver after:
1. Delivery is GPS-confirmed at the property
2. TDS sensor confirms water quality is within safe limits

---

## 📊 API Overview

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/auth/register` | Register new user |
| POST | `/api/auth/login` | Login & get JWT |
| GET | `/api/tank/:id/status` | Get live tank status |
| POST | `/api/tank/:id/sensor-data` | IoT simulator data ingestion |
| GET | `/api/tank/:id/prediction` | Get Predictive Thirst forecast |
| POST | `/api/orders` | Place a water order |
| PUT | `/api/orders/:id/verify` | Verify delivery & release payment |
| GET | `/api/drivers/nearby` | Find nearest available drivers |

> 📘 Full reference: [docs/API.md](docs/API.md)

---

## 🧪 Running Tests

```bash
# Backend tests
cd hydroflow-backend
npm test

# Watch mode
npm run test:watch
```

---

## 📅 Project Timeline

| Sprint | Duration | Focus |
|--------|----------|-------|
| Sprint 1 | Week 1 (Days 1–7) | Backend foundation + Database + Auth |
| Sprint 2 | Week 2 (Days 8–14) | IoT Simulator + Core APIs + Predictive Engine |
| Sprint 3 | Week 3 (Days 15–21) | React Dashboard + Flutter App core screens |
| Sprint 4 | Week 4 (Days 22–30) | M-Pesa integration + Testing + Deployment |

> 📘 Detailed day-by-day plan: [docs/SPRINTS.md](docs/SPRINTS.md)

---

## 🤝 Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development workflow and coding standards.

---

## 📄 License

© 2026 oumadavid. All rights reserved.
