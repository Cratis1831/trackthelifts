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
    
    @Published var currentTier: SubscriptionTier = .free
    @Published var isConfigured = false
    @Published var isLoading = false
    @Published var lastError: RevenueCatError?
    @Published var availablePackages: [Package] = []
    @Published var isTestingMode = false
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // Start with free tier until RevenueCat is properly configured
        currentTier = .free
    }
    
    func configure(apiKey: String) async {
        isLoading = true
        defer { isLoading = false }
        
        // Configure RevenueCat
        Purchases.configure(withAPIKey: apiKey)
        
        // Enable debug logs
        Purchases.logLevel = .debug
        
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
        guard isConfigured else {
            lastError = .notConfigured
            return false
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let result: PurchaseResultData = try await withCheckedThrowingContinuation { continuation in
                Purchases.shared.purchase(package: package) { transaction, customerInfo, error, userCancelled in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        let resultData = PurchaseResultData(
                            transaction: transaction,
                            customerInfo: customerInfo!,
                            userCancelled: userCancelled
                        )
                        continuation.resume(returning: resultData)
                    }
                }
            }
            
            updateSubscriptionStatus(from: result.customerInfo)
            
            if !result.userCancelled {
                print("Purchase successful: \(package.storeProduct.productIdentifier)")
                return true
            } else {
                lastError = .userCancelled
                return false
            }
            
        } catch {
            lastError = .purchaseFailed(error)
            print("Failed to purchase: \(error)")
            return false
        }
    }
    
    func restorePurchases() async -> Bool {
        guard isConfigured else {
            lastError = .notConfigured
            return false
        }
        
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
            print("Purchases restored successfully")
            return true
            
        } catch {
            lastError = .restoreFailed(error)
            print("Failed to restore purchases: \(error)")
            return false
        }
    }
    
    // MARK: - Offerings
    
    func loadOfferings() async {
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
                }
            }
        } catch {
            print("❌ Failed to load offerings: \(error)")
            print("💡 Trying StoreKit direct access as fallback...")
            
            // Fallback: Try to load products directly from StoreKit for testing
            await loadStoreKitProductsDirectly()
        }
    }
    
    // MARK: - StoreKit Fallback for Testing
    
    private func loadStoreKitProductsDirectly() async {
        print("🔄 Loading StoreKit products directly for testing...")
        
        // Create mock packages for testing when RevenueCat validation fails
        // This simulates what would happen with working RevenueCat offerings
        let mockProducts = [
            MockStoreProduct(
                id: "com.ashkansdev.trackthelifts.Monthly",
                displayName: "Track The Lifts Premium Monthly",
                description: "Monthly subscription to Track The Lifts Premium",
                price: 4.99,
                priceString: "$4.99"
            ),
            MockStoreProduct(
                id: "com.ashkansdev.trackthelifts.Annual", 
                displayName: "Track The Lifts Premium Annual",
                description: "Annual subscription to Track The Lifts Premium",
                price: 39.99,
                priceString: "$39.99"
            )
        ]
        
        // Create mock packages from the products
        var mockPackages: [MockPackage] = []
        for product in mockProducts {
            let package = MockPackage(storeProduct: product, identifier: product.id)
            mockPackages.append(package)
        }
        
        // For testing purposes, we'll use this mock data
        print("✅ Created \(mockPackages.count) mock packages for testing")
        print("📦 Mock packages: \(mockPackages.map { $0.identifier })")
        
        // Note: In production, remove this and ensure proper RevenueCat setup
    }
    
    // MARK: - Feature Access Methods
    
    func canAccessFeature(_ feature: String) -> Bool {
        switch feature {
        case PremiumFeature.iCloudSync:
            return currentTier.canUseiCloudSync
        default:
            return true // All other features are free for now
        }
    }
    
    func requiresPremium(for feature: String) -> Bool {
        switch feature {
        case PremiumFeature.iCloudSync:
            return !currentTier.canUseiCloudSync
        default:
            return false
        }
    }
    
    // MARK: - Private Methods
    
    private func updateSubscriptionStatus(from customerInfo: CustomerInfo) {
        // Check if user has active Pro entitlement
        if customerInfo.entitlements["Pro"]?.isActive == true {
            currentTier = .premium
        } else {
            currentTier = .free
        }
        
        print("Updated subscription status - Current tier: \(currentTier.displayName)")
        print("Active entitlements: \(customerInfo.entitlements.active.keys)")
    }
}