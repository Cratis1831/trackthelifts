# ForgeLyte Lift v2.0 Progress

Living checklist for the nutrition/product-model work described in `forgelyte_lift_food_tracking_architecture_v7.md`.

**Branch:** `feature/v2.0-nutrition`  
**Started:** 8 September 2026  
**Current cut:** Phase C product is on-device. Remaining work is production backend, legal/privacy, App Store copy, and launch QA.

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
- [x] Free manual-log limit (3); barcode / AI / Nutrition Facts CTAs paywall for Free. Barcode scanning, Describe with AI, and Nutrition Facts label scan are live for Pro. Meal-photo recognition is not in the product.
- [x] Settings → Food Data Sources (USDA + Open Food Facts attribution).
- [x] Settings → Clear Nutrition History.
- [x] iCloud workout sync no longer requires Pro (still opt-in).
- [x] Tests for access policy, nutrition preview limit, announcement, What's New, analytics feature names.

### In this cut

Phase A is implemented on this branch. Phase C food-entry methods are implemented except optional catalogue contribution and nutrition-history backup.

### Not in this cut (intentionally)

- Meal-photo recognition.
- Nutrition diary on iCloud / CloudKit.
- Optional global custom-food contribution.
- Pro nutrition-history backend backup/sync (diary stays local).
- App Store product ID rename to `com.forgelyte.lift.pro.*`.

---

## Phase B — Vercel backend skeleton

