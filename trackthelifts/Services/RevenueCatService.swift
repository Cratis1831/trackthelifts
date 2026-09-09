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
    @Published private(set) var introEligibilityLoaded = false
    @Published private(set) var isInFreeTrial = false
    /// Survives RevenueCat anonymous ID reset on reinstall; StoreKit eligibility is Apple ID based.
    @Published private(set) var hasPriorPaidOrTrialHistory = false
    #if DEBUG
    private static let debugTierOverrideKey = "debugSubscriptionTierOverride"

    @Published var debugTierOverride: SubscriptionTier? {
        didSet {
            persistDebugTierOverride()
            synchronizeThemeAccess()
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
        #endif
        synchronizeThemeAccess()
    }
    
    func configure(apiKey: String) async {
        isLoading = true
        defer { isLoading = false }
        
        // Configure RevenueCat
        Purchases.configure(withAPIKey: apiKey)
        AnalyticsService.configureActivationPal(userId: Purchases.shared.appUserID)
        
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
            
            AnalyticsService.configureActivationPal(userId: Purchases.shared.appUserID)
            
            isConfigured = true
            print("RevenueCat configured successfully")
            await ForgeLyteSession.shared.bootstrap()
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
            await refreshIntroEligibility()
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
            await refreshIntroEligibility()
            
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
            await refreshIntroEligibility()
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
                availablePackages = Self.sortedPackages(
                    offering.availablePackages.filter { package in
                        package.planKind != .lifetime && package.planKind != .weekly
                    }
                )
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

    var hasEligibleAnnualTrial: Bool {
        guard let annualPackage else { return false }
        return isEligibleForFreeTrial(annualPackage)
    }

    var hasEligibleMonthlyTrial: Bool {
        guard let monthlyPackage else { return false }
        return isEligibleForFreeTrial(monthlyPackage)
    }

    func isEligibleForFreeTrial(_ package: Package) -> Bool {
        guard package.introOfferSummary?.isFreeTrial == true else { return false }
        guard introEligibilityLoaded else { return false }
        guard !hasPriorPaidOrTrialHistory else { return false }
        return introEligibleProductIDs.contains(package.storeProduct.productIdentifier)
    }

    func preferredPaywallPackage() -> Package? {
        if let annualPackage { return annualPackage }
        if let monthlyPackage, isEligibleForFreeTrial(monthlyPackage) {
            return monthlyPackage
        }
        return monthlyPackage ?? availablePackages.first
    }

    private func refreshIntroEligibility() async {
        let packages = availablePackages
        guard !packages.isEmpty else {
            introEligibleProductIDs = []
            introEligibilityLoaded = false
            return
        }

        let result = await Purchases.shared.checkTrialOrIntroDiscountEligibility(packages: packages)
        // Only `.eligible` may show trial copy. Ineligible/unknown after a prior trial
        // (including delete-and-reinstall on the same Apple ID) must not advertise a new trial.
        introEligibleProductIDs = Set(result.compactMap { package, eligibility in
            eligibility.status == .eligible ? package.storeProduct.productIdentifier : nil
        })
        introEligibilityLoaded = true
    }

    /// Stable merchandising order: Yearly first (recommended), then Monthly.
    private static func sortedPackages(_ packages: [Package]) -> [Package] {
        packages.sorted { packageRank($0) < packageRank($1) }
    }

    private static func packageRank(_ package: Package) -> Int {
        switch package.packageType {
        case .annual:
            return 0
        case .monthly:
            return 1
        default:
            let identifier = package.storeProduct.productIdentifier.lowercased()
            if identifier.contains("annual") || identifier.contains("year") { return 0 }
            if identifier.contains("month") { return 1 }
            return 4
        }
    }
    
    // MARK: - Feature Access Methods
    
    func identifyForgeLyteUser(_ userKey: String) async {
        guard isConfigured, !userKey.isEmpty else { return }
        if Purchases.shared.appUserID == userKey {
            AnalyticsService.configureActivationPal(userId: userKey)
            return
        }

        do {
            let (customerInfo, _) = try await Purchases.shared.logIn(userKey)
            updateSubscriptionStatus(from: customerInfo)
            AnalyticsService.configureActivationPal(userId: Purchases.shared.appUserID)
        } catch {
            print("RevenueCat logIn failed: \(error)")
        }
    }

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

        hasPriorPaidOrTrialHistory = customerInfo.entitlements.all["Pro"] != nil
            || customerInfo.allPurchasedProductIdentifiers.contains { identifier in
                let id = identifier.lowercased()
                return id.contains("month") || id.contains("year") || id.contains("annual")
                    || id.contains("lifetime")
            }

        synchronizeThemeAccess()
        // Workout iCloud is free; do not gate the CloudKit store on the Pro entitlement.

        // The user's tier and entitlements are account state; only log them in debug builds.
        #if DEBUG
        print("Updated subscription status - Current tier: \(currentTier.displayName)")
        print("Active entitlements: \(customerInfo.entitlements.active.keys)")
        #endif
    }

    private func synchronizeThemeAccess() {
        ThemePreference.shared.updateProAccess(true)
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
