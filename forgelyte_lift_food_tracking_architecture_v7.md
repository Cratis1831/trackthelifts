# ForgeLyte Lift — Food Tracking Architecture, Cost, Privacy & Licensing Plan

**Prepared:** September 8, 2026  
**Status:** V1 implementation plan  
**Scope:** Food search, manual foods, barcode scanning, GPT-5.6 Luna text/vision, nutrition-label capture, shared food catalogue, and personal food diary.

> **Important:** This plan is intentionally conservative about licensing and privacy. It is an engineering/compliance design, not legal advice. Before a large commercial launch, the final Terms of Service and Privacy Policy should be reviewed by a qualified lawyer familiar with Canadian privacy law and software/data licensing.

---

## 1. Core ForgeLyte Lift constraints

ForgeLyte Lift should continue to work **without traditional user accounts**:

- No email/password account required.
- No name required for the food-tracking feature.
- No social login required.
- Do not create a conventional user-profile database just to support nutrition tracking.
- Keep personal diet history separate from the shared/global food catalogue.
- Use the minimum amount of user-identifying data necessary.

### V1 recommendation

**Personal food diary:** local on the device using SwiftData/local storage.

**Shared/global food catalogue:** backend Postgres database (for example Neon).

**AI/API calls:** go through the ForgeLyte backend so API keys are never shipped in the iOS app.

**Optional future cross-device diary restore:** use an anonymous stable `user_key` derived server-side from Apple's verified `appTransactionID`; do not require an email/password account.

Apple documents that `appTransactionID` is unique for the Apple Account + app and remains the same when the app is redownloaded on another device with the same Apple Account.

Recommended derivation:

```text
StoreKit AppTransaction.shared
        ↓
verified Apple-signed AppTransaction
        ↓
send signed/verifiable identity to ForgeLyte backend
        ↓
extract appTransactionID
        ↓
HMAC-SHA256(appTransactionID, SERVER_SECRET)
        ↓
anonymous user_key
```

Do **not** expose or use the raw `appTransactionID` as a public database identifier.

---

# 2. Important Apple health-data decision

Do **not** plan to sync the nutrition diary through iCloud/CloudKit.

Apple's current App Review Guidelines for health/fitness apps state that apps may not store personal health information in iCloud.

Because ForgeLyte Lift is a fitness application and a nutrition diary can reasonably be treated as health-related data, the conservative implementation is:

### V1

```text
Personal food diary
    ↓
SwiftData / local device
```

### Optional future sync

```text
Personal food diary
    ↓
ForgeLyte backend
    ↓
opaque anonymous user_key
```

That allows cross-device recovery without creating a normal user account.

The **global food catalogue** is not a personal health diary and can live in the ForgeLyte backend.

---

# 3. The four food-entry methods

The feature should support four ways to add food.

| Method | Example | Primary source | Global catalogue? |
|---|---|---|---|
| Manual entry | User manually enters macros | User | Private by default; optional contribution |
| Describe food | `175g chicken breast` | Existing DB → USDA; Luna parses intent | Yes when authoritative source exists |
| Barcode scan | Scan packaged product | Existing DB → USDA → OFF | Yes, with source-specific rules |
| Photo | Photo of meal or Nutrition Facts label | Luna vision → DB matching / label extraction | Depends on result/source |

---

# 4. Database separation

For the safest Open Food Facts licensing architecture, do **not** physically merge OFF-derived records into the proprietary/core food table.

Use two searchable global catalogues.

## 4.1 `foods_core`

Foods ForgeLyte can store and manage independently.

Possible sources:

```text
USDA
USER_CONTRIBUTION
LABEL_SCAN_CONTRIBUTION
FORGELYTE_CURATED
AI_ESTIMATE
```

Example schema:

```sql
foods_core
----------
id UUID PRIMARY KEY
name TEXT NOT NULL
brand TEXT NULL
barcode TEXT NULL

serving_description TEXT NULL
serving_weight_g NUMERIC NULL

calories_per_100g NUMERIC NULL
protein_g_per_100g NUMERIC NULL
carbs_g_per_100g NUMERIC NULL
fat_g_per_100g NUMERIC NULL
fiber_g_per_100g NUMERIC NULL
sugar_g_per_100g NUMERIC NULL
sodium_mg_per_100g NUMERIC NULL

source_type TEXT NOT NULL
source_id TEXT NULL

verified BOOLEAN NOT NULL DEFAULT FALSE
estimated BOOLEAN NOT NULL DEFAULT FALSE

country_code TEXT NULL
created_at TIMESTAMPTZ NOT NULL
updated_at TIMESTAMPTZ NOT NULL
```

### Examples

```text
Apple, raw
source_type = USDA
source_id = <FDC ID>
verified = true
estimated = false
```

```text
Kirkland product entered from a confirmed label scan
source_type = LABEL_SCAN_CONTRIBUTION
verified = user_confirmed
estimated = false
```

```text
Homemade chicken shawarma estimate
source_type = AI_ESTIMATE
verified = false
estimated = true
```

---

## 4.2 `off_products`

A separate store/cache containing only Open Food Facts-derived data.

```sql
off_products
------------
id UUID PRIMARY KEY
off_code TEXT NOT NULL
barcode TEXT NOT NULL

product_name TEXT
brand TEXT

serving_description TEXT
serving_weight_g NUMERIC

calories_per_100g NUMERIC
protein_g_per_100g NUMERIC
carbs_g_per_100g NUMERIC
fat_g_per_100g NUMERIC
fiber_g_per_100g NUMERIC
sugar_g_per_100g NUMERIC
sodium_mg_per_100g NUMERIC

off_revision TEXT NULL
last_synced_at TIMESTAMPTZ NOT NULL
```

Rules:

- Every record in this table is understood to be OFF/ODbL-derived.
- Do not re-label it as ForgeLyte-owned proprietary food data.
- Preserve enough provenance to reconnect the record to OFF.
- Refresh stale records periodically or when selected.
- Do not silently enrich an OFF record with proprietary data and then treat the result as closed data.
- If ForgeLyte changes an OFF-derived product and intends the change to become part of that OFF dataset, prefer sending the correction back through the OFF write/contribution process.

The application search layer can combine results from `foods_core` and `off_products` even though the underlying databases/tables remain separate.

---

# 5. Personal diary storage

The user's actual diary is independent of the global food catalogue.

For V1, store this locally.

```sql
food_logs
---------
id UUID PRIMARY KEY

logged_at DATETIME NOT NULL
meal_type TEXT NOT NULL
-- breakfast / lunch / dinner / snack

source_type TEXT NOT NULL
source_food_id TEXT NULL

display_name TEXT NOT NULL
brand TEXT NULL

quantity NUMERIC NOT NULL
unit TEXT NOT NULL
weight_g NUMERIC NULL

calories_snapshot NUMERIC
protein_g_snapshot NUMERIC
carbs_g_snapshot NUMERIC
fat_g_snapshot NUMERIC
fiber_g_snapshot NUMERIC
sugar_g_snapshot NUMERIC
sodium_mg_snapshot NUMERIC

is_estimated BOOLEAN NOT NULL DEFAULT FALSE
created_at DATETIME NOT NULL
```

## Why snapshot nutrition values?

When the user logs:

