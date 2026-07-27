# Local Setup Guide

This walks you through running the whole system on your own machine: the backend API, the admin
web dashboard, and the Flutter mobile app (which serves both residents and drivers). Everything in
here was checked against the actual code, not assumed.

## Prerequisites

| Tool | Version | Notes |
|---|---|---|
| Node.js | 18 or newer (20 LTS recommended) | Backend requires Express 5, which needs Node 18+. Includes `npm`. |
| Flutter SDK | 3.44.x (Dart 3.12.x) | This is what the project was built and last tested against. |
| PostgreSQL | 15+ | Only if you want a **local** database — see "Database" below, you can also just use the cloud one. |
| Git | any recent version | |
| A code editor | — | VS Code with the Flutter/Dart extensions is easiest for the mobile app. |

You do **not** need Python, MongoDB, or Docker for anything currently in this repo, despite what
older docs in `docs/` may say — see [HANDOVER_NOTES.md](HANDOVER_NOTES.md).

## The pieces, and the order to start them in

1. **Database** (PostgreSQL) — needs to exist before the backend can start
2. **Backend API** (`hydroflow-backend/`) — everything else depends on this being up
3. **Admin dashboard** (`hydroflow-frontend/`) — talks to the backend
4. **Mobile app** (`hydroflow_mobile/`) — talks to the backend

---

## 1. Database

The project currently runs against a cloud PostgreSQL database on [Neon](https://neon.tech) (see
`DATABASE_URL` below) — there's no local Postgres server required to just get going, provided you're
using the project's existing Neon database or have created your own.

If you'd rather run Postgres locally instead, a `docker-compose.yml` is provided at the repo root:

```bash
docker compose up -d
```

This starts Postgres on `localhost:5433` (not the default 5432) with user `postgres`, password
`postgres123`, database `hydroflow_db`. If you use this, your `DATABASE_URL` becomes:
```
postgresql://postgres:postgres123@localhost:5433/hydroflow_db
```
(Note: nothing else in the repo currently uses this docker-compose file automatically — it's an
option, not a requirement, and it was untested as part of this documentation pass.)

## 2. Backend API (`hydroflow-backend/`)

### Install and configure

```bash
cd hydroflow-backend
npm install
cp .env.example .env
```

> ⚠️ The `.env.example` at the **repo root** is out of date and doesn't match what the code actually
> reads (it references Mongo, IoT keys, etc. — see [HANDOVER_NOTES.md](HANDOVER_NOTES.md)). Use the
> table below instead when filling in `hydroflow-backend/.env`, not the file's own comments.

### Environment variables

All of these are read directly from `process.env` somewhere in `hydroflow-backend/src`. None are
optional unless noted.

| Variable | What it's for | Where to get it |
|---|---|---|
| `PORT` | Port the API listens on | Pick one — defaults to `3000` if unset |
| `DATABASE_URL` | Full PostgreSQL connection string | From your Neon project (or your local Postgres, see above) |
| `JWT_SECRET` | Signs login tokens | Any long random string you generate yourself |
| `JWT_EXPIRES_IN` | How long a login session lasts | e.g. `7d` |
| `MPESA_CONSUMER_KEY` | M-Pesa API auth | Safaricom Daraja developer portal → your app |
| `MPESA_CONSUMER_SECRET` | M-Pesa API auth | Same as above |
| `MPESA_SHORTCODE` | The paybill/till the payment goes to | `174379` is Safaricom's public sandbox shortcode — use it for sandbox testing |
| `MPESA_PASSKEY` | Used to sign the payment request | Safaricom publishes a shared public sandbox passkey for shortcode `174379` in their docs; for a real paybill you get your own from the Daraja portal |
| `MPESA_CALLBACK_URL` | Where Safaricom sends the payment result | Must be a real, internet-reachable HTTPS URL. Locally, use a tunnel (e.g. `npx localtunnel --port 3000`) pointed at `<tunnel-url>/api/mpesa/callback` |
| `AT_API_KEY` | SMS (OTP login codes) | Africa's Talking dashboard → API key. **Optional for local dev** — see note below |
| `AT_USERNAME` | Africa's Talking account username | Use `sandbox` for testing |
| `AT_SENDER_ID` | Name SMS appears to come from | e.g. `HydroFlow` |
| `CLOUDINARY_CLOUD_NAME` | Proof-of-delivery photo/signature storage | Cloudinary dashboard → Settings → API Keys |
| `CLOUDINARY_API_KEY` | Same | Same |
| `CLOUDINARY_API_SECRET` | Same | Same |
| `GMAIL_USER` | Sends account-verification emails (web dashboard signup) | A real Gmail address |
| `GMAIL_APP_PASSWORD` | Auth for the above | **Not** your normal Gmail password — generate an "app password" from your Google Account → Security → 2-Step Verification → App passwords (requires 2FA enabled) |
| `FRONTEND_URL` | Used to build the link inside verification emails | e.g. `http://localhost:3000` while developing (see port note below) |

`GOOGLE_MAPS_API_KEY` — you may see this mentioned in old docs/`.env.example`. **It's not actually
used anywhere in the code.** Both the mobile app and the admin dashboard use OpenStreetMap (via
`flutter_map` and `react-leaflet`) for maps, not Google Maps. You can ignore this variable entirely.

> **Local dev shortcut:** you don't strictly need `AT_API_KEY`/`GMAIL_*` configured to test the
> resident/driver login flow. The phone+OTP login (used by the mobile app) always prints the OTP
> code to the backend's console (`[OTP] <phone>: <code>`) even if the SMS itself fails to send — so
> you can log in without a real SMS provider. The web dashboard's password-based login (admin/driver)
> is different — see "Verify it's working" below.

