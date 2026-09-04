# ForgeLyte Lift — App Store updates

Live data from App Store Connect (`asc` 4.11.0) and Astro, 3 Sep 2026.

- **App:** ForgeLyte Lift Workout Tracker
- **App ID:** `6751346666`
- **Bundle ID:** `com.ashkansdev.track-the-lifts`
- **Version:** iOS 1.0.7 `READY_FOR_SALE`
- **Primary locale:** `en-CA`
- **Subscription group:** Pro (`21760682`)

Catalog work is done (3 Sep 2026): Weekly is off sale, Monthly has a 1-week free trial, RevenueCat no longer serves Weekly. Update the paywall UI in the next binary so the sheets match, then submit.

---

## 1. Listing snapshot

| Field | Current | Recommended |
| --- | --- | --- |
| App name | ForgeLyte Lift Workout Tracker | Keep. Already ranks for `workout tracker`. |
| Subtitle | Gym Log, Fitness & Strength | Keep. Indexes gym, log, fitness, strength — do not repeat those in keywords. |
| Category | Health & Fitness | Keep. |
| US availability | Live since 16 Jul 2026 | No change. |

---

## 2. Keyword field (paste this)

**Where:** App Store Connect → version localization → Keywords (`en-CA`)

**Current (98/100):**

```
weightlifting,sets,reps,progress,timer,rest,powerlifting,bodybuilding,routine,planner,training,1rm
```

**Recommended (99/100):**

```
sets,reps,1rm,rpe,rir,kg,lb,volume,weight,powerlifting,ppl,hypertrophy,plate,iron,barbell,bench,5x5
```

No spaces after commas. Do not add `lift`, `workout`, `tracker`, `gym`, `log`, `fitness`, or `strength` — they are already in the name and subtitle.

### Keep / add / drop

| Keyword | Action | US pop / diff | Why |
| --- | --- | --- | --- |
| sets | Keep | 15 / 11 | Easy, core logging term |
| reps | Keep | 40 / 38 | Highest-volume keep |
| 1rm | Keep | 14 / 17 | In the app; ranks #188 CA |
| powerlifting | Keep | 15 / 40 | Honest niche |
| ppl | Add | **34 / 15** | Best new term |
| hypertrophy | Add | 23 / 37 | Competitor gym-log SERPs |
| plate | Add | 25 / 17 | Easy, gym-specific |
| iron | Add | 21 / 17 | Combos with Lift in the title |
| rpe, rir | Add | 5 / 9 (rpe) | In the product |
| kg, lb | Add | 20 / 36, 19 / 15 | Both units are supported |
| weight, volume, barbell, bench, 5x5 | Add | mixed | True features / programs |
| progress, timer, rest, routine, planner, training, bodybuilding | Drop | 40–67 pop, hard | Unwinnable or already in subtitle |
| hevy, fitbod, strong | Do not add | brand volume | Competitor names |

### Rankings to re-check after keywords go live

| Keyword | US rank | CA rank | Notes |
| --- | --- | --- | --- |
| workout tracker | 70 | 22 | Driven by title + ratings |
| forgelyte | 1 | 1 | Brand |
| lift tracker | unranked | 57 | Should improve with lifting terms |
| 1rm | unranked | 188 | Keep tracking |
| ppl / hypertrophy / 5x5 | not tracked before | — | Check Astro in 7–14 days |

---

## 3. Live prices vs competitors (US)

| Plan | ForgeLyte (ASC) | Hevy | Strong | Fitbod |
| --- | --- | ---: | ---: | ---: |
| Weekly | **$1.99/wk ≈ $103/yr** | — | — | — |
| Monthly | $1.99 | $2.99 | $4.99 | $15.99 |
| Annual | $14.99 | $23.99 | $29.99 | $95.99 |
| Lifetime | $24.99 | $74.99 | ~$99.99 | rare |
| Trial | **1-week free on Monthly** | usable free tier | usable free tier | 7-day trial |

Canada equalization (keep): Monthly CA$2.99 · Annual CA$19.99 · Lifetime CA$34.99. Weekly was CA$2.99; it is no longer for sale.

**Verdict:** Monthly and annual are cheap vs the category. Weekly at the same $1.99 as monthly is a trap. Lifetime is low on purpose while ratings are tiny — raise toward $39.99–$49.99 later.

---

## 4. Catalog changes (applied 3 Sep 2026)

| Item | Status |
| --- | --- |
| Weekly `com.ashkansdev.track_the_lifts.Weekly` (`6796393265`) | **Done.** ASC state `DEVELOPER_REMOVED_FROM_SALE` (0 territories). Existing Weekly subscribers keep access until the period ends. |
| Monthly `com.ashkansdev.track_the_lifts.Monthly` (`6751348647`) | **Done.** Still $1.99. 1-week `FREE_TRIAL` created in **133/133** territories, start date 2026-09-03. |
| Annual `6751348321` | Unchanged at $14.99. No trial. Highlight as best value in the next paywall. |
| Lifetime IAP `6790801551` | Unchanged at $24.99. |
| RevenueCat Weekly `prod47fa096d5c` | **Done.** Already off the `Pro` entitlement and both offerings. Product archived (`inactive`). `pro_v2` display name is now `Pro` (packages: Annual, Lifetime, Monthly). |

`TrackTheLifts.storekit` no longer includes Weekly. Local Monthly is $1.99 with a 1-week free intro so StoreKit testing matches live.

The 1-week trial is **not** in the 27 EU countries. Those storefronts are `CANNOT_SELL` for the app, Monthly is not on sale there, and 0 of the 133 intro offers are EU. After the free week, Apple auto-renews into paid Monthly at $1.99 unless the user cancels during the trial.

---

## 5. Features vs Strong / Hevy / Fitbod

| Feature | Recommendation |
| --- | --- |
| Core logging | Keep **free forever** (how Strong/Hevy acquire users) |
| Routines | Free: 3. Pro: unlimited |
| History / charts | Free: ~8–12 weeks. Pro: unlimited + charts |
| iCloud sync | Keep Pro-only. Do not lock local data behind the trial |
| CSV export, extra themes | Keep Pro |
| Apple Watch | Biggest gap. Build before raising prices to Strong levels |
| Social / AI programming | Do not add. The listing already sells “no social, no AI clutter” |
| Weekly in the paywall | Hide. Monthly + Annual + Lifetime is enough |

---

## 6. What you still do in the next build

1. Paste the keyword field if it is not already applied.
2. Update paywall UI: drop Weekly; show **1 week free, then $1.99/mo**; keep Annual $14.99 and Lifetime $24.99.
3. Submit that binary. The trial is already live on the Monthly product — the new UI just has to present it.
4. Re-check Astro ranks 7–14 days after keywords go live.

---

## 7. IDs cheat sheet

| Product | ASC ID | Product ID |
| --- | --- | --- |
| Monthly | `6751348647` | `com.ashkansdev.track_the_lifts.Monthly` |
| Annual | `6751348321` | `com.ashkansdev.track_the_lifts.Annual` |
| Weekly (off sale) | `6796393265` | `com.ashkansdev.track_the_lifts.Weekly` |
| Lifetime | `6790801551` | `com.ashkansdev.track_the_lifts.Lifetime` |
| Entitlement | — | `Pro` |
| RC project | `proj16b5a7d0` | ForgeLyte Lift |
| RC offering (app uses this) | `ofrng2cec204d5a` | `pro_v2` |