```text
Kirkland Protein Bar
1 bar
190 kcal
21g protein
```

save those values into the diary record.

Do not calculate old diary entries live from the current global food record forever.

This prevents yesterday's history from changing if:

- USDA updates a product.
- OFF corrects a product.
- ForgeLyte changes serving calculations.
- A manufacturer reformulates a product.

The diary still keeps:

```text
source_type = OPEN_FOOD_FACTS
source_food_id = <OFF cached ID>
```

for provenance.

---

# 6. Unified food search

The user should experience **one search box**.

They should not need to understand USDA versus OFF.

Recommended flow:

```text
User searches: "Kirkland protein bar"
        ↓
1. Search local recent/favorite/custom foods
        ↓
2. Search foods_core
        ↓
3. Search off_products cache
        ↓
good results?
   ├── YES → return
   └── NO
        ↓
4. Search USDA API
        ↓
found?
   ├── YES → normalize → save to foods_core → return
   └── NO
        ↓
5. Search Open Food Facts API
        ↓
found?
   ├── YES → normalize → save to off_products → return
   └── NO
        ↓
6. Offer:
   - Describe with AI
   - Take a food photo
   - Scan Nutrition Facts label
   - Enter manually
```

### OFF search-rate-limit requirement

OFF currently documents approximately:

- 15 read product requests/minute/IP for product queries.
- 10 search requests/minute/IP for search queries.
- Search should **not** be used as search-as-you-type.

Therefore:

- Search your own local/global indexes while the user types.
- Only call OFF after the user pauses/submits the query.
- Debounce and rate-limit server-side.
- Cache useful OFF results in `off_products`.
- Never expose the OFF API directly from the iOS client.

---

# 7. Barcode flow

Barcode scanning itself should use native iOS APIs and has no per-scan API cost.

Recommended flow:

```text
SCAN UPC/EAN/GTIN
        ↓
normalize barcode
        ↓
foods_core by barcode?
        ├── YES → return
        └── NO
              ↓
off_products cache by barcode?
        ├── YES → return
        └── NO
              ↓
USDA FoodData Central
        ├── FOUND → save foods_core(source=USDA)
        └── NOT FOUND
              ↓
Open Food Facts product-by-barcode
        ├── FOUND → save off_products
        └── NOT FOUND
              ↓
"Product not found"
              ↓
Take front/package photo + Nutrition Facts label
```

---

# 8. Food-photo recognition with GPT-5.6 Luna

The user can take a photo of a meal.

Examples:

- chicken breast + rice + broccoli
- hamburger and fries
- bowl of oatmeal with banana
- sushi
- protein bar/package
- restaurant meal

## Goal of AI

Luna should primarily **identify and decompose** the food, not silently invent authoritative nutrition.

Example structured output:

```json
{
  "items": [
    {
      "name": "grilled chicken breast",
      "estimated_weight_g": 160,
      "confidence": 0.88
    },
    {
      "name": "cooked white rice",
      "estimated_weight_g": 180,
      "confidence": 0.76
    },
    {
      "name": "steamed broccoli",
      "estimated_weight_g": 90,
      "confidence": 0.84
    }
  ]
}
```

Then ForgeLyte searches:

```text
foods_core
→ USDA
→ off_products/OFF when appropriate
```

and lets the user confirm portions.

### Important UI

Show:

```text
AI estimate — confirm portions before logging
```

The user must be able to:

- change the detected food;
- change serving/weight;
- remove incorrectly detected items;
- add missed items.

### If no authoritative food match exists

Luna may return an approximate nutrition estimate, but it must be marked:

```text
source_type = AI_ESTIMATE
estimated = true
verified = false
```

AI-estimated nutrition should not automatically become a "verified" global food.

---

# 9. Nutrition Facts label scanner

This is the fallback that prevents dead ends.

## Flow

```text
Barcode not found
        ↓
Take package/front photo
        ↓
Take Nutrition Facts photo
        ↓
ForgeLyte crops/resizes image
        ↓
strip EXIF/location metadata
        ↓
send minimum required image to OpenAI
        ↓
GPT-5.6 Luna extracts structured nutrition
        ↓
user reviews result
        ↓
CONFIRM
```

Requested structured fields:

```json
{
  "product_name": "",
  "brand": "",
  "barcode": "",
  "serving_description": "",
  "serving_weight_g": null,
  "calories": null,
  "protein_g": null,
  "carbs_g": null,
  "fat_g": null,
  "fiber_g": null,
  "sugar_g": null,
  "sodium_mg": null
}
```

### Validation before saving

ForgeLyte should perform deterministic checks:

- serving weight must be positive;
- calories/macros cannot be negative;
- reject impossible unit conversions;
- warn if extracted values look obviously inconsistent;
- require user confirmation;
- keep the original photo only in memory/temporary storage;
- delete the app/backend temporary copy immediately after processing.

---

# 10. Private custom food vs global contribution

A manually added food should be **private by default**.

Example:

```text
Ash's Homemade Chili
```

This should stay on-device unless the user explicitly chooses to contribute it.

For a packaged product with a real barcode:

```text
[ ] Help improve ForgeLyte's shared food database
```

If enabled:

- send only product/nutrition facts needed for the catalogue;
- do not send the user's diary/date/meal;
- do not attach their anonymous diary identity unless required for abuse prevention;
- do not publish a personal name or note;
- product images should not become part of ForgeLyte's catalogue in V1.

A contribution workflow makes the source:

```text
LABEL_SCAN_CONTRIBUTION
```

or:

```text
USER_CONTRIBUTION
```

not `USDA` and not `OPEN_FOOD_FACTS`.

---

# 11. Open Food Facts licensing rules

Open Food Facts database data is licensed under the **Open Database License (ODbL)**.

The ODbL permits use, copying, sharing and adaptation, but includes:

- attribution;
- share-alike obligations for derivative databases publicly used;
- licensing notices.

OFF's own caching guidance states that cached OFF data remains subject to ODbL and specifically advises developers **not to mix OFF data with external product data**.

Therefore ForgeLyte should:

1. Keep OFF-derived catalogue records in `off_products`.
2. Keep USDA/ForgeLyte/user-contribution records in `foods_core`.
3. Combine them at the application/search layer.
4. Preserve OFF provenance.
5. Provide OFF attribution.
6. Avoid copying OFF product images into ForgeLyte V1.

### Product images

OFF documentation states product images are separately available under a Creative Commons Attribution-ShareAlike license and can contain additional copyrighted graphical elements.

**V1 recommendation: do not cache/rehost OFF product images.**

This greatly simplifies licensing.

---

# 12. USDA licensing rules

USDA FoodData Central states:

- the data is in the public domain;
- it is published under CC0 1.0;
- permission is not required;
- USDA requests that FoodData Central be listed as a data source.

This makes USDA the preferred authoritative source for foods that it covers.

ForgeLyte may:

- cache USDA records;
- normalize USDA records;
- make them globally searchable;
- store them permanently;
- combine them with ForgeLyte-owned/user-contributed records.

Always preserve:

```text
source_type = USDA
source_id = FDC ID
```

for provenance.

---

# 13. Attribution UI

Add:

```text
Settings
  → About
    → Food Data Sources
```

Recommended content:

## USDA

