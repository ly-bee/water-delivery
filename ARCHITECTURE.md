# Architecture

This explains how the system actually works today, based on reading the code — not how it was
originally planned. A few places where the real behavior has gaps or dead ends are called out
explicitly, because a new owner needs to know about those, not have them smoothed over.

## Contents
- [System overview](#system-overview)
- [Roles](#roles)
- [Order lifecycle](#order-lifecycle)
- [Driver assignment](#driver-assignment)
- [Proof of delivery](#proof-of-delivery)
- [Payments (M-Pesa)](#payments-m-pesa)
- [Data model](#data-model)
- [Third-party integrations](#third-party-integrations)

## System overview

```mermaid
graph TB
    subgraph Clients
        Resident["Resident app (Flutter)"]
        Driver["Driver app (Flutter)"]
        Admin["Admin dashboard (React)"]
    end

    subgraph Backend["hydroflow-backend (Node/Express)"]
        REST["REST API<br/>/api/*"]
        Socket["Socket.IO<br/>admin-room broadcast"]
        Auth["JWT auth + role checks"]
    end

    DB[("PostgreSQL")]
    Cloudinary["Cloudinary"]
    Mpesa["M-Pesa Daraja"]
    AT["Africa's Talking (SMS)"]
    Gmail["Gmail SMTP"]

    Resident -->|HTTPS| REST
    Driver -->|HTTPS| REST
    Admin -->|HTTPS| REST
    Admin -.->|live driver locations| Socket
    Driver -.->|GPS ping every ~10s while on a delivery| REST

    REST --> Auth
    REST --> DB
    REST --> Cloudinary
    REST --> Mpesa
    REST --> AT
    REST --> Gmail
    Socket --> DB
```

All three client apps are "dumb" in the sense that none of them contain business logic beyond form
validation and display — every decision (who gets assigned a delivery, whether a rating is allowed,
whether a payment can be started) is made in the backend controllers.

Auth is a single JWT issued at login, containing the user's `id` and `role`. Every protected route
checks the token (`protect` middleware) and, where relevant, the role (`allowRoles('admin')` etc.).
There's no separate session store — the token itself is the credential, valid until it expires
(`JWT_EXPIRES_IN`, currently `7d`).

## Roles

There are exactly three roles, stored on the `users.role` column: `resident`, `driver`, `admin`.
The same login system serves all three — what differs is which app they use and which API routes
their JWT is allowed to call.

- **Resident** — mobile app only. Places orders, tracks them, pays, rates.
- **Driver** — mobile app (different screens, same app) or can also technically log into the admin
  dashboard (the frontend has a driver view for `/orders`, but it's mostly built around admin use).
- **Admin** — web dashboard only.

## Order lifecycle

```mermaid
stateDiagram-v2
    [*] --> PENDING: resident places order,<br/>no driver auto-assigned
    [*] --> ASSIGNED: resident places order,<br/>a driver WAS auto-assigned
    PENDING --> PAID: M-Pesa payment succeeds<br/>(order had no driver yet)
    PENDING --> ASSIGNED: admin manually assigns a driver
    PAID --> ASSIGNED: admin manually assigns a driver
    ASSIGNED --> ASSIGNED: M-Pesa payment succeeds<br/>(status is preserved, not overwritten)
    PENDING --> CANCELLED: resident or admin cancels
    ASSIGNED --> CANCELLED: resident or admin cancels
    ASSIGNED --> IN_TRANSIT: driver starts the delivery
    IN_TRANSIT --> DELIVERED: driver submits proof of delivery<br/>(photo/signature + empties count)
    DELIVERED --> COMPLETED: resident confirms receipt<br/>(POST /api/quality/orders/:id/verify)
    COMPLETED --> COMPLETED: resident submits a 1-5 star rating<br/>(once only)
    CANCELLED --> [*]
    COMPLETED --> [*]
```

Payment and driver assignment are two independent tracks that can happen in either order — a driver
can be auto-assigned before or after payment, and paying doesn't require a driver to exist yet (or
vice versa). Two things that made this correct, fixed after being caught during the initial
documentation pass:

1. **The M-Pesa endpoint now accepts payment on `PENDING` or `ASSIGNED` orders**, not just `PENDING`
   — it used to reject payment outright for any order that had already been auto-assigned a driver.
2. **The payment callback no longer overwrites delivery progress.** It used to unconditionally set
   `status = 'PAID'` on a successful payment — which, for an order that already had a driver
   (`ASSIGNED`/`IN_TRANSIT`), would have silently erased that assignment status and hidden the job
   from the driver's app. It now only moves `PENDING → PAID`; an already-assigned order keeps its
   real status and just gets `mpesa_receipt`/`paid_at` recorded. The admin dashboard's "Assign
   Driver" button also now appears for `PAID` orders, not just `PENDING` (the backend already
   supported this — only the button's visibility was missing it).

Cancellation is allowed from `PENDING` or `ASSIGNED` only (a resident can't cancel once a driver is
en route or has delivered).

## Driver assignment

```mermaid
flowchart TD
    A[Resident places order] --> B{GPS location<br/>captured?}
    B -- No --> F[Order created as PENDING]
    B -- Yes --> C{Any driver<br/>available + verified?}
    C -- No --> F
    C -- Yes --> D[Compute distance to each<br/>available driver — Haversine formula]
    D --> E[Assign the nearest one]
    E --> G[Order created as ASSIGNED<br/>driver marked on_delivery]

    F --> H[Sits in PENDING until<br/>an admin manually assigns a driver]
    H --> I[Admin picks a driver from a dropdown<br/>in the Orders page]
    I --> G
```

A driver only shows up as a candidate for auto-assignment if **all** of these are true:
`is_available = true`, `is_verified = true` (an admin has to verify a driver at least once), and
they have a current GPS position on file (`current_lat`/`current_lng` not null — set by the driver
app pinging `PATCH /api/drivers/location` while online).

Once assigned, a driver is marked `on_delivery` and won't be offered new deliveries or show as
"available" until the current one reaches a terminal state (`DELIVERED`/`CANCELLED`), at which point
they're automatically flipped back to `available` — *unless* they have another active order, in which
case they stay `on_delivery`.

## Proof of delivery

```mermaid
sequenceDiagram
    participant D as Driver app
    participant API as Backend API
    participant CL as Cloudinary
    participant DB as PostgreSQL

    D->>D: Capture photo (camera)<br/>and/or signature (drawn on screen)
    D->>API: POST /api/driver/deliveries/:id/proof<br/>(multipart: photo, signature, empty_collected, notes)
    API->>API: Verify the order belongs<br/>to this driver
    API->>CL: Upload photo bytes
    CL-->>API: photo URL
    API->>CL: Upload signature bytes
    CL-->>API: signature URL
    API->>DB: Insert/update proof_of_delivery row<br/>(photo_url, signature_url, empty_collected, notes)
    API->>DB: Set order.status = DELIVERED
    API->>DB: Free up the driver if they have<br/>no other active delivery
    API-->>D: 201 success

    Note over API,DB: Resident and admin later see the same<br/>photo_url/signature_url via a LEFT JOIN<br/>on proof_of_delivery when they fetch the order.
```

Both the photo and signature are optional — the driver can submit with neither and the order still
gets marked `DELIVERED` (there's no server-side requirement that proof exists). Files are uploaded
straight from the backend (not directly from the phone to Cloudinary), so the Cloudinary API secret
never has to live inside the mobile app.

## Payments (M-Pesa)

The backend talks to Safaricom's **Daraja API**, currently configured for their **sandbox**
environment only — `MPESA_BASE_URL` is hardcoded to `https://sandbox.safaricom.co.ke` in
`mpesaService.js`. The `MPESA_ENVIRONMENT` variable in `.env` is not actually read anywhere; going
live would require changing that hardcoded URL (and getting production credentials from Safaricom),
not just flipping an env var.

Flow: resident places an order → mobile app calls `POST /api/mpesa/pay` → backend asks Safaricom to
send an STK push → mobile app polls `GET /api/mpesa/status/:orderId` every few seconds → when
Safaricom calls the backend back on `MPESA_CALLBACK_URL` with a result, the order flips to `PAID` (or
stays as-is on failure) → the poll picks up the new status and the app moves on.

In Safaricom's sandbox, no real phone receives a real prompt for arbitrary numbers — only their
shared test number (`254708374149`) is meaningful there, and even that mostly proves the request was
accepted rather than simulating a real customer PIN entry end-to-end. See
[SETUP.md](SETUP.md#common-setup-issues) for the practical implication.

## Data model

Only the fields that matter for understanding the system — not a full column dump (see the
migration files under `hydroflow-backend/src/migrations/` for the exact schema).

```mermaid
erDiagram
    USERS ||--o| DRIVERS : "is a driver via"
    USERS ||--o{ ORDERS : "places"
    DRIVERS ||--o{ ORDERS : "delivers"
    PRODUCTS ||--o{ ORDERS : "ordered as (optional)"
    ORDERS ||--o| PROOF_OF_DELIVERY : "has"
    ORDERS ||--o{ ORDER_STATUS_LOG : "history"
    USERS ||--o{ ORDER_STATUS_LOG : "changed by"

    USERS {
        uuid id PK
        string name
        string phone UK
        string email UK
        string password_hash
        string role "resident, driver, admin"
        bool is_verified
    }
    DRIVERS {
        uuid id PK
        uuid user_id FK
        string vehicle_plate
        string vehicle_info
        string status "offline, available, on_delivery, suspended"
        bool is_available
        bool is_verified
        decimal current_lat
        decimal current_lng
        decimal rating
    }
    PRODUCTS {
        uuid id PK
        string name
        int volume_liters
        decimal price_ksh
        bool is_active
    }
    ORDERS {
        uuid id PK
        uuid user_id FK
        uuid driver_id FK
        uuid product_id FK "nullable — mobile order flow doesn't use the catalog"
        int volume_liters
        int quantity
        decimal amount_ksh
        decimal delivery_fee
        string delivery_address
        decimal delivery_lat
        decimal delivery_lng
        string status "PENDING..CANCELLED, see lifecycle diagram"
        int rating "1-5, null until resident rates"
        string mpesa_receipt
        timestamp created_at
        timestamp completed_at
    }
    PROOF_OF_DELIVERY {
        uuid id PK
        uuid order_id FK, UK
        string photo_url
        string signature_url
        int empty_collected
        string notes
    }
    ORDER_STATUS_LOG {
        uuid id PK
        uuid order_id FK
        string status
        uuid changed_by FK
        timestamp changed_at
    }
```

A few notes on things that look odd but are intentional (or at least, that's how the code treats
them):
- `orders.product_id` is almost always null in practice — the mobile order screen only ever creates
  10L/20L jerrican orders with a hardcoded price, and never references the `products` catalog table.
  The `products` table and its admin-only create/update API exist but aren't used by any part of the
  UI you can currently reach.
- `orders.rating` lives directly on the order row (one rating per order, resident → order only).
  There's no separate ratings table, and no driver-level aggregate rating is computed *from* order
  ratings — the `drivers.rating` column is a completely separate field that nothing currently writes
  to (it's always whatever it was set to at driver creation, i.e. `0`).
- `otp_codes` (not shown above) is a short-lived table for phone-login codes — rows are deleted as
  soon as they're used or replaced.

## Third-party integrations

| Service | What it's used for | Where it's called from |
|---|---|---|
| **Neon (PostgreSQL)** | The only database. Everything lives here. | `hydroflow-backend/src/config/db.js` |
| **Cloudinary** | Stores proof-of-delivery photos and customer signatures | `hydroflow-backend/src/config/cloudinary.js`, called from `driverSelfController.js` |
| **Safaricom M-Pesa (Daraja)** | STK Push payments | `hydroflow-backend/src/services/mpesaService.js` — sandbox only, see above |
| **Africa's Talking** | SMS for phone-login OTP codes | `hydroflow-backend/src/services/smsService.js` — degrades gracefully if not configured (still works for local dev, code just isn't texted) |
| **Gmail (SMTP via nodemailer)** | Account verification emails for the web dashboard's password-based signup | `hydroflow-backend/src/services/emailService.js` |
| **OpenStreetMap (via Leaflet / flutter_map)** | All maps, both admin dashboard and mobile — free, no API key needed | `react-leaflet` (web), `flutter_map` (mobile) |

Notably **not** integrated, despite being mentioned in older docs/env files: Google Maps (no API key
is read anywhere in the code), MongoDB, and anything IoT-related.
