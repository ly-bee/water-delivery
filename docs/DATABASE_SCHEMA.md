# 🗄️ HydroFlow — Database Schema

HydroFlow uses a **hybrid database** approach:
- **PostgreSQL** — structured data (users, orders, payments, drivers)
- **MongoDB** — time-series sensor data (high-volume, fast writes)

---

## PostgreSQL Tables

### `users`
Stores all user accounts (residents, drivers, admins).

| Column | Type | Notes |
|--------|------|-------|
| `id` | UUID (PK) | Auto-generated |
| `name` | VARCHAR(100) | Full name |
| `phone` | VARCHAR(15) | Unique. Used for login + M-Pesa |
| `email` | VARCHAR(100) | Optional, unique |
| `password_hash` | VARCHAR(255) | bcrypt hashed |
| `role` | ENUM | `resident`, `driver`, `admin` |
| `created_at` | TIMESTAMP | Auto-set |

---

### `tanks`
Water storage tanks registered by residents.

| Column | Type | Notes |
|--------|------|-------|
| `id` | UUID (PK) | |
| `user_id` | UUID (FK → users) | Owner of the tank |
| `name` | VARCHAR(100) | e.g., "Main Roof Tank" |
| `capacity_liters` | INTEGER | Total tank size |
| `location_lat` | DECIMAL(10,7) | For GPS matching with drivers |
| `location_lng` | DECIMAL(10,7) | |
| `created_at` | TIMESTAMP | |

---

### `drivers`
Extended profile for users with role `driver`.

| Column | Type | Notes |
|--------|------|-------|
| `id` | UUID (PK) | |
| `user_id` | UUID (FK → users) | 1:1 relationship |
| `vehicle_plate` | VARCHAR(20) | |
| `is_verified` | BOOLEAN | Admin-verified badge |
| `is_available` | BOOLEAN | Online/offline toggle |
| `current_lat` | DECIMAL(10,7) | Updated in real-time |
| `current_lng` | DECIMAL(10,7) | |

---

### `orders`
Water delivery orders from placement to completion.

| Column | Type | Notes |
|--------|------|-------|
| `id` | UUID (PK) | |
| `tank_id` | UUID (FK → tanks) | Target delivery tank |
| `user_id` | UUID (FK → users) | Customer who placed order |
| `driver_id` | UUID (FK → drivers) | Assigned driver (null until assigned) |
| `volume_liters` | INTEGER | How much water ordered |
| `amount_ksh` | DECIMAL(10,2) | Price in Kenyan Shillings |
| `status` | ENUM | See order statuses below |
| `escrow_status` | ENUM | See escrow statuses below |
| `quality_verdict` | ENUM | `FRESH`, `BORDERLINE`, `SALINE`, null |
| `tds_at_delivery` | INTEGER | PPM reading taken at delivery |
| `mpesa_receipt` | VARCHAR(50) | M-Pesa transaction code |
| `notes` | TEXT | Customer notes |
| `created_at` | TIMESTAMP | |
| `completed_at` | TIMESTAMP | |

**Order Statuses:**
```
PENDING → ASSIGNED → IN_PROGRESS → QUALITY_CHECK → COMPLETED
                                                  → QUALITY_FAILED
                   → CANCELLED
```

**Escrow Statuses:**
```
PENDING_PAYMENT → HELD → RELEASED_TO_DRIVER
                       → REFUNDED
```

---

## MongoDB Collection

### `sensor_readings`
High-frequency data from IoT sensors (or Python simulator).

```javascript
{
  _id: ObjectId,
  tank_id: String,        // UUID matching PostgreSQL tanks.id
  water_level_percent: Number,  // 0.0 – 100.0
  tds_ppm: Number,        // Total Dissolved Solids (salinity)
  timestamp: Date,        // When reading was taken
  source: String          // "esp32" | "simulator"
}
```

**Indexes:**
- `{ tank_id: 1, timestamp: -1 }` — for fast "latest reading" queries
- TTL index on `timestamp` — auto-delete readings older than 90 days

---

## Entity Relationship Diagram

```
users ──────────────────────── tanks
  │  (1 user has many tanks)     │
  │                              │ (1 tank has many orders)
  │                              │
drivers ─────────────────── orders
  │  (1 driver handles many)     │
  │                              │ 
  └──────────────────────────────┘
                                 │
                                 sensor_readings (MongoDB)
                           (1 tank has many readings)
```