> Nutrition data may include data from U.S. Department of Agriculture, Agricultural Research Service, FoodData Central.

Include a link to:

`https://fdc.nal.usda.gov/`

## Open Food Facts

Use a prominent notice similar to:

> Contains information from Open Food Facts, made available under the Open Database License (ODbL).

Links:

- `https://world.openfoodfacts.org/`
- `https://opendatacommons.org/licenses/odbl/1-0/`

### Food-detail screen

Also display lightweight provenance when the user opens a food:

```text
Source: USDA FoodData Central
```

or:

```text
Source: Open Food Facts
```

This is preferable to hiding provenance only in legal settings.

---

# 14. OpenAI privacy rules for food photos

GPT-5.6 Luna supports both text and image inputs.

OpenAI states that API data is **not used to train OpenAI models by default unless the API customer explicitly opts in**.

OpenAI also states that abuse-monitoring logs may contain API customer content and are generally retained for up to 30 days unless a different eligible data-control arrangement applies or longer retention is legally required.

Therefore ForgeLyte must treat an uploaded food photo as data disclosed to a service provider.

## Implementation rules

Before upload:

1. crop to the relevant food/package/label;
2. resize/compress to the minimum useful resolution;
3. strip EXIF metadata, especially GPS/location;
4. do not attach the user's diary history;
5. do not attach an email/name because ForgeLyte does not need one;
6. avoid sending `user_key` to OpenAI unless technically necessary;
7. use a short request-specific internal request ID instead.

After response:

1. parse structured output;
2. delete temporary ForgeLyte copies;
3. do not save the original image in the global catalogue;
4. let the user confirm extracted/estimated data.

---

# 15. Privacy Policy requirements

ForgeLyte's Privacy Policy should explicitly explain:

### Local diary

- Food diary entries are stored locally on the user's device in V1.
- ForgeLyte does not require an email/password account to track food.

### AI processing

When the user chooses AI/photo features:

- the selected food/package/label image or description is sent to OpenAI for processing;
- the purpose is food identification or nutrition-label extraction;
- ForgeLyte does not use the image for advertising;
- ForgeLyte does not intentionally store the submitted image after processing;
- OpenAI's API data handling should be linked/explained accurately.

### Shared catalogue contribution

If the user explicitly contributes a product:

- the product name, barcode, serving and nutrition facts may become part of ForgeLyte's shared catalogue;
- diary details such as meal/date are not part of the contribution;
- submissions should not contain personally identifying information.

### Third-party data sources

Disclose:

- USDA FoodData Central;
- Open Food Facts;
- OpenAI.

---

# 16. Canadian privacy considerations

ForgeLyte should be designed around PIPEDA's privacy principles where applicable, including:

- accountability;
- identifying purposes;
- meaningful consent;
- limiting collection;
- limiting use/disclosure/retention;
- accuracy;
- safeguards;
- openness;
- access/correction;
- a method to challenge privacy practices.

Practical ForgeLyte implementation:

- collect less rather than more;
- do not require a real identity for food tracking;
- do not upload the full food diary to AI;
- strip photo metadata;
- provide a clear privacy policy;
- provide a way to clear/delete nutrition history;
- if backend diary sync is added, provide a "Delete My Nutrition Data" action;
- use TLS in transit;
- use managed encryption at rest for backend data;
- keep API keys server-side;
- maintain retention rules for temporary uploads/logs.

---

# 17. App Store privacy considerations

Before submitting the update, review App Store Connect's Privacy Nutrition Label based on the **actual shipped implementation**.

Potentially relevant categories can include:

- Health & Fitness / Health information;
- User Content / Photos;
- Product Interaction or analytics, if ForgeLyte analytics records use of the feature.

Because a photo is transmitted off-device to OpenAI for processing, do not assume that "we don't save the photo ourselves" automatically removes all App Store privacy disclosure obligations.

Do not use food/fitness data:

- for targeted advertising;
- for selling to data brokers;
- for unrelated marketing/data-mining uses.

---

# 18. Terms of Service — user-contributed foods

The Terms of Service should contain a contribution clause.

A lawyer should finalize the language, but the functionality should be based on these concepts:

- User contributions are voluntary.
- The user confirms they are permitted to submit the information.
- The user grants ForgeLyte permission to store, normalize, reproduce and display the submitted factual product/nutrition information as part of the shared catalogue.
- ForgeLyte may correct, deduplicate or remove inaccurate submissions.
- ForgeLyte does not guarantee user-submitted or AI-estimated nutrition is accurate.
- Users should verify nutrition where accuracy is important.
- Do not accept photos as globally reusable catalogue assets in V1.
- Do not auto-publish custom foods containing personal names/notes.

---

# 19. Source trust levels

Use an explicit trust system.

| Source | Default trust | Estimated? | Global searchable? |
|---|---|---:|---:|
| USDA | High | No | Yes |
| ForgeLyte curated | High | No | Yes |
| Confirmed Nutrition Facts label | Medium/High | No | Yes if contributed |
| User manual food | Medium | No | Private by default |
| Open Food Facts | External/community | No | Yes via OFF catalogue |
| AI food estimate | Low/Estimated | Yes | Prefer private/user-specific |

Suggested fields:

```text
verified
estimated
confidence_score
source_type
source_id
last_verified_at
```

---

# 20. Search/result ranking

Recommended ranking:

```text
1. Exact user custom food / recent food
2. Exact barcode match in foods_core
3. Exact barcode match in off_products
4. Verified USDA / ForgeLyte food
5. Strong OFF match
6. User-contributed confirmed-label food
7. AI estimate
```

Never visually present an AI estimate as if it were manufacturer-verified.

---

# 21. Duplicate prevention

Use normalized keys.

For packaged foods:

```text
normalized_barcode
```

For generic foods:

```text
normalized_name
brand
country
source_id
```

Do not deduplicate an OFF record by physically merging it into a USDA/core row.

Instead, the application may maintain a separate equivalence mapping:

```sql
food_equivalences
-----------------
core_food_id
off_product_id
match_confidence
```

This table means:

> "These records appear to represent the same product."

It does **not** copy OFF nutrition fields into the core record.

---

# 22. Cost breakdown

Prices below are based on publicly listed pricing checked September 8, 2026 and can change.

## USDA FoodData Central

```text
API cost: $0
Default rate limit: 1,000 requests/hour/IP
```

Because USDA data can be cached in `foods_core`, API traffic should decline as the catalogue grows.

---

## Open Food Facts

```text
API cost: $0
```

Current documented limits include approximately:

```text
Product reads: 15 requests/minute/IP
Search:        10 requests/minute/IP
```

This is why ForgeLyte should:

- search its own OFF cache first;
- avoid OFF search-as-you-type;
- query OFF only on an explicit/debounced search;
- cache selected/useful OFF products.

---

## GPT-5.6 Luna

Current API pricing checked September 8, 2026:

```text
Input:        $0.20 / 1M tokens
Cached input: $0.02 / 1M tokens
Output:       $1.20 / 1M tokens
```

### Example text-food parsing call

Assumption:

```text
1,000 input tokens
300 output tokens
```

Approximate cost:

```text
Input  = 1,000 / 1,000,000 × $0.20 = $0.00020
Output =   300 / 1,000,000 × $1.20 = $0.00036

Total ≈ $0.00056
```

