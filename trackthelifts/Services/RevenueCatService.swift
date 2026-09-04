import Foundation
import Combine
import RevenueCat

struct PurchaseResultData {
    let transaction: StoreTransaction?
    let customerInfo: CustomerInfo
    let userCancelled: Bool
}

@MainActor
class RevenueCatService: ObservableObject {
    static let shared = RevenueCatService()
    static let proOfferingIdentifier = "pro_v2"
    
    @Published private(set) var entitlementTier: SubscriptionTier = .free
    @Published var isConfigured = false
    @Published var isLoading = false
    @Published var lastError: RevenueCatError?
    @Published var availablePackages: [Package] = []
    @Published private(set) var introEligibleProductIDs: Set<String> = []
    @Published private(set) var isInFreeTrial = false
    private var introEligibilityLoaded = false
    #if DEBUG
    private static let debugTierOverrideKey = "debugSubscriptionTierOverride"

    @Published var debugTierOverride: SubscriptionTier? {
        didSet {
            persistDebugTierOverride()
            synchronizeThemeAccess()
            CloudSyncPreference.shared.cachedHasPro = canAccess(.icloudSync)
        }
    }
    #endif

    var currentTier: SubscriptionTier {
        #if DEBUG
        SubscriptionAccessPolicy.effectiveTier(
            entitlementTier: entitlementTier,
            debugOverride: debugTierOverride
        )
        #else
        entitlementTier
        #endif
    }

    /// Debug Pro overrides are treated as a paid subscription so iCloud can be tested.
    private var effectiveIsInFreeTrial: Bool {
        #if DEBUG
        if debugTierOverride != nil { return false }
        #endif
        return isInFreeTrial
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        #if DEBUG
        if let raw = UserDefaults.standard.string(forKey: Self.debugTierOverrideKey) {
            debugTierOverride = SubscriptionTier(rawValue: raw)
        }
        CloudSyncPreference.shared.cachedHasPro = canAccess(.icloudSync)
        #endif
        synchronizeThemeAccess()
    }
    
    func configure(apiKey: String) async {
        isLoading = true
        defer { isLoading = false }
        
        // Configure RevenueCat
        Purchases.configure(withAPIKey: apiKey)
        
        // Verbose SDK logs are visible in Console.app/sysdiagnose, so keep them out of release builds.
        #if DEBUG
        Purchases.logLevel = .debug
        #else
        Purchases.logLevel = .error
        #endif
        
        do {
            // Get initial customer info using the completion handler
            let customerInfo: CustomerInfo = try await withCheckedThrowingContinuation { continuation in
                Purchases.shared.getCustomerInfo { customerInfo, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let customerInfo = customerInfo {
                        continuation.resume(returning: customerInfo)
                    } else {
                        continuation.resume(throwing: RevenueCatError.notConfigured)
                    }
                }
            }
            
            updateSubscriptionStatus(from: customerInfo)
            
            // Load offerings
            await loadOfferings()
            
            isConfigured = true
            print("RevenueCat configured successfully")
        } catch {
            lastError = .notConfigured
            print("Failed to configure RevenueCat: \(error)")
        }
    }
    
    func checkSubscriptionStatus() async {
        guard isConfigured else {
            lastError = .notConfigured
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let customerInfo: CustomerInfo = try await withCheckedThrowingContinuation { continuation in
                Purchases.shared.getCustomerInfo { customerInfo, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let customerInfo = customerInfo {
                        continuation.resume(returning: customerInfo)
                    } else {
                        continuation.resume(throwing: RevenueCatError.notConfigured)
                    }
                }
            }
            
            updateSubscriptionStatus(from: customerInfo)
            print("Checked subscription status successfully")
        } catch {
            lastError = .restoreFailed(error)
            print("Failed to check subscription status: \(error)")
        }
    }
    