- [x] Repo location: [`Cratis1831/forgelyte_server`](https://github.com/Cratis1831/forgelyte_server) (cloned to `../forgelyte_server`). Not the marketing site.
- [x] Neon schema: `foods_core` + `off_products` kept physically separate (`migrations/001_init.sql`). Apply with `npm run migrate` after `DATABASE_URL` is set.
- [x] `POST /api/bootstrap` — verified Apple `AppTransaction` JWS → HMAC `fl_…` `user_key` → 7-day session. No install-ID fallback.
- [x] RevenueCat server-side entitlement checks (`Pro`) with a short cache + `POST /api/revenuecat/webhook`.
- [x] `GET /api/foods/search` and `GET /api/foods/barcode/:code` — in-memory/DB cache → USDA (if needed) → rate-limited OFF; OFF never written to `foods_core`. Neon can wait.
- [x] iOS API client on this branch (`ForgeLyteAPI` / `ForgeLyteSession`); USDA/OFF/OpenAI keys stay on the server.

Still needed to go live: Vercel production project, env vars from `forgelyte_server/.env.example` (real USDA key, OpenAI, RevenueCat secret + webhook auth), RevenueCat webhook URL, then point release iOS builds at the production host. Neon can wait if live USDA/OFF keep working.

---

## Phase C — full food-entry methods

- [x] Native barcode scan → local custom foods → server cache → USDA → OFF → Nutrition Facts label or manual entry if missing.
- [x] Luna text describe (`POST /api/foods/ai/describe`) with structured JSON and DB matching.
- [x] Nutrition Facts label scan (`POST /api/foods/ai/label`): on-device Vision gate, then Luna extracts the panel only. Meal-photo recognition is out of scope.
- [x] User confirmation UI; AI estimates marked `estimated`.
- [x] Copy meal from the last 5 days (or Copy to today from a past day). Saved meals live on-device and can be added from Add Food without catalogue search.
- [x] Serving editor on Log Food: amount × unit (serving / g / oz / lb / kg) scales calories and macros.
- [x] Calories-first targets: daily calories → percent or grams → split. Percents must add to 100%.
- [x] Shared confirmation overlay (`AppDialog`) for destructive nutrition, workout, history, and paywall actions.
- [x] Onboarding: lifting tour → nutrition diary → nutrition logging → trial → name last.
- [x] Free trial is shown only after StoreKit/RevenueCat says this Apple ID is eligible (delete/reinstall cannot mint a second trial).
- [x] Yearly “SAVE X%” uses this storefront’s monthly × 12 vs yearly, not a hardcoded 44.
- [ ] Optional explicit global contribution (private custom foods by default). Not required to ship 2.0.
- [ ] Pro nutrition-history backup/sync (not iCloud). Not required to ship 2.0; diary stays local.

---

## Launch remaining (ship 2.0)

Product code on this branch is the 2.0 cut. These are the leftover launch items:

- [ ] Deploy `forgelyte_server` to Vercel production and fill env vars (USDA production key, OpenAI, `FORGELYTE_SERVER_SECRET`, RevenueCat secret + webhook).
- [ ] Point RevenueCat webhooks at the production host; point **release** iOS builds at that host (debug stays on `http://127.0.0.1:3000`).
- [ ] Update marketing-site Privacy Policy for local diary, catalogue search, Describe with AI, and Nutrition Facts uploads (no meal photos).
- [ ] Terms of Service / contribution clause if we mention user-submitted foods; otherwise keep Terms aligned with “no contribution in 2.0”.
- [ ] App Store Connect privacy nutrition label for nutrition + off-device AI (label images / describe text).
- [ ] Refresh in-app What's New (still says search/barcode/AI are “upcoming”) and App Store listing copy, screenshots, and promotional text.
- [ ] Confirm App Store Connect: Yearly 3-day intro offer, Monthly $5.99 with no trial, Lifetime hidden from new purchases.
- [ ] Device QA on a real iPhone: barcode, label scan, Describe, free-preview limit, trial eligibility after restore, paywall regional savings %.
- [ ] Optional: Neon migrate if we want a persistent catalogue cache in production.

---

## Notes / follow-ups

- App Store Connect + RevenueCat still use the existing product IDs (`com.ashkansdev.track_the_lifts.Monthly` / `Annual`). Architecture’s `com.forgelyte.lift.pro.*` IDs are a later catalog change, not a blocker for this branch.
- Yearly 3-day free trial is configured in App Store Connect and `TrackTheLifts.storekit` ($39.99/year, $5.99/month). The paywall reads StoreKit prices and computes yearly savings from those prices; debug builds use the StoreKit config on the scheme.
- Privacy Policy / Terms live on the marketing site (`forgelyte-lift.vercel.app`) and must be updated before shipping nutrition AI.
- Existing complimentary RevenueCat `Pro` grants continue to work; they now unlock nutrition instead of workout extras.
- `IAP.md` still describes the old workout-Pro model in most sections; only product prices were updated. Refresh or drop it before an external handoff.

---

## Session log

### 2026-09-09 — trial eligibility + regional yearly savings

- Intro offers wait for RevenueCat/StoreKit eligibility. Ineligible until Apple returns `.eligible`, and blocked if the Apple ID already has Pro or prior paid/trial history, so deleting the app cannot start a second free trial.
- Yearly Best Value “SAVE X%” is `1 − (yearly / (monthly × 12))` from the current storefront prices. Hidden when yearly is not cheaper.

### 2026-09-09 — onboarding, dialogs, starter-routine dupes, targets

- Onboarding is welcome → workouts → routines → progress → personalization → ready → nutrition diary → nutrition logging → trial → name (always last). Skip from the lifting tour lands on nutrition; trial “Not now” still requires the name page.
- Destructive confirms use the same overlay as Clear Meal (`AppDialog` / `AppChoiceDialog`).
- Duplicate starter Push/Pull/Legs/Full Body from iCloud + local seed collapse to one of each name.
- Nutrition targets are three steps: calories (locked while typing), then % or grams, then split. Disclaimer uses ForgeLyte Lift. Debug Settings can reset the v2.0 “training is free” announcement.

### 2026-09-09 — OFF per-serving dump + label serving accuracy

- Open Food Facts often writes per-serving Nutrition Facts into `*_100g`. Server `offLabelServingDumpedAs100g` is no longer drink-only, so barcode/search servings match the panel more often.

### 2026-09-09 — diary delete, rounding, target splits

- Swipe to delete a food on the Nutrition diary (meal rows are real list rows). Meal `⋯` has Clear meal, with a confirmation.
- Saving a meal shows a confirmation after the name alert.
- Serving amounts keep up to 5 decimals; calories, macros/micros, and macro % splits round to whole numbers. oz/lb/kg conversions stay exact internally.
- Targets can be Calories & % (e.g. 40/40/20) or grams. 1 g protein = 4 kcal, 1 g carb = 4, 1 g fat = 9. Grams mode fills calories; calories can still be edited after.

### 2026-09-09 — copy/save meals + serving sizes

- Meal cards can copy from the last five days (local diary only) or copy a past meal to today with a destination meal picker. Save meal stores a named snapshot on-device; Add Food lists saved meals so staples don’t need another catalogue search.
- Log Food has a serving row: change `0.5` serving or switch g/oz/lb/kg. Calories and macros follow the original portion.

### 2026-09-09 — Nutrition Facts label scan, no meal photos

- Meal-photo recognition is removed from Add Food, paywall, and Pro benefits. It is a poor fit next to search, barcode, and Describe.
- Scan Nutrition Facts uses a tall panel viewfinder. Vision OCR on-device must see a Nutrition Facts / Valeur nutritive heading plus serving/calorie markers before any image is uploaded.
- `POST /api/foods/ai/label` extracts a panel into structured per-serving nutrition, or returns `not_a_label`. JPEG is recompressed (EXIF stripped) and not stored. Barcode misses offer this as the fallback.

### 2026-09-09 — catalogue search fallback

- Open Food Facts `cgi/search.pl` 503 plus USDA `DEMO_KEY` 429 made search return an empty 200, so Add Food only showed local recents. Search now uses `search.openfoodfacts.org` first, keeps cgi as fallback, and does not trip the 60s OFF circuit when the search index works.
- Empty cache plus both live sources down now returns 503 `catalogue_unavailable`. Add Food shows that error (or a no-matches card) with Try Again instead of swallowing it.

### 2026-09-09 — search ranking, fiber, USDA/OFF attribution

- Search no longer treats three weak OFF hits as “enough”; generic queries like `banana` still go to USDA Foundation/SR. Ranking prefers produce (`Bananas, raw`) over chips/yogurt, and result rows show brand, serving, and P/C/F/Fi.
- OFF attribution now includes ODbL on each result. USDA and OFF caches stay in separate tables; the app only stores a private diary snapshot plus source id.
- Add Food collapses Scan/Photo/Describe/Manual into a top-right menu while searching. Fiber is on the diary, targets, and manual/AI entry.

### 2026-09-09 — paywall prices, feature list, food names

- Debug StoreKit config now matches v2 Pro pricing: Yearly $39.99 with a 3-day trial, Monthly $5.99 with no trial. Trial cards show “3 days free” plus the renewal price instead of looking like a $1.99 week.
- Removed the extra “Ongoing Nutrition Features” paywall row so the purchase button stays on screen.
- Food names are title-cased when they arrive in all lowercase (`chicken breast` → `Chicken Breast`).

### 2026-09-09 — catalogue search guards + Describe lookup

- Search memoizes non-empty results for 15 minutes (server + iOS session). Neon still optional; live USDA/OFF are skipped once a query already has ≥3 hits or a score ≥ 80.
- USDA `DEMO_KEY` is capped at 25/hour; a 429 stops further USDA calls for that window. OFF 503 trips a 60s circuit so Describe does not keep hammering.
- Describe lookup: Luna parse → drop prep words (`skinless boneless chicken breast` → `chicken breast`) → same search path → top matches; iOS still requires a catalogue match or a manual calorie edit before Add.

### 2026-09-08 — Phase C Describe with AI

- Pro Describe with AI sends the meal text to `POST /api/foods/ai/describe`, shows parsed foods with catalogue matches, and logs confirmed rows as `AI_ESTIMATE`.
- Unmatched items must be edited before they can be added. Photo and Nutrition Facts label remain later.

### 2026-09-08 — Phase C barcode scanning

- Pro Scan Barcode opens a VisionKit camera (or a typed UPC field on Simulator / no camera).
- Lookup uses the existing `/api/foods/barcode/:code` path. Misses offer manual entry with the barcode attached; Nutrition Facts label scan remains later.

### 2026-09-08 — Phase B backend + catalogue search

- Scaffolded `forgelyte_server` from the Furry Pals Vercel/Neon/App Transaction pattern (no sticker/credits/blob code).
- iOS bootstraps a ForgeLyte session after RevenueCat configure, logs into RevenueCat with the HMAC `user_key`, and searches the catalogue after a pause (not per keystroke).
- Native barcode camera, Luna photo/label, and nutrition backup remain Phase C.

### 2026-09-08 — local API testing

- `forgelyte_server` can run with `npm run dev` at `http://127.0.0.1:3000`. Debug iOS builds use that host.
- `npm run smoke` / local search-barcode-describe verified USDA, Open Food Facts, and OpenAI (`gpt-5.6-luna`) without putting keys in the app.

### 2026-09-08 — branch + Phase A implementation

- Created `feature/v2.0-nutrition`.
- Implemented the iOS product cut: free training, Nutrition tab, Settings on Profile, local diary, announcement, nutrition-focused paywall.
- Unit tests passed (`tracktheliftsTests`).