About **0.056 cents**.

1,000 similar calls:

```text
≈ $0.56
```

### Example vision budgeting

Exact vision cost depends on how many input tokens the image becomes.

Conservative development budget example:

```text
10,000 total input tokens
500 output tokens

Input  = $0.0020
Output = $0.0006

Total ≈ $0.0026
```

Approximately **0.26 cents per analysis** under that assumption.

For planning, budget:

```text
~$0.001–$0.005 per food/label image analysis
```

until ForgeLyte has real production token measurements.

### Example AI-heavy active user

Hypothetical monthly usage:

```text
100 text AI food descriptions
20 food/label photos
```

Using the estimates above:

```text
100 × $0.00056 = $0.056
20  × $0.003   = $0.060

Estimated AI total ≈ $0.12/user/month
```

Most users should cost less if:

- regular foods are found in the database;
- barcode matches are cached;
- USDA/OFF handle packaged foods;
- AI is only invoked when necessary.

---

## Neon/Postgres

Current public Neon pricing checked September 8, 2026:

### Free

```text
$0
0.5 GB storage/project
100 CU-hours/month/project
scale-to-zero
```

Good for initial development/small production usage.

### Launch

Usage based:

```text
Compute: $0.106 / CU-hour
Storage: $0.35 / GB-month
```

Neon advertises a typical intermittent 1 GB workload around **$15/month**, but actual usage depends on traffic.

### Cost-control strategy

- keep `foods_core` narrow;
- keep OFF cache only for products actually encountered initially;
- do not store product photos;
- index normalized barcode/name fields;
- use server-side connection pooling;
- enable scale-to-zero where appropriate.

---

## Native barcode scanning

```text
Cost: $0
```

Use Apple's native camera/barcode scanning APIs.

No third-party barcode SDK is required for V1.

---

## Image storage

Recommended:

```text
Permanent food photo storage: none
```

Photo lifecycle:

```text
capture
→ crop / strip metadata / compress
→ send to AI
→ extract data
→ discard
```

Therefore normal operation should have effectively **$0 permanent image-storage cost**.

---

# 23. Recommended API endpoints

Example ForgeLyte backend:

```text
GET  /api/foods/search?q=
GET  /api/foods/barcode/:code

POST /api/foods/ai/describe
POST /api/foods/ai/photo
POST /api/foods/ai/label

POST /api/foods/contribute

GET  /api/foods/:source/:id
```

Server responsibilities:

- keep USDA/OpenAI keys private;
- enforce OFF rate limits;
- normalize external data;
- preserve source provenance;
- cache according to source rules;
- strip unwanted fields;
- validate AI responses;
- never allow the client to claim a source is USDA/OFF without server verification.

---

# 24. Recommended search API response

Return a normalized view to the app:

```json
{
  "id": "internal-or-source-reference",
  "name": "Kirkland Signature Protein Bar",
  "brand": "Kirkland Signature",
  "barcode": "0000000000000",
  "serving": {
    "amount": 1,
    "unit": "bar",
    "weight_g": 60
  },
  "nutrition": {
    "calories": 190,
    "protein_g": 21,
    "carbs_g": 22,
    "fat_g": 7
  },
  "source": {
    "type": "OPEN_FOOD_FACTS",
    "external_id": "0000000000000",
    "estimated": false
  }
}
```

The iOS UI can treat every source consistently while backend storage remains legally separated.

---

# 25. Recommended UI

## Add Food

```text
Search foods...
[ Scan Barcode ]
[ Take Food Photo ]
[ Describe with AI ]
[ Add Manually ]
```

### Barcode miss

```text
We couldn't find this product.

[ Scan Nutrition Label ]
[ Enter Manually ]
```

### Photo result

```text
We found:

Grilled chicken breast — ~160g
White rice — ~180g
Broccoli — ~90g

AI estimated portions. Please confirm.

[ Edit ] [ Add to Meal ]
```

### Label scan

```text
Kirkland Signature Protein Bar
Serving: 1 bar (60g)

190 calories
21g protein
22g carbs
7g fat

Please compare this with the package.

[ Correct ] [ Confirm ]
```

---

# 26. Safety/accuracy rules

ForgeLyte should never imply:

- AI recognition is perfectly accurate;
- photo-based portion estimation is exact;
- AI-estimated nutrition is manufacturer-verified;
- nutrition tracking is medical diagnosis/treatment.

Use copy such as:

```text
Estimated from your photo. Confirm foods and portions before logging.
```

and:

```text
Nutrition information can vary by product and preparation.
```

---

# 27. What not to do

Do **not**:

- merge OFF data into the proprietary USDA/ForgeLyte core dataset;
- remove OFF provenance;
- copy/rehost OFF product images in V1;
- use OFF text search on every keystroke;
- send the user's complete food diary to OpenAI;
- retain uploaded food photos unless a future feature clearly requires it;
- retain EXIF/GPS metadata from uploaded food photos;
- treat AI estimates as verified nutrition;
- publish private manual foods globally without an explicit contribution action;
- store the nutrition diary in iCloud/CloudKit;
- require an email/password account merely to use food tracking;
- put OpenAI, USDA, or OFF API secrets in the iOS binary.

---

# 28. V1 implementation order

## Phase 1 — data model

- [ ] Add local `FoodLog` SwiftData model.
- [ ] Add local custom foods/favorites/recent foods.
- [ ] Create backend `foods_core`.
- [ ] Create separate backend `off_products`.
- [ ] Add source/provenance enum.
- [ ] Add nutrition snapshots to diary entries.

## Phase 2 — search

- [ ] Global ForgeLyte search.
- [ ] USDA lookup.
- [ ] Cache USDA records in `foods_core`.
- [ ] OFF fallback.
- [ ] Cache OFF records only in `off_products`.
- [ ] Merge results only at the API response/UI layer.

## Phase 3 — barcode

- [ ] Native barcode scanner.
- [ ] Search ForgeLyte cache first.
- [ ] USDA lookup.
- [ ] OFF product-by-barcode fallback.
- [ ] Nutrition-label fallback.

## Phase 4 — Luna text

- [ ] Parse natural-language food descriptions.
- [ ] Use structured JSON output.
- [ ] Match parsed foods against real database records.
- [ ] Mark unmatched AI nutrition as `AI_ESTIMATE`.

## Phase 5 — Luna vision

- [ ] Food photo identification.
- [ ] Portion confirmation.
- [ ] Nutrition-label extraction.
- [ ] Package/front-label extraction.
- [ ] Crop/resize/strip EXIF before upload.
- [ ] Delete temporary images immediately after processing.

## Phase 6 — legal/privacy UI

- [ ] Settings → About → Food Data Sources.
- [ ] USDA attribution.
- [ ] OFF + ODbL attribution.
- [ ] Source shown on food detail.
- [ ] Privacy Policy update.
- [ ] Terms contribution clause.
- [ ] App Store Privacy Nutrition Label review.
- [ ] Delete/Clear Nutrition History control.
- [ ] Explicit global-contribution opt-in.

---

# 29. Final recommended architecture

