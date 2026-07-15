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
    
    @Published private(set) var entitlementTier: SubscriptionTier = .free
    @Published var isConfigured = false
    @Published var isLoading = false
    @Published var lastError: RevenueCatError?
    @Published var availablePackages: [Package] = []
    #if DEBUG
    @Published var debugTierOverride: SubscriptionTier? {
        didSet { synchronizeThemeAccess() }
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
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        #if DEBUG
        debugTierOverride = nil
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
            
            if let currentOffering = offerings.current {
                availablePackages = currentOffering.availablePackages
                print("✅ Loaded \(availablePackages.count) packages from current offering")
                print("Packages: \(availablePackages.map { $0.storeProduct.productIdentifier })")
            } else {
                print("⚠️ No current offering found - checking all offerings")
                // Fallback: use packages from any available offering
                for offering in offerings.all.values {
                    if !offering.availablePackages.isEmpty {
                        availablePackages = offering.availablePackages
                        print("✅ Using packages from offering: \(offering.identifier)")
                        break
                    }
                }
                
                if availablePackages.isEmpty {
                    print("❌ No packages found in any offerings")
                    lastError = .noOfferingsAvailable
                }
            }
        } catch {
            print("❌ Failed to load offerings: \(error)")
            lastError = .offeringsLoadFailed(error)
        }
    }
    
    // MARK: - Feature Access Methods
    
    func canAccess(_ feature: ProFeature) -> Bool {
        SubscriptionAccessPolicy.canAccess(feature, tier: currentTier)
    }
    
    func requiresPro(_ feature: ProFeature) -> Bool {
        !canAccess(feature)
    }
    
    // MARK: - Private Methods
    
    private func updateSubscriptionStatus(from customerInfo: CustomerInfo) {
        // Check if user has active Pro entitlement
        if customerInfo.entitlements["Pro"]?.isActive == true {
            entitlementTier = .pro
        } else {
            entitlementTier = .free
        }

        synchronizeThemeAccess()
        
        // The user's tier and entitlements are account state; only log them in debug builds.
        #if DEBUG
        print("Updated subscription status - Current tier: \(currentTier.displayName)")
        print("Active entitlements: \(customerInfo.entitlements.active.keys)")
        #endif
    }

    private func synchronizeThemeAccess() {
        ThemePreference.shared.updateProAccess(currentTier == .pro)
    }
}