### Set up the database tables

There's no single `migrate` command that runs everything — the schema was built up as five separate
scripts, and they must run in this order (each is safe to re-run):

```bash
cd hydroflow-backend
node src/migrations/createTables.js       # users, drivers, products, orders + seeds default products
node src/migrations/addOtpTable.js        # otp_codes table
node src/migrations/addSchemaV2.js        # order_status_log, proof_of_delivery, extra columns
node src/migrations/addMissingColumns.js  # otp_codes.role, orders.quantity/return_empties
node src/migrations/addDriverStatus.js    # drivers.status, drivers.location_updated_at
```

### Create accounts to log in with

```bash
node src/scripts/createAdmin.js       # admin: phone 0700000001 / Admin@1234
node src/scripts/createTestUsers.js   # resident: 0700000002 / Customer@1234, driver: 0700000003 / Driver@1234
```

Both scripts skip creating the account if it already exists, so they're safe to re-run.

### Start it

```bash
npm run dev
```

You should see `HydroFlow server running on port 3000` (or whatever `PORT` you set). Verify with:

```bash
curl http://localhost:3000/api/health
# {"status":"ok","message":"HydroFlow server is running","timestamp":"..."}
```

---

## 3. Admin dashboard (`hydroflow-frontend/`)

```bash
cd hydroflow-frontend
npm install
```

Create `hydroflow-frontend/.env` (this file doesn't exist yet in the repo — CRA reads it automatically):

```
REACT_APP_API_URL=http://localhost:3000/api
```

Then:

```bash
npm start
```

This is a Create React App project, so `npm start` (not `npm run dev`) is correct — the top-level
`docs/SETUP.md` and old README get this wrong.

> **Port clash:** CRA defaults to port **3000**, the same port the backend uses. If the backend is
> already running, `npm start` will detect the conflict and ask "Would you like to run the app on
> another port instead?" — answer yes (it'll typically pick 3001). It opens in your browser
> automatically.

### Verify it's working

Log in with the admin account created above (phone `0700000001`, password `Admin@1234`). You should
land on the dashboard and see stats (all zero until you place a test order), an orders list, and a
drivers page with a live map.

---

## 4. Mobile app (`hydroflow_mobile/`) — resident + driver

This is a single Flutter app; which role's screens you see depends on which account you log into.

### Point it at your backend

Unlike the other two apps, **the API URL here is not an environment variable — it's a hardcoded Dart
constant** you edit directly:

`hydroflow_mobile/lib/services/api_service.dart`:
```dart
static const String baseUrl = AppConstants.baseUrl;
```
which reads from `hydroflow_mobile/lib/config/constants.dart`:
```dart
class AppConstants {
  static const String baseUrl = 'http://172.20.10.3:3000/api';
}
```

Change this IP to wherever your backend is actually reachable from the device/emulator you're
running on:
- **Android emulator** → `http://10.0.2.2:3000/api` (the emulator's alias for your machine's localhost)
- **Physical phone on the same Wi-Fi** → your computer's LAN IP (run `ipconfig` on Windows / `ifconfig`
  on Mac/Linux to find it), e.g. `http://192.168.1.42:3000/api`
- **iOS simulator** → `http://localhost:3000/api` works directly

After editing this file you need to fully rebuild the app (hot reload won't pick up a `const` change
reliably) — stop and re-run.

### Install and run

```bash
cd hydroflow_mobile
flutter pub get
flutter run
```

Pick a target device when prompted (Android emulator, connected phone, etc.). An Android emulator
needs to already be running (via Android Studio) before `flutter run`, or use `flutter devices` to
check what's available.

### Verify it's working

Log in as the test resident (phone `0700000002`, password `Customer@1234` — but note: **password
login on mobile requires the account's `is_verified` flag to be true**, which `createTestUsers.js`
already sets, so this works out of the box). Alternatively, use the phone+OTP flow with any Kenyan-
format number — the OTP will print in the backend console as described above.

You should be able to browse products, place an order, and see it appear in the admin dashboard's
orders list and in the driver app if you log in as the test driver (`0700000003` / `Driver@1234`) in
a second copy of the app (or a second emulator).

---

## Common setup issues

| Problem | Fix |
|---|---|
| Backend won't connect to the database | Double check `DATABASE_URL` — if using Neon, make sure `sslmode=require` is in the connection string (Neon requires SSL) |
| Mobile app shows "Cannot connect to server" everywhere | The hardcoded `baseUrl` in `constants.dart` doesn't match how your backend is actually reachable from that device — see the IP guidance above. This is the single most common issue. |
| Admin dashboard login says invalid credentials but you're sure the password is right | Password logins require `is_verified = true` on the account. If you registered through the dashboard's own signup form (not via `createAdmin.js`/`createTestUsers.js`), it needs a working `GMAIL_USER`/`GMAIL_APP_PASSWORD` to send the verification email — without that, the account is stuck unverified. Easiest fix for local dev: use the seed scripts instead of the signup form. |
| M-Pesa STK push never arrives on a real phone | Expected in sandbox — Safaricom's sandbox doesn't deliver real prompts to arbitrary phones. See [ARCHITECTURE.md](ARCHITECTURE.md#payments-m-pesa). |
| `npm start` in the frontend opens on the wrong/unexpected port | See the port-clash note above — it happens because the backend is also using 3000 |