```text
                         FORGELYTE LIFT
                              │
            ┌─────────────────┴─────────────────┐
            │                                   │
       PERSONAL DATA                       SHARED DATA
            │                                   │
     Local SwiftData                      ForgeLyte Backend
            │                                   │
       food_logs                    ┌────────────┴────────────┐
       custom foods                 │                         │
       favorites                foods_core               off_products
       recents                       │                         │
                             USDA / ForgeLyte /              OFF only
                             user contributions               ODbL
                                     │                         │
                                     └──────────┬──────────────┘
                                                │
                                         Unified Search
                                                │
                             ┌──────────────────┼──────────────────┐
                             │                  │                  │
                           USDA                OFF              OpenAI
                             │                  │                  │
                        authoritative        fallback       parse / vision
                                                            / estimates
```

## Key principle

**One user experience does not require one legally mixed database.**

ForgeLyte can present:

```text
Apple — USDA
Kirkland Protein Bar — Open Food Facts
Homemade Chili — User Custom
Restaurant Meal — AI Estimate
```

inside the same diary/search UI while preserving the correct source, license, trust level and storage rules underneath.

---

# 30. Official references

### USDA FoodData Central

API/licensing:

https://fdc.nal.usda.gov/api-guide/

USDA states FoodData Central data is public domain and published under CC0 1.0.

---

### Open Food Facts

API documentation:

https://openfoodfacts.github.io/openfoodfacts-server/api/

Local caching guidance:

https://openfoodfacts.github.io/documentation/docs/Product-Opener/api/tutorials/creating-a-local-cache-of-open-food-facts-data/

Licensing guidance:

https://openfoodfacts.github.io/openfoodfacts-server/api/tutorials/license-be-on-the-legal-side/

ODbL summary:

https://opendatacommons.org/licenses/odbl/summary/

Full ODbL 1.0:

https://opendatacommons.org/licenses/odbl/1-0/

---

### OpenAI

GPT-5.6 Luna:

https://developers.openai.com/api/docs/models/gpt-5.6-luna

API data controls:

https://platform.openai.com/docs/models/default-usage-policies-by-endpoint

---

### Apple

App Review Guidelines:

https://developer.apple.com/app-store/review/guidelines/

App Privacy Details:

https://developer.apple.com/app-store/app-privacy-details/

AppTransaction / appTransactionID:

https://developer.apple.com/documentation/storekit/apptransaction/apptransactionid

---

### Canada / PIPEDA

Office of the Privacy Commissioner — PIPEDA fair information principles:

https://www.priv.gc.ca/en/privacy-topics/privacy-laws-in-canada/the-personal-information-protection-and-electronic-documents-act-pipeda/p_principle/

---

# 31. Launch decision summary

For ForgeLyte Lift V1:

```text
ACCOUNTS
No email/password account.

PERSONAL DIARY
Local device only.

GLOBAL DB
Neon/Postgres.

MANUAL FOOD
Private by default; optional explicit global contribution.

TEXT AI
GPT-5.6 Luna parses/decomposes food descriptions.
Use USDA/database nutrition whenever possible.

BARCODE
ForgeLyte cache → USDA → OFF → label scan.

FOOD PHOTO
Luna identifies foods → match against databases → user confirms portions.

LABEL PHOTO
Luna extracts Nutrition Facts → user confirms → private/custom or explicit contribution.

USDA
Store permanently in foods_core.
CC0/public domain; attribute USDA.

OFF
Cache/store in separate off_products dataset.
ODbL; preserve provenance and attribution.

AI ESTIMATES
Allowed, but always marked estimated/unverified.

PRODUCT PHOTOS
Do not retain/rehost in V1.

PRIVACY
Strip EXIF, send minimum image to OpenAI, discard after processing.

LEGAL
Update Privacy Policy, Terms, App Store privacy disclosures and attribution screen before shipping.
```


---

# 32. Anonymous identity, reinstall and new-device restore

ForgeLyte Lift does not require a traditional user account for nutrition sync.

Use Apple's verified StoreKit `AppTransaction.shared` data to obtain the stable `appTransactionID` for the Apple Account + ForgeLyte Lift app.

```text
ForgeLyte Lift launches
        ↓
AppTransaction.shared
        ↓
verify Apple's signed AppTransaction
        ↓
extract appTransactionID
        ↓
ForgeLyte backend
        ↓
HMAC-SHA256(appTransactionID, FORGELYTE_SERVER_SECRET)
        ↓
derived anonymous user_key
```

For the same Apple Account + the same ForgeLyte Lift app:

| Scenario | Expected identity |
|---|---|
| Delete and reinstall ForgeLyte | Same `appTransactionID` → same `user_key` |
| New iPhone using same Apple Account | Same `appTransactionID` → same `user_key` |
| Another supported Apple device, same Apple Account | Same identity |
| Different Apple Account | Different identity |
| Different Family Sharing member | Different identity |

Recommended restore flow:

```text
New iPhone / reinstall
        ↓
verified AppTransaction
        ↓
same appTransactionID
        ↓
same server HMAC secret
        ↓
same user_key
        ↓
backend finds nutrition history
        ↓
restore/sync diary
```

The backend should store the derived `user_key`, not a name, email, username or password.

Recommended nutrition architecture:

```text
SwiftData local diary
        ↕
ForgeLyte backend sync
        ↓
anonymous user_key
```

---

# 33. Nutrition monetization

Nutrition tracking should be an ongoing-service feature because it creates recurring costs from GPT-5.6 Luna, backend compute, database storage/sync, and food-data/API maintenance.

## ForgeLyte Lifetime

One-time purchase for permanent core workout features.

Includes core workout tracking, routines/history, and other primarily on-device lifting features.

Does **not** include calorie/macro tracking, AI food/photo features, nutrition cloud backup/sync, or other ongoing AI/cloud services.

Avoid naming this entitlement `Lifetime Pro`.

Preferred naming:

```text
ForgeLyte Lifetime
```

Suggested App Store IAP wording:

```text
ForgeLyte Lifetime — Workout Features
```

## ForgeLyte Pro

Monthly or annual subscription.

Includes everything in Lifetime plus:

- calorie and macro tracking;
- food database search;
- barcode scanning;
- AI meal descriptions;
- food photo recognition;
- Nutrition Facts label scanning;
- secure nutrition-history backup/sync;
- future ongoing AI/cloud features.

---

# 34. Recommended paywall copy

## ForgeLyte Lifetime

```text
One payment. Keep the core lifting features forever.

✓ Full workout tracking
✓ Unlimited routines and history
✓ Advanced lifting features
✓ No recurring payment

Does not include Nutrition Tracking, AI features,
or cloud-backed services.
```

## ForgeLyte Pro

```text
Everything in ForgeLyte, plus smart nutrition tracking.

✓ Everything in Lifetime
✓ Calorie & macro tracking
✓ Food database search
✓ Barcode food scanning
✓ AI meal descriptions
✓ Food photo recognition
✓ Nutrition Facts label scanning
✓ Secure nutrition-history backup
✓ Ongoing AI and online features
```

Recommended positioning:

```text
Spend less time logging.

Scan barcodes, photograph meals, describe what you ate,
and keep your nutrition history backed up across devices.
```

Use this distinction consistently:

```text
Lifetime includes the core workout features.
Pro includes ongoing AI and cloud-backed services.
```

---

# 35. Free vs Pro nutrition access

