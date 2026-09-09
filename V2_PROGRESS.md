# ForgeLyte Lift v2.0 Progress

Living checklist for the nutrition/product-model work described in `forgelyte_lift_food_tracking_architecture_v7.md`.

**Branch:** `feature/v2.0-nutrition`  
**Started:** 8 September 2026  
**Current cut:** Phase C — native barcode scan (AI describe/photo/label still later)

Design rule for every UI change: reuse the existing dark canvas, surface cards, borders, type, `IconTile`, `EmptyStateView`, `AppPrimaryButtonStyle` / `AppSecondaryButtonStyle`, and accent-as-highlight language. Do not introduce a second visual system.

---

## Product decisions locked for v2.0

- Workout / lifting tracker is fully free (logging, history, routines, supersets, RPE/RIR, charts, themes, iCloud workout sync).
- ForgeLyte Pro is nutrition + ongoing AI/cloud services.
- Lifetime is hidden from new purchases; existing Lifetime entitlements still unlock `Pro` if RevenueCat says they do, but do **not** grant nutrition/AI/backend just because of a historical Lifetime SKU unless we later choose that.
- Nutrition diary is local SwiftData only. It is **never** attached to the CloudKit workout store.
- No email/password account.
- Free preview: view the Nutrition tab, set calorie/macro targets, log a small number of manual foods, then the paywall.

---

## Phase A — this branch (iOS product cut)

### Done

- [x] Open `feature/v2.0-nutrition` from current `main` (includes in-progress analytics work).
- [x] Add this progress file.
- [x] Bump marketing version to **2.0.0**.
- [x] Ungate every workout Pro feature so training is free.
- [x] Retarget `ProFeature`, paywall, Pro benefits, Settings upgrade copy, and onboarding trial page to nutrition.
- [x] Hide Lifetime (and Weekly) from the paywall merchandising list; prefer Yearly.
- [x] Move Settings off the tab bar onto Profile (trailing gear).
- [x] Add a Nutrition tab (`fork.knife`) where Settings used to be.
- [x] One-time "training is free / Pro is nutrition" announcement sheet for existing users.
- [x] What's New notes for 2.0.0.
- [x] Local SwiftData models: `FoodLog`, `CustomFood` on a **separate local-only** store.
- [x] Nutrition dashboard (day totals, macros, meals) matching current cards/typography.
- [x] Manual add/edit/delete food + local recent/custom search.
- [x] Free manual-log limit (3); barcode / AI / photo CTAs paywall for Free. Barcode scanning is live for Pro; AI / photo stay "next update" until Luna endpoints exist.
- [x] Settings → Food Data Sources (USDA + Open Food Facts attribution).
- [x] Settings → Clear Nutrition History.
- [x] iCloud workout sync no longer requires Pro (still opt-in).
- [x] Tests for access policy, nutrition preview limit, announcement, What's New, analytics feature names.

### In this cut

Phase A is implemented on this branch. Remaining product work is Phase B/C.

### Not in this cut (intentionally)

See Phase B and C below.

---

## Phase B — Vercel backend skeleton

- [x] Repo location: [`Cratis1831/forgelyte_server`](https://github.com/Cratis1831/forgelyte_server) (cloned to `../forgelyte_server`). Not the marketing site.
- [x] Neon schema: `foods_core` + `off_products` kept physically separate (`migrations/001_init.sql`). Apply with `npm run migrate` after `DATABASE_URL` is set.
- [x] `POST /api/bootstrap` — verified Apple `AppTransaction` JWS → HMAC `fl_…` `user_key` → 7-day session. No install-ID fallback.
- [x] RevenueCat server-side entitlement checks (`Pro`) with a short cache + `POST /api/revenuecat/webhook`.
- [x] `GET /api/foods/search` and `GET /api/foods/barcode/:code` — cache → USDA → rate-limited OFF; OFF never written to `foods_core`.
- [x] iOS API client on this branch (`ForgeLyteAPI` / `ForgeLyteSession`); USDA/OFF/OpenAI keys stay on the server.

Still needed to go live: Vercel project, Neon database, env vars from `forgelyte_server/.env.example`, RevenueCat webhook URL, then set the iOS host if it is not `https://forgelyte-server.vercel.app`.

---

## Phase C — full food-entry methods

- [x] Native barcode scan → local custom foods → server cache → USDA → OFF → manual entry if missing (label-scan fallback still later).
- [ ] Luna text describe (`POST /api/foods/ai/describe`) with structured JSON and DB matching.
- [ ] Luna vision meal photo + Nutrition Facts label; crop/resize/strip EXIF; discard images after processing.
- [ ] User confirmation UI; AI estimates marked `estimated`.
- [ ] Optional explicit global contribution (private custom foods by default).
- [ ] Pro nutrition-history backup/sync (not iCloud).
- [ ] Privacy Policy, Terms contribution clause, App Store privacy label review.

---

## Notes / follow-ups

- App Store Connect + RevenueCat still use the existing product IDs (`com.ashkansdev.track_the_lifts.Monthly` / `Annual`). Architecture’s `com.forgelyte.lift.pro.*` IDs are a later catalog change, not a blocker for this branch.
- Yearly 3-day free trial is configured in App Store Connect; the app already reads StoreKit intro offers. After ASC is updated, paywall copy will show the real trial automatically.
- Privacy Policy / Terms live on the marketing site (`forgelyte-lift.vercel.app`) and must be updated before shipping nutrition AI/photos.
- Existing complimentary RevenueCat `Pro` grants continue to work; they now unlock nutrition instead of workout extras.

---

## Session log

### 2026-09-08 — Phase C barcode scanning

- Pro Scan Barcode opens a VisionKit camera (or a typed UPC field on Simulator / no camera).
- Lookup uses the existing `/api/foods/barcode/:code` path. Misses offer manual entry with the barcode attached; Nutrition Facts label scan remains later.

### 2026-09-08 — Phase B backend + catalogue search

- Scaffolded `forgelyte_server` from the Furry Pals Vercel/Neon/App Transaction pattern (no sticker/credits/blob code).
- iOS bootstraps a ForgeLyte session after RevenueCat configure, logs into RevenueCat with the HMAC `user_key`, and searches the catalogue after a pause (not per keystroke).
- Native barcode camera, Luna describe/photo/label, and nutrition backup remain Phase C.

### 2026-09-08 — local API testing

- `forgelyte_server` can run with `npm run dev` at `http://127.0.0.1:3000`. Debug iOS builds use that host.
- `npm run smoke` / local search-barcode-describe verified USDA, Open Food Facts, and OpenAI (`gpt-5.6-luna`) without putting keys in the app.

### 2026-09-08 — branch + Phase A implementation

- Created `feature/v2.0-nutrition`.
- Implemented the iOS product cut: free training, Nutrition tab, Settings on Profile, local diary, announcement, nutrition-focused paywall.
- Unit tests passed (`tracktheliftsTests`).
