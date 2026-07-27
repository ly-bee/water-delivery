# Handover Notes

Practical notes for whoever is taking this system over — written after reading through the actual
code, not the original plan for it. Treat this as the most trustworthy document in the repo about
"what's really here," since the older `docs/` files were not updated as the project's scope changed.

## The docs are more ambitious than the code — read this first

The original `README.md`, `CONTRIBUTING.md`, and everything in `docs/` (`API.md`,
`DATABASE_SCHEMA.md`, `SPRINTS.md`) describe a much bigger original vision: IoT tank-level sensors
(ESP32 + ultrasonic + TDS sensors), a Python sensor simulator, a "Predictive Thirst Engine", an
overnight leak-detection algorithm, MongoDB for sensor time-series data, M-Pesa **escrow** tied to
water-quality verification, Google Maps, Zustand, Tailwind, Riverpod, Dio, and a Jest test suite.

**None of that exists in the code.** What was actually built is the simpler system these new docs
describe: a straightforward order → assign → deliver → confirm → rate marketplace, backed by
PostgreSQL only, using OpenStreetMap instead of Google Maps, with no automated tests. The one trace
of the original "quality verification" idea left in the code is the `/api/quality/orders/:id/verify`
endpoint — its name is a leftover from that plan, but it now just means "resident confirms they
received the order" (see [ARCHITECTURE.md](ARCHITECTURE.md#order-lifecycle)).

**Recommendation:** archive or delete `docs/API.md`, `docs/DATABASE_SCHEMA.md`, `docs/SPRINTS.md`,
and the original `CONTRIBUTING.md` branching strategy — they'll actively mislead anyone who reads
them expecting to find those features. I haven't deleted them myself since that's a judgment call
that's really yours to make, not something to do silently while writing docs.

## Known limitations / rough edges

Roughly in order of how much they'd affect a real user — **except #1, which is the single most
important thing in this document.**

1. 🔴 **A "sandbox" M-Pesa test on this project caused a real deduction from a real M-Pesa account.**
   During development, an STK push initiated against the sandbox credentials/shortcode (`174379`)
   delivered a real prompt to a real phone, and completing it actually debited the resident's real
   M-Pesa balance. This directly contradicts what's commonly documented about how Safaricom's sandbox
   is supposed to behave, and the root cause was never conclusively identified. **Do not assume any
   M-Pesa test against this codebase — sandbox or otherwise — is free of real financial risk.**
   Recommended before doing any further payment testing: get written confirmation from Safaricom
   about exactly what shortcode `174379` and these specific credentials can and can't do, consider
   requesting fresh sandbox credentials from a Daraja account you control, and test only with amounts
   you'd be OK losing. See [ARCHITECTURE.md](ARCHITECTURE.md#payments-m-pesa) for what's confirmed.