| Nutrition feature | Free | ForgeLyte Pro |
|---|---:|---:|
| View calorie/macro targets | Yes | Yes |
| Manual food logging | Limited/basic | Yes |
| Full food database search | No | Yes |
| Barcode scanning | No | Yes |
| AI food description | No | Yes |
| Food photo recognition | No | Yes |
| Nutrition Facts scanner | No | Yes |
| Custom foods | Limited | Yes |
| Nutrition backup/sync | No | Yes |
| Daily/weekly nutrition insights | No/limited | Yes |

Do not include AI nutrition or nutrition-history backend sync in the lifetime entitlement.

---

# 36. Nutrition data privacy messaging

Preferred product-facing copy:

```text
Private nutrition sync

Your food history is securely backed up through ForgeLyte
so it can be restored if you reinstall the app or move to a new iPhone.

No email, password, or traditional account is required.
```

For Settings → Nutrition → Data & Privacy:

```text
Nutrition Data

ForgeLyte keeps a local copy of your nutrition history on
your device and securely backs it up to ForgeLyte's servers
using an anonymous app identifier.

We don't require your name, email address, or password to
sync your nutrition history.

Nutrition history is not stored in iCloud.
```

For first use of AI food/photo scanning:

```text
AI Food Analysis

When you use food-photo or nutrition-label scanning, the
selected image is securely sent to our AI provider to identify
food or read nutrition information.

ForgeLyte does not keep the photo after processing.
```

---

# 37. Updated launch recommendation

```text
FREE
Core workout app + optional limited manual nutrition preview.

FORGELYTE LIFETIME
Permanent core workout features.
No AI nutrition.
No nutrition cloud backup.
No ongoing-service entitlement.

FORGELYTE PRO SUBSCRIPTION
Everything in Lifetime
+ calorie/macro tracking
+ searchable foods
+ barcode scanning
+ GPT-5.6 Luna text/vision
+ nutrition-label scanning
+ nutrition-history backend sync
+ future ongoing AI/cloud features.
```

Identity:

```text
No email/password account.

Apple appTransactionID
→ verified server-side
→ HMAC-derived anonymous user_key
→ backend nutrition sync/restore
```

Data:

```text
Shared foods:
ForgeLyte backend

Personal nutrition diary:
SwiftData local copy
+
ForgeLyte backend synced copy for subscribed users

Not iCloud/CloudKit.
```

---

# 38. Revised ForgeLyte product model — fitness is free

ForgeLyte Lift should now use the fitness/workout tracker as the **free core product**.

The subscription should exist primarily for nutrition tracking and other ongoing-cost services.

## Final tier structure

| Tier | Workout / lifting | Nutrition / calorie tracking | Price |
|---|---|---|---:|
| **ForgeLyte Free** | Full workout tracking | No full nutrition feature set | **$0** |
| **ForgeLyte Pro** | Full workout tracking | Full nutrition + AI + backup/sync | **$5.99/month or $39.99/year** |

### Lifetime

Retire the Lifetime purchase for **new users**.

There are currently no meaningful paid-customer entitlement obligations to preserve beyond the existing complimentary/internal users, so this is the cleanest time to simplify the product model.

Do not advertise a new Lifetime purchase alongside the nutrition subscription.

---

# 39. ForgeLyte Free — included features

The workout side of ForgeLyte Lift should be positioned as genuinely free rather than as a heavily restricted trial.

Recommended included fitness functionality:

- workout logging;
- exercise history;
- sets/reps/weight tracking;
- routines/programs;
- progress tracking;
- other existing core lifting functionality that does not materially create recurring server/API costs.

The exact workout-feature list can continue to evolve without changing the core pricing principle:

```text
Training is free.
Ongoing nutrition/AI services are Pro.
```

This makes the free workout tracker the acquisition funnel for ForgeLyte.

---

# 40. ForgeLyte Pro — nutrition subscription

Recommended pricing:

```text
Monthly: $5.99 USD
Annual:  $39.99 USD
```

Recommended annual trial:

```text
7-day introductory offer for $0.99
```

ForgeLyte Pro should include:

- everything available in the free workout tracker;
- calorie tracking;
- macro tracking;
- food search;
- USDA-backed generic/branded foods;
- Open Food Facts fallback where appropriate;
- barcode scanning;
- GPT-5.6 Luna natural-language food logging;
- food-photo recognition;
- Nutrition Facts label scanning;
- custom foods;
- daily nutrition totals;
- weekly nutrition history/insights;
- secure nutrition-history backend backup/sync;
- future AI/cloud nutrition features.

Do not sell the subscription as paying for "AI usage." Sell the convenience and nutrition functionality.

---

# 41. Updated paywall

The paywall should no longer compare a Lifetime tier against Pro.

Use a simple Free → Pro upgrade model.

## Suggested headline

```text
Train for free. Upgrade when you want nutrition.
```

## Suggested Pro card

```text
ForgeLyte Pro

Smart nutrition tracking built into your workout app.

✓ Calorie & macro tracking
✓ Search foods quickly
✓ Scan food barcodes
✓ Describe meals with AI
✓ Photograph meals to identify foods
✓ Scan Nutrition Facts labels
✓ Secure nutrition-history backup
✓ Restore your food history on a new iPhone

$5.99/month
or
$39.99/year

7-day introductory offer for $0.99 with annual
```

## Alternative value copy

```text
Spend less time logging.

Scan it, photograph it, describe it, or search it —
ForgeLyte handles the rest.
```

---

# 42. Feature gating

Recommended entitlement logic:

| Feature | Free | Pro |
|---|:---:|:---:|
| Workout logging | Yes | Yes |
| Workout history | Yes | Yes |
| Routines/programs | Yes | Yes |
| Exercise/progress tracking | Yes | Yes |
| Calorie/macro targets preview | Optional | Yes |
| Manual nutrition logging | Optional limited preview | Yes |
| Full food database search | No | Yes |
| Barcode scanner | No | Yes |
| AI meal description | No | Yes |
| Food photo recognition | No | Yes |
| Nutrition Facts scanner | No | Yes |
| Custom nutrition foods | Limited/No | Yes |
| Nutrition backend backup/sync | No | Yes |
| Daily/weekly nutrition insights | No/Limited | Yes |

## Recommended preview strategy

ForgeLyte may optionally allow a small manual nutrition preview for free users so they can understand the feature before subscribing.

Examples:

- allow users to set calorie/macro targets;
- show the nutrition dashboard empty state;
- allow a very small number of manual logs;
- allow one demo AI/photo scan.

Do not provide ongoing food-database/API/AI usage to free users unless there is a deliberate acquisition reason and server-side limits are in place.

---

# 43. Subscription economics

The revised subscription pricing remains comfortably above expected recurring infrastructure costs.

Primary recurring costs are:

- GPT-5.6 Luna text/vision calls;
- Neon/Postgres storage and compute;
- backend API compute/networking;
- ongoing maintenance of USDA/Open Food Facts integrations.

At current estimated usage, AI and diary-storage costs should be small relative to a $5.99 monthly or $39.99 annual subscription.

This provides room for:

- Apple's App Store commission;
- higher-than-average AI usage;
- infrastructure growth;
- support/maintenance;
- future nutrition features.

