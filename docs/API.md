# 📡 HydroFlow API Reference

Base URL: `http://localhost:3000/api`  
All protected endpoints require: `Authorization: Bearer <JWT_TOKEN>`

---

## 🔐 Authentication

### POST `/auth/register`
Register a new user (resident or driver).

**Request Body:**
```json
{
  "name": "Maggy Maji",
  "phone": "0712345678",
  "email": "maggy@example.com",
  "password": "securePassword123",
  "role": "resident"
}
```
`role` can be: `resident` | `driver` | `admin`

**Response 201:**
```json
{
  "message": "User registered successfully",
  "user": {
    "id": "uuid",
    "name": "Maggy Maji",
    "phone": "0712345678",
    "role": "resident"
  },
  "token": "eyJhbGci..."
}
```

---

### POST `/auth/login`
Login and receive a JWT token.

**Request Body:**
```json
{
  "phone": "0712345678",
  "password": "securePassword123"
}
```

**Response 200:**
```json
{
  "token": "eyJhbGci...",
  "user": {
    "id": "uuid",
    "name": "Maggy Maji",
    "role": "resident"
  }
}
```

---

## 💧 Tank Management

### POST `/tanks` 🔒
Register a new water tank.

**Request Body:**
```json
{
  "name": "Main Roof Tank",
  "capacity_liters": 5000,
  "location_lat": -1.0989,
  "location_lng": 37.0118
}
```

**Response 201:**
```json
{
  "id": "uuid",
  "name": "Main Roof Tank",
  "capacity_liters": 5000,
  "user_id": "uuid",
  "created_at": "2026-02-15T10:00:00Z"
}
```

---

### GET `/tanks` 🔒
Get all tanks belonging to the authenticated user.

**Response 200:**
```json
[
  {
    "id": "uuid",
    "name": "Main Roof Tank",
    "capacity_liters": 5000,
    "latest_reading": {
      "water_level_percent": 67,
      "tds_ppm": 342,
      "timestamp": "2026-02-15T14:30:00Z"
    }
  }
]
```

---

### GET `/tanks/:id/status` 🔒
Get full tank status including latest sensor reading.

**Response 200:**
```json
{
  "id": "uuid",
  "name": "Main Roof Tank",
  "capacity_liters": 5000,
  "current_level_percent": 67,
  "current_volume_liters": 3350,
  "tds_ppm": 342,
  "quality_verdict": "FRESH",
  "last_updated": "2026-02-15T14:30:00Z"
}
```

---

## 📡 Sensor Data (IoT Ingestion)

### POST `/tanks/:id/sensor-data`
Receive data from the ESP32 / Python simulator.  
**Auth:** `x-device-api-key: <IOT_DEVICE_API_KEY>` header (NOT a JWT)

**Request Body:**
```json
{
  "water_level_percent": 65.4,
  "tds_ppm": 387
}
```

**Response 201:**
```json
{
  "message": "Sensor data recorded",
  "reading_id": "mongodb_object_id"
}
```

---

### GET `/tanks/:id/sensor-history` 🔒
Returns last 100 sensor readings for a tank.

**Response 200:**
```json
[
  {
    "water_level_percent": 67.2,
    "tds_ppm": 342,
    "timestamp": "2026-02-15T14:30:00Z"
  },
  {
    "water_level_percent": 67.8,
    "tds_ppm": 340,
    "timestamp": "2026-02-15T14:15:00Z"
  }
]
```

---

## 🔮 Predictive Thirst Engine

### GET `/tanks/:id/prediction` 🔒
Returns water depletion forecast based on usage history.

**Response 200:**
```json
{
  "current_level_percent": 67,
  "daily_usage_rate_percent": 22.5,
  "estimated_empty_date": "2026-02-18T09:00:00Z",
  "days_remaining": 3,
  "confidence": "high",
  "recommendation": "Order water within the next 24 hours to avoid running dry."
}
```

`confidence`: `"high"` (7+ days data) | `"medium"` (3–6 days) | `"low"` (< 3 days)

---

## 🔍 Leak Detection

### GET `/tanks/:id/leak-check` 🔒
Analyzes night-time usage patterns for hidden leaks.

**Response 200 (leak detected):**
```json
{
  "leak_detected": true,
  "confidence": "high",
  "avg_night_drop_percent": 3.8,
  "analysis_window": "2:00 AM – 4:00 AM",
  "nights_analyzed": 3,
  "recommendation": "A steady water drop was detected during overnight hours. Check all pipes, joints, and toilet cisterns immediately."
}
```

**Response 200 (no leak):**
```json
{
  "leak_detected": false,
  "confidence": "high",
  "avg_night_drop_percent": 0.1,
  "recommendation": "No leak patterns detected. Your plumbing appears normal."
}
```