    func purchasePackage(_ package: Package) async -> Bool {
        let packageType = analyticsPackageType(for: package)
        guard isConfigured else {
            lastError = .notConfigured
            AnalyticsService.track(.purchaseFailed(packageType: packageType, reason: .notConfigured))
            return false
        }

        lastError = nil
        isLoading = true
        defer { isLoading = false }
        
        do {
            let result: PurchaseResultData = try await withCheckedThrowingContinuation { continuation in
                Purchases.shared.purchase(package: package) { transaction, customerInfo, error, userCancelled in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let customerInfo = customerInfo {
                        let resultData = PurchaseResultData(
                            transaction: transaction,
                            customerInfo: customerInfo,
                            userCancelled: userCancelled
                        )
                        continuation.resume(returning: resultData)
                    } else {
                        continuation.resume(throwing: RevenueCatError.notConfigured)
                    }
                }
            }
            
            updateSubscriptionStatus(from: result.customerInfo)
            
            if !result.userCancelled {
                print("Purchase successful: \(package.storeProduct.productIdentifier)")
                AnalyticsService.track(.purchaseCompleted(packageType: packageType))
                return true
            } else {
                lastError = .userCancelled
                AnalyticsService.track(.purchaseCancelled(packageType: packageType))
                return false
            }
            
        } catch {
            lastError = .purchaseFailed(error)
            AnalyticsService.track(.purchaseFailed(packageType: packageType, reason: .sdkError))
            print("Failed to purchase: \(error)")
            return false
        }
    }
    
    func restorePurchases() async -> Bool {
        guard isConfigured else {
            lastError = .notConfigured
            AnalyticsService.track(.purchaseRestoreFailed(reason: .notConfigured))
            return false
        }

        lastError = nil
        isLoading = true
        defer { isLoading = false }
        
        do {
            let customerInfo: CustomerInfo = try await withCheckedThrowingContinuation { continuation in
                Purchases.shared.restorePurchases { customerInfo, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let customerInfo = customerInfo {
                        continuation.resume(returning: customerInfo)
                    } else {
                        continuation.resume(throwing: RevenueCatError.notConfigured)
                    }
                }
            }
            
            updateSubscriptionStatus(from: customerInfo)
            AnalyticsService.track(.purchaseRestoreCompleted(hasActiveEntitlement: currentTier == .pro))
            print("Purchases restored successfully")
            return true
            
        } catch {
            lastError = .restoreFailed(error)
            AnalyticsService.track(.purchaseRestoreFailed(reason: .sdkError))
            print("Failed to restore purchases: \(error)")
            return false
        }
    }
    
    // MARK: - Offerings

    private func analyticsPackageType(for package: Package) -> AnalyticsPackageType {
        AnalyticsPackageType.fromRevenueCatDescription(String(describing: package.packageType))
    }
    
    func loadOfferings() async {
        lastError = nil
        do {
            let offerings: Offerings = try await withCheckedThrowingContinuation { continuation in
                Purchases.shared.getOfferings { offerings, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let offerings = offerings {
                        continuation.resume(returning: offerings)
                    } else {
                        continuation.resume(throwing: RevenueCatError.invalidProduct)
                    }
                }
            }
            
            if let offering = offerings.all[Self.proOfferingIdentifier] ?? offerings.current {
                availablePackages = Self.sortedPackages(offering.availablePackages)
                print("✅ Loaded \(availablePackages.count) packages from offering: \(offering.identifier)")
                print("Packages: \(availablePackages.map { $0.storeProduct.productIdentifier })")
                await refreshIntroEligibility()
            } else {
                availablePackages = []
                introEligibleProductIDs = []
                introEligibilityLoaded = false
                print("❌ No Pro or current offering found")
                lastError = .noOfferingsAvailable
            }
        } catch {
            print("❌ Failed to load offerings: \(error)")
            lastError = .offeringsLoadFailed(error)
        }
    }