The annual plan is intentionally priced materially below dedicated premium nutrition products such as MacroFactor while reflecting that ForgeLyte has a more focused nutrition feature set.

---

# 44. Updated product positioning

Recommended product-level messaging:

```text
ForgeLyte Lift

Your workout tracker is free.
Add ForgeLyte Pro when you're ready to track nutrition too.
```

Alternative:

```text
Lift free. Track nutrition smarter with Pro.
```

Avoid positioning ForgeLyte as a direct MacroFactor replacement.

Instead position it as:

- an excellent free lifting tracker;
- with an optional, affordable smart nutrition layer;
- inside the same app the user already uses for training.

The differentiation is convenience and price, not claiming the same coaching/database depth as dedicated nutrition platforms.

---

# 45. Final commercial model

```text
FORGELYTE FREE
$0

Full core workout tracker.
No subscription required to track training.

        ↓ optional upgrade

FORGELYTE PRO
$5.99/month
or $39.99/year
7-day annual trial

Everything in Free
+
Calories/macros
Food database
Barcode scanner
GPT-5.6 Luna food logging
Food-photo recognition
Nutrition Facts scanning
Nutrition history
Anonymous backend backup/sync
Future nutrition AI/cloud functionality
```

### Lifetime status

```text
New Lifetime sales: discontinued
```

If old Lifetime entitlements exist in production, preserve whatever functionality was promised by that entitlement, but do not grant the new nutrition/AI/backend services merely because a historical Lifetime entitlement exists unless ForgeLyte explicitly chooses to do so.



---

# 38. Final Pro introductory pricing

ForgeLyte Pro should use the following launch pricing:

```text
Intro offer:
3-day free trial on the yearly plan

Then:
$5.99/month
or
$39.99/year
```

The yearly plan uses a true **3-day free trial** before converting to the annual subscription.

Recommended paywall wording:

```text
Try ForgeLyte Pro for 3 days free.

Then $39.99/year. Monthly is also available at $5.99/month without a trial.
```

The app, App Store metadata, and paywall may accurately describe the annual offer as a **3-day free trial**.

Preferred wording:

```text
3-Day Free Trial
```

or:

```text
Try Pro free for 3 days
7 days, then renews at the selected plan price.
```

The purchase screen must clearly disclose the renewal price and billing cadence before purchase.


---

# 39. Final RevenueCat subscription setup

ForgeLyte Lift uses **RevenueCat** for subscription entitlement management.

The final recommended monetization structure is:

| Product | Price | Intro offer | Role |
|---|---:|---|---|
| ForgeLyte Pro Yearly | **$39.99/year** | **3-day free trial** | Primary/default plan |
| ForgeLyte Pro Monthly | **$5.99/month** | None | Secondary/flexible option |

The paywall should visually emphasize the **yearly** product as the recommended/default choice.

Suggested paywall copy:

```text
ForgeLyte Pro

Try Pro free for 3 days.

✓ Calorie & macro tracking
✓ Barcode food scanning
✓ AI meal descriptions
✓ Food photo recognition
✓ Nutrition Facts label scanning
✓ Secure nutrition-history backup
✓ Ongoing AI and online features

Best Value
$39.99/year
3-day free trial, then renews annually

or

$5.99/month
No trial
```

## RevenueCat product structure

Recommended App Store products:

```text
com.forgelyte.lift.pro.monthly
com.forgelyte.lift.pro.yearly
```

Recommended RevenueCat entitlement:

```text
pro
```

Both products should unlock the same `pro` entitlement.

Recommended RevenueCat Offering:

```text
Offering: default

Package: $rc_annual
→ ForgeLyte Pro Yearly
→ 3-day free trial
→ $39.99/year

Package: $rc_monthly
→ ForgeLyte Pro Monthly
→ $5.99/month
→ no trial
```

The **trial itself is configured in App Store Connect** as the introductory offer on the yearly auto-renewable subscription.

RevenueCat reads the StoreKit product/offer information and reports entitlement status after purchase.

## Paywall behavior

Recommended order:

```text
1. Yearly card first / highlighted
2. "3 days free" shown prominently
3. Annual renewal price shown clearly
4. Monthly option shown underneath
5. Restore Purchases always available
```

Do not obscure:

- the fact that the trial converts to an annual subscription;
- the annual renewal price;
- the subscription auto-renewal nature.

Recommended disclosure:

```text
3 days free, then $39.99/year.
Subscription renews automatically unless cancelled.
```

## RevenueCat entitlement checks

Nutrition features should use:

```text
customerInfo.entitlements["pro"]?.isActive == true
```

to unlock:

- calorie/macro tracking;
- barcode food scanning;
- AI food description;
- food-photo recognition;
- Nutrition Facts label scanning;
- nutrition-history backup/sync;
- other subscription-only cloud/AI features.

Workout tracking remains free and should **not** depend on the `pro` entitlement.

## Existing free-granted users

The current manually granted users can remain active through the RevenueCat `pro` entitlement as desired.

No migration complexity is required because there are no meaningful paid legacy customers to preserve.

---

# 40. Final pricing summary

```text
FREE
Full workout/lifting tracker.

FORGELYTE PRO YEARLY
3-day free trial
then $39.99/year

FORGELYTE PRO MONTHLY
$5.99/month
no trial

PRO UNLOCKS
Nutrition tracking
Barcode scanning
AI text food logging
Food-photo recognition
Nutrition Facts scanning
Nutrition backup/sync
Future ongoing AI/cloud features
```


---

# 41. Vercel backend deployment

ForgeLyte Lift's nutrition backend should be deployed on **Vercel**.

The iOS app should never call OpenAI, USDA FoodData Central, Open Food Facts, or the database directly using privileged credentials.

Recommended architecture:

```text
ForgeLyte Lift iOS app
        ↓ HTTPS
Vercel backend
        ↓
 ┌──────┼───────────────┬──────────────┐
 │      │               │              │
USDA   Open Food Facts  OpenAI Luna    Neon/Postgres
```

Vercel is responsible for:

- API routing;
- request validation;
- RevenueCat entitlement checks where needed;
- Apple `AppTransaction` verification/bootstrap;
- generation of the anonymous `user_key`;
- USDA requests;
- Open Food Facts requests;
- OFF rate limiting/debouncing;
- GPT-5.6 Luna text and vision requests;
- normalization of external food data;
- cache lookup/write logic;
- nutrition-history sync;
- database access;
- abuse prevention;
- server-side logging/monitoring;
- keeping all API/database secrets out of the iOS binary.

## Recommended environment variables

Configure secrets only in Vercel environment variables.

Example:

```text
OPENAI_API_KEY
USDA_FDC_API_KEY
DATABASE_URL

FORGELYTE_SERVER_SECRET

REVENUECAT_SECRET_API_KEY
REVENUECAT_WEBHOOK_SECRET

APPLE_BUNDLE_ID
APPLE_APP_ID
APPLE_ISSUER_ID        # only if required by chosen Apple verification flow
APPLE_KEY_ID           # only if required
APPLE_PRIVATE_KEY      # only if required
```

Do not commit these secrets to Git.

Use separate Vercel environments:

```text
Development
Preview
Production
```

Production credentials should not be exposed to Preview deployments unless explicitly required.

---

# 42. Recommended Vercel API endpoints