---

## 🧪 Water Quality

### GET `/tanks/:id/quality` 🔒
Returns the current water quality verdict.

**Response 200:**
```json
{
  "tds_ppm": 342,
  "verdict": "FRESH",
  "is_safe": true,
  "measured_at": "2026-02-15T14:30:00Z",
  "thresholds": {
    "fresh_max_ppm": 500,
    "borderline_max_ppm": 1000,
    "saline_above_ppm": 1000
  }
}
```

`verdict`: `"FRESH"` | `"BORDERLINE"` | `"SALINE"`

---

## 🚚 Orders

### POST `/orders` 🔒
Place a new water delivery order.

**Request Body:**
```json
{
  "tank_id": "uuid",
  "volume_liters": 3000,
  "notes": "Please come before 6 PM"
}
```

**Response 201:**
```json
{
  "id": "uuid",
  "status": "PENDING",
  "tank_id": "uuid",
  "amount_ksh": 1500,
  "escrow_status": "PENDING_PAYMENT",
  "created_at": "2026-02-15T10:00:00Z"
}
```

---

### GET `/orders/:id` 🔒
Get order details and current status.

**Response 200:**
```json
{
  "id": "uuid",
  "status": "ASSIGNED",
  "driver": {
    "name": "John Kamau",
    "phone": "0723456789",
    "vehicle_plate": "KCB 123A",
    "distance_km": 2.4
  },
  "amount_ksh": 1500,
  "escrow_status": "HELD",
  "quality_check_result": null
}
```

**Order statuses:** `PENDING` → `ASSIGNED` → `IN_PROGRESS` → `QUALITY_CHECK` → `COMPLETED` | `QUALITY_FAILED` | `CANCELLED`

---

### PUT `/orders/:id/verify` 🔒
Driver marks delivery complete — triggers quality check and escrow release.

**Response 200 (fresh water):**
```json
{
  "status": "COMPLETED",
  "quality_check": {
    "tds_ppm": 380,
    "verdict": "FRESH",
    "passed": true
  },
  "escrow_status": "RELEASED_TO_DRIVER",
  "message": "Delivery verified. Payment released to driver."
}
```

**Response 200 (salty water):**
```json
{
  "status": "QUALITY_FAILED",
  "quality_check": {
    "tds_ppm": 1450,
    "verdict": "SALINE",
    "passed": false
  },
  "escrow_status": "REFUNDED",
  "message": "Water quality failed. Your M-Pesa payment has been refunded."
}
```

---

## 🚗 Drivers

### GET `/drivers/nearby?lat=&lng=` 🔒
Find available drivers near a location.

**Query Params:** `lat`, `lng`, `radius_km` (default: 10)

**Response 200:**
```json
[
  {
    "id": "uuid",
    "name": "John Kamau",
    "distance_km": 2.4,
    "vehicle_plate": "KCB 123A",
    "is_verified": true
  }
]
```

---

### PUT `/drivers/location` 🔒 (Driver only)
Update driver's current GPS location.

**Request Body:**
```json
{
  "lat": -1.0989,
  "lng": 37.0118
}
```

---

### PUT `/drivers/availability` 🔒 (Driver only)
Toggle online/offline status.

**Request Body:**
```json
{
  "is_available": true
}
```

---

## 💳 Payments

### POST `/payments/initiate` 🔒
Trigger M-Pesa STK Push to user's phone.

**Request Body:**
```json
{
  "order_id": "uuid",
  "phone": "0712345678"
}
```

**Response 200:**
```json
{
  "message": "M-Pesa prompt sent to 0712345678. Please complete payment on your phone.",
  "checkout_request_id": "ws_CO_..."
}
```

---

### POST `/payments/callback`
Safaricom M-Pesa callback (called automatically by Safaricom — not by your app).

---

### GET `/payments/status/:orderId` 🔒
Check payment status for an order.

**Response 200:**
```json
{
  "order_id": "uuid",
  "payment_status": "CONFIRMED",
  "escrow_status": "HELD",
  "amount_ksh": 1500,
  "mpesa_receipt": "QGH2TR8..."
}
```

---

## ❌ Error Responses

All errors follow this format:

```json
{
  "error": "SHORT_ERROR_CODE",
  "message": "Human-readable description of what went wrong"
}
```

| HTTP Code | Meaning |
|-----------|---------|
| 400 | Bad request / validation error |
| 401 | Not authenticated (missing/invalid JWT) |
| 403 | Forbidden (authenticated but not authorized) |
| 404 | Resource not found |
| 409 | Conflict (e.g., duplicate email) |
| 500 | Internal server error |
