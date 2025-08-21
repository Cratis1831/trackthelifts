import SwiftUI
import RevenueCat

struct PaywallView: View {
    @EnvironmentObject var revenueCatService: RevenueCatService
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPackage: Package?
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var purchaseButtonText: String {
        if let package = selectedPackage {
            return "Start Premium - \(package.storeProduct.localizedPriceString)"
        } else {
            return "Select a Plan"
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 30) {
                        
                        // Header Section
                        VStack(alignment: .center, spacing: 16) {
                            Image(systemName: "icloud")
                                .font(.system(size: 60))
                                .foregroundColor(.orange)
                            
                            Text("Upgrade to Premium")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                            
                            Text("Sync your workouts across all your devices with iCloud")
                                .font(.system(size: 18))
                                .foregroundColor(Color(red: 0.56, green: 0.56, blue: 0.58))
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        
                        // Features Section
                        VStack(alignment: .leading, spacing: 20) {
                            Text("Premium Features")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(.white)
                            
                            VStack(alignment: .leading, spacing: 16) {
                                FeatureRow(
                                    icon: "icloud.and.arrow.up",
                                    title: "iCloud Sync",
                                    description: "Automatically sync your workouts across iPhone, iPad, and Mac"
                                )
                                
                                FeatureRow(
                                    icon: "arrow.clockwise.icloud",
                                    title: "Automatic Backup",
                                    description: "Never lose your workout data with secure cloud backup"
                                )
                                
                                FeatureRow(
                                    icon: "smartphone",
                                    title: "Multi-Device Access",
                                    description: "Access your workouts from any of your Apple devices"
                                )
                                
                                FeatureRow(
                                    icon: "lock.shield",
                                    title: "Secure & Private",
                                    description: "Your data is encrypted and stored securely in your iCloud"
                                )
                            }
                        }
                        
                        // Pricing Plans
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Choose Your Plan")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(.white)
                            
                            if revenueCatService.availablePackages.isEmpty {
                                VStack(spacing: 12) {
                                    ProgressView()
                                        .tint(.orange)
                                    Text("Loading subscription plans...")
                                        .font(.system(size: 16))
                                        .foregroundColor(Color(red: 0.56, green: 0.56, blue: 0.58))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(40)
                            } else {
                                VStack(spacing: 12) {
                                    ForEach(revenueCatService.availablePackages, id: \.identifier) { package in
                                        PackageCard(
                                            package: package,
                                            isSelected: selectedPackage?.identifier == package.identifier
                                        ) {
                                            selectedPackage = package
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Purchase Button
                        Button(action: {
                            guard let package = selectedPackage else { return }
                            
                            Task {
                                let success = await revenueCatService.purchasePackage(package)
                                if success {
                                    dismiss()
                                } else if let error = revenueCatService.lastError {
                                    errorMessage = error.localizedDescription
                                    showingError = true
                                }
                            }
                        }) {
                            HStack {
                                if revenueCatService.isLoading {
                                    ProgressView()
                                        .scaleEffect(0.9)
                                        .tint(.white)
                                } else {
                                    Text(purchaseButtonText)
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(selectedPackage != nil ? Color.orange : Color.gray)
                            .cornerRadius(12)
                        }
                        .disabled(revenueCatService.isLoading || selectedPackage == nil)
                        
                        // Footer
                        VStack(spacing: 8) {
                            Text("• Cancel anytime")
                                .font(.system(size: 14))
                                .foregroundColor(Color(red: 0.56, green: 0.56, blue: 0.58))
                            
                            Text("• Auto-renewal can be turned off in Account Settings")
                                .font(.system(size: 14))
                                .foregroundColor(Color(red: 0.56, green: 0.56, blue: 0.58))
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Premium")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.orange)
                }
            }
        }
        .onAppear {
            // Auto-select first package if available
            if selectedPackage == nil && !revenueCatService.availablePackages.isEmpty {
                selectedPackage = revenueCatService.availablePackages.first
            }
        }
        .alert("Purchase Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .foregroundColor(.orange)
                .font(.system(size: 24))
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.system(size: 15))
                    .foregroundColor(Color(red: 0.56, green: 0.56, blue: 0.58))
                    .lineLimit(nil)
            }
            
            Spacer()
        }
    }
}

struct PackageCard: View {
    let package: Package
    let isSelected: Bool
    let action: () -> Void
    
    var planType: String {
        let identifier = package.storeProduct.productIdentifier.lowercased()
        if identifier.contains("month") {
            return "Monthly"
        } else if identifier.contains("annual") || identifier.contains("year") {
            return "Yearly"
        } else {
            return "Premium"
        }
    }
    
    var description: String {
        let identifier = package.storeProduct.productIdentifier.lowercased()
        if identifier.contains("month") {
            return "Billed monthly, cancel anytime"
        } else if identifier.contains("annual") || identifier.contains("year") {
            return "Billed yearly, best value"
        } else {
            return "Premium subscription"
        }
    }
    
    var savings: String? {
        let identifier = package.storeProduct.productIdentifier.lowercased()
        if identifier.contains("annual") || identifier.contains("year") {
            return "Save 33%"
        } else {
            return nil
        }
    }
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(planType)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                        
                        if let savings = savings {
                            Text(savings)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.orange)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.orange.opacity(0.2))
                                .cornerRadius(4)
                        }
                    }
                    
                    Text(description)
                        .font(.system(size: 14))
                        .foregroundColor(Color(red: 0.56, green: 0.56, blue: 0.58))
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text(package.storeProduct.localizedPriceString)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .orange : Color(red: 0.56, green: 0.56, blue: 0.58))
                    .font(.system(size: 24))
            }
            .padding(16)
            .background(Color(red: 0.11, green: 0.11, blue: 0.12))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.orange : Color(red: 0.17, green: 0.17, blue: 0.18), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    PaywallView()
        .environmentObject(RevenueCatService.shared)
}