Suggested Next.js/Vercel backend routes:

```text
POST /api/bootstrap
GET  /api/foods/search
GET  /api/foods/barcode/:barcode
GET  /api/foods/:source/:id

POST /api/foods/ai/describe
POST /api/foods/ai/photo
POST /api/foods/ai/label

POST /api/foods/contribute

GET  /api/nutrition/logs
POST /api/nutrition/logs
PUT  /api/nutrition/logs/:id
DELETE /api/nutrition/logs/:id

POST /api/nutrition/sync

POST /api/revenuecat/webhook
```

## `/api/bootstrap`

Purpose:

```text
iOS AppTransaction
→ verify Apple-signed transaction
→ extract appTransactionID
→ derive HMAC user_key
→ return short-lived ForgeLyte session/token
```

Do not make every API request resend the raw Apple transaction.

Recommended flow:

```text
launch/loginless bootstrap
        ↓
verified anonymous identity
        ↓
short-lived signed ForgeLyte session token
        ↓
subsequent nutrition API requests
```

---

## `/api/foods/search`

Flow:

```text
query
 ↓
search foods_core
 ↓
search off_products cache
 ↓
if insufficient:
    USDA search
 ↓
if insufficient:
    debounced OFF search
 ↓
normalize
 ↓
cache allowed records
 ↓
return unified result
```

The iOS client should not know or care which provider supplied the record beyond displaying source attribution.

---

## `/api/foods/barcode/:barcode`

Flow:

```text
barcode
 ↓
foods_core
 ↓
off_products
 ↓
USDA branded foods
 ↓
OFF product-by-barcode
 ↓
if missing:
    return LABEL_SCAN_REQUIRED
```

---

## `/api/foods/ai/describe`

Requires active ForgeLyte Pro entitlement.

Flow:

```text
natural language description
 ↓
Luna structured parsing
 ↓
food DB matching
 ↓
return editable detected items
```

Example input:

```text
2 eggs, toast with butter, half an avocado
```

---

## `/api/foods/ai/photo`

Requires active ForgeLyte Pro entitlement.

Flow:

```text
compressed/cropped food photo
 ↓
strip EXIF before upload
 ↓
Luna vision
 ↓
identify foods + estimated portions
 ↓
database matching
 ↓
return editable result
 ↓
discard temporary image
```

---

## `/api/foods/ai/label`

Requires active ForgeLyte Pro entitlement.

Flow:

```text
Nutrition Facts photo
 ↓
strip EXIF
 ↓
Luna extraction
 ↓
validate structured values
 ↓
user confirmation
 ↓
return normalized custom/contribution candidate
 ↓
discard temporary image
```

---

# 43. RevenueCat checks on Vercel

The iOS app may use RevenueCat locally for paywall/UI state, but expensive server-backed nutrition operations should also be protected on the backend.

Do not trust a client field such as:

```json
{
  "isPro": true
}
```

Recommended server flow:

```text
request
 ↓
identify anonymous user_key
 ↓
verify/cache current RevenueCat entitlement
 ↓
pro active?
 ├── YES → allow AI/nutrition backend request
 └── NO  → return 403 / subscription_required
```

Server-gated operations should include at minimum:

- AI food description;
- food-photo recognition;
- Nutrition Facts scanning;
- nutrition-history backend sync.

For performance, entitlement state may be cached briefly server-side and kept current through RevenueCat webhooks.

---

# 44. Vercel + Neon responsibilities

Recommended split:

## Vercel

```text
business logic
authentication/bootstrap
API provider integrations
AI requests
rate limiting
validation
subscription checks
```

## Neon/Postgres

```text
foods_core
off_products
food equivalence mappings
anonymous nutrition backup
sync metadata
minimal anonymous identity records
```

## iOS / SwiftData

```text
fast local diary
offline access
recent foods
favorites
temporary custom foods
UI state
```

This keeps the architecture straightforward:

```text
SwiftData = local UX/offline
Vercel = trusted backend/API layer
Neon = persistent server data
RevenueCat = subscription entitlement
OpenAI/USDA/OFF = external providers
```

---

# 45. Deployment requirements

Before shipping nutrition:

- [ ] Create Vercel project/environment.
- [ ] Configure production domain/API hostname.
- [ ] Add environment variables/secrets.
- [ ] Connect Neon using server-side connection pooling.
- [ ] Implement `/api/bootstrap`.
- [ ] Implement ForgeLyte session/token handling.
- [ ] Add USDA adapter.
- [ ] Add Open Food Facts adapter.
- [ ] Add OFF server-side rate limiting.
- [ ] Add OpenAI Luna adapter.
- [ ] Add image metadata stripping/compression.
- [ ] Add RevenueCat entitlement verification.
- [ ] Add RevenueCat webhook.
- [ ] Add food search/barcode endpoints.
- [ ] Add nutrition sync endpoints.
- [ ] Add request size limits.
- [ ] Add abuse/rate limits per anonymous user.
- [ ] Add structured server logs without storing food photos.
- [ ] Ensure no API secrets are bundled in the iOS application.
- [ ] Test Production and Preview environments separately.


---

# 46. Final image policy — no food/product image storage

ForgeLyte Lift does **not** need product images, meal images, or food thumbnails in the food catalogue.

This is the preferred production policy.

## Global food catalogue

Do not store:

- Open Food Facts product images;
- USDA food images;
- manufacturer package images;
- user-submitted food photos;
- meal photos;
- nutrition-label photos.

Catalogue records should contain structured data only:

```text
name
brand
barcode
serving size
calories
protein
carbs
fat
fiber
sugar
sodium
source/provenance
```

This keeps the database smaller and avoids unnecessary image copyright/licensing complications.

---

## AI food-photo recognition

A user may still take a photo to identify a meal.

The photo lifecycle should be:

```text
User takes/selects photo
        ↓
crop / resize / compress
        ↓
strip EXIF/location metadata
        ↓
send temporarily through Vercel to OpenAI
        ↓
receive structured food result
        ↓
discard image
```

Do not save the image:

- in Neon;
- in Vercel Blob;
- in the global food database;
- in a user photo-history table;
- in analytics/logs.

Only the structured result the user confirms should be retained.

---

## Nutrition Facts label scan

Same rule:

```text
Nutrition label photo
        ↓
temporary processing
        ↓
Luna extracts nutrition facts
        ↓
user confirms
        ↓
store structured nutrition data
        ↓
discard image
```

The saved record may include:

```text
source_type = LABEL_SCAN_CONTRIBUTION
```

but should not include the original label image.

---

## Benefits

This decision provides:

- effectively zero permanent image-storage cost;
- simpler privacy policy;
- lower breach/privacy exposure;
- fewer copyright/image-license issues;
- simpler Open Food Facts compliance;
- smaller database/storage requirements;
- easier data deletion;
- less CDN/Blob infrastructure;
- lower bandwidth costs.

---

# 47. Updated V1 storage rule

Final rule:

```text
FOOD DATA
Structured nutrition/text only

USER DIARY
Structured log records only

AI PHOTOS
Temporary processing only

PRODUCT IMAGES
Not used

PERMANENT IMAGE STORAGE
None
```

Vercel does not need a Blob/image-storage product for the food-tracking feature in V1.