2. ~~M-Pesa payment could only be started on a `PENDING` order, but orders could skip straight to
   `ASSIGNED`~~ — **fixed.** Payment now works on `PENDING` or `ASSIGNED` orders, the payment callback
   no longer overwrites an in-progress delivery status back down to `PAID`, and the admin dashboard's
   "Assign Driver" button now appears for `PAID` orders too. See
   [ARCHITECTURE.md](ARCHITECTURE.md#order-lifecycle) for how it works now.
3. **Payment confirmation is now self-reported by the resident, not verified against Safaricom.**
   After the callback-reliability and real-money issues above, the app was changed so the resident
   taps "I've paid" rather than the app waiting on Safaricom's callback (see
   [ARCHITECTURE.md](ARCHITECTURE.md#payments-m-pesa)). This trades payment-verification rigor for
   reliability — a resident could tap "I've paid" without having paid. The only mitigation right now
   is that self-reported confirmations are recorded distinguishably (`mpesa_receipt` is the literal
   string `RESIDENT_CONFIRMED` if no code was typed in) — nothing currently cross-checks a typed-in
   code against Safaricom's actual records, and there's no admin view built yet to review these.
4. **M-Pesa is hard-coded to Safaricom's sandbox** (`MPESA_BASE_URL` in `mpesaService.js`). The
   `MPESA_ENVIRONMENT` variable in `.env` looks like it should control this but isn't read anywhere.
   Going live with real payments needs a code change plus Safaricom production credentials (which
   require a registered business and KYC — not something you get instantly).
5. **The mobile app's backend URL is a hardcoded constant**, not configuration —
   `hydroflow_mobile/lib/config/constants.dart`. Anyone building the app for a new environment (or
   even just a different Wi-Fi network during development) has to remember to edit this file and
   rebuild. This already caused a real "why can't I connect" bug earlier in this project's life.
6. **No automated tests anywhere.** `hydroflow-backend`'s `npm test` is a no-op
   (`echo "No tests yet"`). Frontend has the default CRA testing setup installed but no tests written
   against it. There is no CI running any of this.
7. **Email verification (web dashboard signup) will silently strand a user if Gmail isn't
   configured.** `GMAIL_USER`/`GMAIL_APP_PASSWORD` failing just gets logged server-side; the user gets
   a "check your email" message and then has no way to ever verify, since there's no admin UI to
   manually verify an account. (Workaround for local dev: use `createAdmin.js`/`createTestUsers.js`,
   which insert accounts already verified.)
8. **A handful of API endpoints exist but nothing in the UI calls them** — confirmed by checking for
   any button/page that references them: `POST /api/drivers/register`, `POST`/`PUT /api/products`
   (admin product catalog management — there's no products page in the admin dashboard), and
   `POST /api/quality/orders/:id/report`. Not bugs, just unfinished/unused surface area — worth
   knowing about before assuming a feature exists because the API for it does.
9. **The M-Pesa routes are registered twice** (`/api/mpesa/*` and `/api/payments/mpesa/*` both point
   at the exact same controller functions — see `hydroflow-backend/src/server.js`). Harmless, but
   redundant; worth picking one and removing the other next time you're in that code.
10. **`drivers.rating` is a column that's never written to** — it's always whatever it was at driver
    creation (`0`, or whatever a seed script set it to). The rating shown in the admin dashboard is
    computed live from `orders.rating` instead, which is the one that's actually correct/live.

## Where credentials live, and what to do about them

Everything sensitive lives in `hydroflow-backend/.env`, which is git-ignored (never committed) —
meaning **the only copy of these credentials is on whichever machine currently has that file.** As
the new owner, you should:

1. **Get the current `.env` file directly from whoever hands this project over** — it's not in the
   repo and I can't hand it to you through documentation.
2. **Rotate every credential in it once you have it**, since the previous owner/developer will still
   have copies otherwise:
   - **Neon (`DATABASE_URL`)** — transfer the Neon project to your own account, or create a fresh
     database under your account and re-run the migration scripts in [SETUP.md](SETUP.md) against it.
   - **Cloudinary** — transfer account ownership, or create a new Cloudinary account and swap in new
     `CLOUDINARY_*` keys (existing uploaded proof-of-delivery images would stay on the old account
     either way unless you migrate them).
   - **M-Pesa (Safaricom Daraja)** — labelled "sandbox," but see limitation #1 above: this has
     already caused a real deduction from a real account, so don't treat these as low-risk
     throwaway credentials. If this moves to production you'll separately need to register your own
     business with Safaricom directly; ownership doesn't "transfer."
   - **Africa's Talking** — transfer or recreate the account/API key.
   - **Gmail app password** — this is tied to a personal Gmail account's 2FA settings. You almost
     certainly want your own dedicated Gmail (or proper transactional email service) rather than
     inheriting someone's personal account credentials long-term.
   - **`JWT_SECRET`** — generate a brand new random value. Changing it invalidates every existing
     login session, which is fine (everyone just logs in again) and is good practice for a handover
     regardless.
3. Also check who owns the **GitHub repo** itself (`github.com/ly-bee/water-delivery`, per the git
   remote) and transfer or fork it as appropriate for your situation.

## Suggested next steps

Roughly in the order I'd tackle them:

1. **Get the real-money-in-sandbox issue (limitation #1) resolved with Safaricom before any further
   payment testing.** Everything else on this list can wait; this one is about actual money.
2. Rotate credentials as described above, before doing anything else with real user data.
3. Decide whether self-reported payment confirmation (limitation #3) is acceptable long-term, or
   whether it's worth the effort of getting the callback path working reliably (e.g. a stable public
   URL for the backend) so payments are independently verified again instead of trusted on the
   resident's word.
4. Replace the stale `docs/` and `CONTRIBUTING.md` content (or delete it) so it stops contradicting
   reality.
5. Get *something* deployed (see [DEPLOYMENT.md](DEPLOYMENT.md)) — right now this only runs on a
   developer's laptop, which means it can't be handed to a real resident or driver to use yet.
6. Add at least a handful of backend tests around the order lifecycle and payment flow — those are
   the highest-stakes code paths and currently have zero automated coverage, so every change to them
   is verified by hand.
7. Decide whether the unused surface area (product catalog management, `drivers.rating`, the
   duplicate M-Pesa routes) should be finished, wired up, or removed — right now it's just ambiguous
   dead weight.

## Things I flagged rather than guessed

Everything above is based on what the code actually does. A few things I deliberately did **not**
assume, and you may want to confirm yourself:
- What the actual business/pricing plan is for the 10L vs 20L pricing, delivery fee, and whether the
  unused `products` catalog was meant to eventually replace the hardcoded pricing.
- Who currently owns the Neon, Cloudinary, Africa's Talking, and Gmail accounts, and whether they're
  personal or already business accounts.
- Whether there's a target production M-Pesa paybill/till already arranged with Safaricom, or whether
  that process hasn't started.
