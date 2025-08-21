# Track The Lifts - In-App Purchases Documentation

## Overview

Track The Lifts uses RevenueCat to manage in-app purchases and subscriptions. The app follows a freemium model where basic features are free, and premium features require a subscription.

## Subscription Tiers

### Free Tier
- ✅ Basic workout tracking
- ✅ Exercise library
- ✅ Local data storage
- ✅ Workout history
- ❌ iCloud sync

### Premium Tier
- ✅ Everything in Free Tier
- ✅ **iCloud sync across devices**
- ✅ Automatic backup
- ✅ Data restoration

## Premium Feature: iCloud Sync

Currently, the only premium feature is iCloud sync, which allows users to:
- Sync workouts across iPhone, iPad, and Mac
- Automatically backup workout data to iCloud
- Restore data when switching devices
- Access workouts from any Apple device

## RevenueCat Products

### Product IDs
- **Monthly Subscription**: `com.ashkansdev.trackthelifts.Monthly`
- **Yearly Subscription**: `com.ashkansdev.trackthelifts.Annual`

### Entitlements
- **Pro**: `Pro` - Grants access to all premium features

### Pricing (Subject to App Store Connect configuration)
- **Monthly**: $4.99/month
- **Yearly**: $39.99/year (33% savings)

## Implementation Architecture

### Services
- **RevenueCatService**: Main service class that handles all subscription logic
- **SubscriptionTier**: Enum defining free and premium tiers with their features
- **PremiumFeature**: Constants for premium feature identifiers

### Key Files
- `Services/RevenueCatService.swift` - Main subscription service
- `Services/SubscriptionTier.swift` - Tier definitions and feature management
- `Views/PaywallView.swift` - Subscription purchase interface
- `Views/SettingsView.swift` - Subscription management interface

### Integration Points
1. **App Launch**: RevenueCat is configured in `TrackTheLiftsApp.swift`
2. **Settings**: Users can view current tier and upgrade via `SettingsView`
3. **Paywall**: Purchase interface shown when upgrading
4. **Feature Gates**: iCloud sync features check subscription status

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