    var monthlyPackage: Package? {
        availablePackages.first { $0.planKind == .monthly }
    }

    var annualPackage: Package? {
        availablePackages.first { $0.planKind == .annual }
    }

    var hasEligibleMonthlyTrial: Bool {
        guard let monthlyPackage else { return false }
        return isEligibleForFreeTrial(monthlyPackage)
    }

    func isEligibleForFreeTrial(_ package: Package) -> Bool {
        guard package.introOfferSummary?.isFreeTrial == true else { return false }
        if introEligibilityLoaded {
            return introEligibleProductIDs.contains(package.storeProduct.productIdentifier)
        }
        return true
    }

    func preferredPaywallPackage() -> Package? {
        if let monthlyPackage, isEligibleForFreeTrial(monthlyPackage) {
            return monthlyPackage
        }
        return annualPackage ?? availablePackages.first
    }

    private func refreshIntroEligibility() async {
        let packages = availablePackages
        guard !packages.isEmpty else {
            introEligibleProductIDs = []
            introEligibilityLoaded = false
            return
        }

        let result = await Purchases.shared.checkTrialOrIntroDiscountEligibility(packages: packages)
        introEligibleProductIDs = Set(result.compactMap { package, eligibility in
            eligibility.status == .eligible ? package.storeProduct.productIdentifier : nil
        })
        introEligibilityLoaded = true
    }

    /// Stable merchandising order for the 2×2 paywall:
    /// Annual, Lifetime, Monthly, Weekly.
    private static func sortedPackages(_ packages: [Package]) -> [Package] {
        packages.sorted { packageRank($0) < packageRank($1) }
    }

    private static func packageRank(_ package: Package) -> Int {
        switch package.packageType {
        case .annual:
            return 0
        case .lifetime:
            return 1
        case .monthly:
            return 2
        case .weekly:
            return 3
        default:
            let identifier = package.storeProduct.productIdentifier.lowercased()
            if identifier.contains("annual") || identifier.contains("year") { return 0 }
            if identifier.contains("lifetime") || identifier.contains("life") { return 1 }
            if identifier.contains("month") { return 2 }
            if identifier.contains("week") { return 3 }
            return 4
        }
    }
    
    // MARK: - Feature Access Methods
    
    func canAccess(_ feature: ProFeature) -> Bool {
        SubscriptionAccessPolicy.canAccess(
            feature,
            tier: currentTier,
            isInFreeTrial: effectiveIsInFreeTrial
        )
    }
    
    func requiresPro(_ feature: ProFeature) -> Bool {
        !canAccess(feature)
    }
    
    // MARK: - Private Methods
    
    private func updateSubscriptionStatus(from customerInfo: CustomerInfo) {
        let entitlement = customerInfo.entitlements["Pro"]
        if entitlement?.isActive == true {
            entitlementTier = .pro
            isInFreeTrial = entitlement?.periodType == .trial
        } else {
            entitlementTier = .free
            isInFreeTrial = false
        }

        synchronizeThemeAccess()

        // Snapshot paid-Pro access (not trial) so the next launch does not open CloudKit
        // for a trial that might be cancelled. See `ProFeature.isIncludedInFreeTrial`.
        CloudSyncPreference.shared.cachedHasPro = canAccess(.icloudSync)

        // The user's tier and entitlements are account state; only log them in debug builds.
        #if DEBUG
        print("Updated subscription status - Current tier: \(currentTier.displayName)")
        print("Active entitlements: \(customerInfo.entitlements.active.keys)")
        #endif
    }

    private func synchronizeThemeAccess() {
        ThemePreference.shared.updateProAccess(currentTier == .pro)
    }

    #if DEBUG
    private func persistDebugTierOverride() {
        if let debugTierOverride {
            UserDefaults.standard.set(debugTierOverride.rawValue, forKey: Self.debugTierOverrideKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.debugTierOverrideKey)
        }
    }
    #endif
}
