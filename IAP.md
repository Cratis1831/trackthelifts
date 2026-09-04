# Track The Lifts - In-App Purchases Documentation

## Overview

Track The Lifts uses RevenueCat to manage in-app purchases and subscriptions. The app follows a freemium model where basic features are free, and premium features require a subscription.

## Subscription Tiers

### Free Tier
- ✅ Basic workout tracking
- ✅ Exercise library
- ✅ Local data storage
- ✅ Workout history

### Pro Tier
- ✅ Everything in Free Tier
- ✅ **iCloud Sync & Backup**
- ✅ **Unlimited routines**
- ✅ **Advanced progress analytics**
- ✅ **RPE and RIR effort tracking**
- ✅ **Supersets**
- ✅ **Every accent theme**
- ✅ All future Pro features

## Pro Features

The Pro tier is defined by the `ProFeature` enum in `Services/SubscriptionTier.swift`:
- `icloudSync` — iCloud Sync & Backup (opt-in toggle in Settings; see `Services/CloudSyncPreference.swift`). **Not included in the Monthly free trial** — trial users keep data on-device so cancelling cannot lock them out of a CloudKit store.
- `unlimitedRoutines` — Unlimited Routines
- `advancedProgress` — Advanced Progress Analytics
- `effortTracking` — RPE and RIR Tracking
- `supersets` — Supersets
- `accentThemes` — Every Accent Theme

Access is gated via `RevenueCatService.canAccess(_:)`, which checks the `Pro`
entitlement. New Pro features are added by extending `ProFeature`.

## RevenueCat Products

### Product IDs
- **Monthly Subscription**: `com.ashkansdev.track_the_lifts.Monthly` (auto-renewable, 1-week free trial then $1.99)
- **Yearly Subscription**: `com.ashkansdev.track_the_lifts.Annual` (auto-renewable)
- **Lifetime**: `com.ashkansdev.track_the_lifts.Lifetime` (non-consumable, one-time)
- Weekly (`com.ashkansdev.track_the_lifts.Weekly`) is removed from sale and archived in RevenueCat; do not attach it to the offering.

The paywall reads packages dynamically from the current RevenueCat offering, so
these IDs must match the products configured in App Store Connect and attached to
the offering. See `TrackTheLifts.storekit` for the local StoreKit testing config.

### Entitlements
- **Pro**: `Pro` - Grants access to all premium features (checked in `RevenueCatService.swift`)

### Pricing (Subject to App Store Connect configuration)
- See `TrackTheLifts.storekit` for local testing prices; live prices are set in App Store Connect.

## Implementation Architecture

### Services
- **RevenueCatService**: Main service class that handles all subscription logic
- **SubscriptionTier**: Enum defining free and premium tiers with their features
- **PremiumFeature**: Constants for premium feature identifiers

### Key Files
- `Services/RevenueCatService.swift` - Main subscription service
- `Services/SubscriptionTier.swift` - Tier and `ProFeature` definitions, access policy
- `Services/SubscriptionOfferPresentation.swift` - Trial/paywall copy and plan merchandising
- `Views/Subscription/PaywallView.swift` - Subscription purchase interface
- `Views/Subscription/ProBenefitsView.swift` - Benefits + management for subscribers
- `Views/SettingsView.swift` - Subscription status, upgrade entry, restore
- `Views/OnboardingView.swift` - First-launch walkthrough, including the optional Monthly trial page

### Integration Points
1. **App Launch**: RevenueCat is configured in `TrackTheLiftsApp.swift`
2. **Onboarding**: After the profile name page, eligible new users can start the Monthly 1-week trial or skip
3. **Settings**: Users can view current tier and upgrade via `SettingsView`
4. **Paywall**: Purchase interface shown when upgrading; Monthly shows the trial when the Apple ID is eligible
5. **Feature Gates**: iCloud sync features check subscription status

## Setup Instructions

### 1. RevenueCat Configuration
1. Create a RevenueCat account at https://revenuecat.com
2. Set up your app in RevenueCat dashboard
3. Configure products and entitlements
4. Replace `YOUR_REVENUECAT_API_KEY` in `TrackTheLiftsApp.swift` with your actual API key

### 2. App Store Connect Setup
1. Create in-app purchase products in App Store Connect:
   - `$rc_monthly` (Auto-Renewable Subscription)
   - `$rc_annual` (Auto-Renewable Subscription)
2. Set up subscription group
3. Configure pricing and availability

### 3. RevenueCat Dashboard Configuration
1. Add products from App Store Connect to RevenueCat
2. Create "Premium" entitlement
3. Attach both subscription products to the Premium entitlement
4. Test with sandbox users

### 4. Xcode Setup
1. Add RevenueCat SDK via Swift Package Manager:
   - URL: `https://github.com/RevenueCat/purchases-ios`
2. Enable "In-App Purchase" capability in project settings
3. Update API key in `TrackTheLiftsApp.swift`

## Testing

### Sandbox Testing
1. Create sandbox test user in App Store Connect
2. Sign out of real App Store account on test device
3. Use sandbox account for testing purchases
4. Test both monthly and yearly subscriptions
5. Test restore purchases functionality

### RevenueCat Testing
- Use RevenueCat's debugger to verify events
- Check customer info updates
- Verify entitlement status changes

## Future Enhancements

### Potential Premium Features
- Advanced workout analytics
- Custom exercise creation
- Workout templates sharing
- Export functionality
- Advanced reporting
- Multiple workout plans

### Implementation Notes
- The current architecture is designed to be easily extensible
- New premium features can be added by updating `SubscriptionTier.swift`
- Feature gates can be added using `RevenueCatService.canAccessFeature()`
- The service is Observable, so UI updates automatically when subscription status changes

## Error Handling

The app handles various subscription-related errors:
- Network failures
- Purchase cancellations
- Restore failures
- Invalid products
- Configuration errors

All errors are logged and displayed to users with appropriate messaging.

## Privacy & Security

- User subscription status is managed by RevenueCat
- No sensitive payment information is stored locally
- iCloud sync data is encrypted and stored in the user's iCloud account
- All RevenueCat communication uses HTTPS
- Subscription status is validated server-side by RevenueCat

## Support & Troubleshooting

### Common Issues
1. **"Not configured" errors**: Check API key and network connection
2. **Purchase failures**: Verify App Store Connect configuration
3. **Restore not working**: Ensure user is signed into correct Apple ID
4. **Features not unlocking**: Check entitlement configuration in RevenueCat

### Debug Steps
1. Check RevenueCat debug logs
2. Verify customer info in RevenueCat dashboard
3. Test with multiple sandbox accounts
4. Verify product IDs match exactly

## Contact & Resources

- RevenueCat Documentation: https://docs.revenuecat.com
- Apple In-App Purchase Guide: https://developer.apple.com/in-app-purchase/
- RevenueCat Support: support@revenuecat.com