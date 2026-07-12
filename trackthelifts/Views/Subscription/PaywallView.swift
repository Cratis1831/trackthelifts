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
                Color.appCanvas
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        
                        // Features Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Upgrade to Premium")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.appTextPrimary)
                                .frame(maxWidth: .infinity)
                                .multilineTextAlignment(.center)

                            VStack(alignment: .leading, spacing: 12) {
                                FeatureRow(
                                    icon: "icloud.and.arrow.up",
                                    iconColor: Color(red: 0.20, green: 0.48, blue: 0.96),
                                    title: "iCloud Sync",
                                    description: "Automatically sync your workouts across iPhone, iPad, and Mac"
                                )

                                FeatureRow(
                                    icon: "arrow.clockwise.icloud",
                                    iconColor: Color(red: 0.36, green: 0.42, blue: 0.90),
                                    title: "Automatic Backup",
                                    description: "Never lose your workout data with secure cloud backup"
                                )

                                FeatureRow(
                                    icon: "smartphone",
                                    iconColor: Color(red: 0.30, green: 0.72, blue: 0.40),
                                    title: "Multi-Device Access",
                                    description: "Access your workouts from any of your Apple devices"
                                )

                                FeatureRow(
                                    icon: "lock.shield",
                                    iconColor: Color(red: 0.58, green: 0.36, blue: 0.90),
                                    title: "Secure & Private",
                                    description: "Your data is encrypted and stored securely in your iCloud"
                                )
                            }
                        }
                        
                        // Pricing Plans
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Choose Your Plan")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.appTextPrimary)
                            
                            if revenueCatService.availablePackages.isEmpty {
                                if let lastError = revenueCatService.lastError {
                                    EmptyStateView(
                                        systemImage: "exclamationmark.triangle",
                                        title: "Couldn't Load Plans",
                                        message: lastError.localizedDescription,
                                        actionTitle: "Retry",
                                        action: {
                                            Task {
                                                await revenueCatService.loadOfferings()
                                            }
                                        }
                                    )
                                    .padding(.vertical, 20)
                                } else {
                                    VStack(spacing: 12) {
                                        ProgressView()
                                            .tint(.appAccent)
                                        Text("Loading subscription plans...")
                                            .font(.system(size: 14))
                                            .foregroundColor(Color.appTextSecondary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(40)
                                }
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
                                        .tint(selectedPackage != nil ? .onAppAction : .appTextSecondary)
                                } else {
                                    Text(purchaseButtonText)
                                }
                            }
                        }
                        .buttonStyle(AppPrimaryButtonStyle())
                        .opacity(selectedPackage == nil ? 0.42 : 1)
                        .disabled(revenueCatService.isLoading || selectedPackage == nil)
                        
                        // Footer
                        VStack(spacing: 8) {
                            Text("Subscription automatically renews unless canceled at least 24 hours before the end of the current period.")
                                .font(.system(size: 11))
                                .foregroundColor(Color.appTextSecondary)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)

                            Link("Terms of Service", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                                .font(.system(size: 11))
                                .foregroundColor(.appAccent)
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
                    .foregroundColor(.appAccent)
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
    let iconColor: Color
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            IconTile(color: iconColor, size: 32) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.appTextPrimary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.appTextPrimary)

                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(Color.appTextSecondary)
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
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.appTextPrimary)
                        
                        if let savings = savings {
                            Text(savings)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.appAccent)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.appAccent.opacity(0.2))
                                .cornerRadius(4)
                        }
                    }
                    
                    Text(description)
                        .font(.system(size: 12))
                        .foregroundColor(Color.appTextSecondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text(package.storeProduct.localizedPriceString)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.appTextPrimary)
                }
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .appAccent : Color.appTextSecondary)
                    .font(.system(size: 24))
            }
            .padding(16)
            .background(Color.appSurface)
            .cornerRadius(AppDesign.cardRadius)
            .overlay(
                RoundedRectangle(cornerRadius: AppDesign.cardRadius)
                    .stroke(isSelected ? Color.appAccent : Color.appBorder, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    PaywallView()
        .environmentObject(RevenueCatService.shared)
}
