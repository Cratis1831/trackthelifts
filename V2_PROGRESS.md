# ForgeLyte Lift v2.0 Progress

Living checklist for the nutrition/product-model work described in `forgelyte_lift_food_tracking_architecture_v7.md`.

**Branch:** `feature/v2.0-nutrition`  
**Started:** 8 September 2026  
**Current cut:** Phase A — iOS product change + local diary (backend and live food APIs come later)

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
- [x] Free manual-log limit (3); barcode / AI / photo CTAs paywall for Free, honest "next update" for Pro until the backend exists.
- [x] Settings → Food Data Sources (USDA + Open Food Facts attribution).
- [x] Settings → Clear Nutrition History.
- [x] iCloud workout sync no longer requires Pro (still opt-in).
- [x] Tests for access policy, nutrition preview limit, announcement, What's New, analytics feature names.

### In this cut

Phase A is implemented on this branch. Remaining product work is Phase B/C.

### Not in this cut (intentionally)

See Phase B and C below.

---

## Phase B — Vercel backend skeleton (next)

- [ ] Decide repo location (recommendation: separate backend repo, not the marketing site).
- [ ] Neon `foods_core` + `off_products` (kept physically separate).
- [ ] `POST /api/bootstrap` (verified `appTransactionID` → HMAC `user_key` → short-lived session).
- [ ] RevenueCat server-side entitlement checks + webhook.
- [ ] `GET /api/foods/search` and `GET /api/foods/barcode/:code` with USDA then OFF fallback, OFF rate limits, no OFF search-as-you-type.
- [ ] iOS API client; no provider secrets in the app binary.

---

## Phase C — full food-entry methods

- [ ] Native barcode scan → cache → USDA → OFF → label-scan fallback.
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

### 2026-09-08 — branch + Phase A implementation

- Created `feature/v2.0-nutrition`.
- Implemented the iOS product cut: free training, Nutrition tab, Settings on Profile, local diary, announcement, nutrition-focused paywall.
- Unit tests passed (`tracktheliftsTests`).
