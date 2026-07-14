import SwiftUI
import RevenueCat

struct PaywallView: View {
    var focusedFeature: ProFeature? = nil

    @EnvironmentObject var revenueCatService: RevenueCatService
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPackage: Package?
    @State private var showingError = false
    @State private var errorMessage = ""

    var purchaseButtonText: String {
        guard let package = selectedPackage else {
            return "Select a Plan"
        }
        let price = package.storeProduct.localizedPriceString
        if package.packageType == .lifetime {
            return "Get Lifetime Access - \(price)"
        } else {
            return "Start Pro - \(price)"
        }
    }

    /// The monthly package from the current offering, used to compute annual savings.
    /// Falls back to identifier matching when the package type isn't set.
    private var monthlyPackage: Package? {
        revenueCatService.availablePackages.first { $0.packageType == .monthly }
            ?? revenueCatService.availablePackages.first {
                $0.storeProduct.productIdentifier.lowercased().contains("month")
            }
    }

    /// Whether the currently selected plan is a one-time (non-subscription) purchase.
    private var isLifetimeSelected: Bool {
        selectedPackage?.packageType == .lifetime
    }

    private var displayedFeatures: [ProFeature] {
        guard let focusedFeature else { return ProFeature.allCases }
        return [focusedFeature] + ProFeature.allCases.filter { $0 != focusedFeature }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appCanvas
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {

                        // Features Section
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(displayedFeatures) { feature in
                                FeatureRow(
                                    icon: feature.systemImage,
                                    iconColor: feature.iconColor,
                                    title: feature.title,
                                    description: feature.description
                                )
                            }

                            FeatureRow(
                                icon: "sparkles",
                                iconColor: Color(red: 0.95, green: 0.72, blue: 0.20),
                                title: "All Future Pro Features",
                                description: "Every new Pro feature we add, included automatically"
                            )
                        }

                        // Pricing Plans
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Choose Your Plan")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.appTextPrimary)

                            plansSection
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                }
            }
            .safeAreaInset(edge: .bottom) {
                purchaseFooter
            }
            .navigationTitle("Track The Lifts Pro")
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

    // MARK: - Plans

    @ViewBuilder
    private var plansSection: some View {
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
            HStack(alignment: .top, spacing: 10) {
                ForEach(revenueCatService.availablePackages, id: \.identifier) { package in
                    PackageCard(
                        package: package,
                        isSelected: selectedPackage?.identifier == package.identifier,
                        monthlyPackage: monthlyPackage
                    ) {
                        selectedPackage = package
                    }
                }
            }
        }
    }

    // MARK: - Pinned purchase footer

    @ViewBuilder
    private var purchaseFooter: some View {
        VStack(spacing: 10) {
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

            VStack(spacing: 6) {
                Text(isLifetimeSelected
                     ? "One-time purchase. No subscription, no renewals."
                     : "Subscription automatically renews unless canceled at least 24 hours before the end of the current period.")
                    .font(.system(size: 11))
                    .foregroundColor(Color.appTextSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    Link("Terms of Service", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)

                    Text("·")
                        .foregroundColor(Color.appTextSecondary)

                    Link("Privacy Policy", destination: URL(string: "https://www.forgelyte.com/apps/TrackTheLifts/privacy-policy")!)
                }
                .font(.system(size: 11))
                .foregroundColor(.appAccent)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(Color.appCanvas)
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
                    .lineLimit(2)
            }

            Spacer()
        }
    }
}

struct PackageCard: View {
    let package: Package
    let isSelected: Bool
    /// The monthly package, when present, so annual savings can be computed from real store prices.
    var monthlyPackage: Package? = nil
    let action: () -> Void

    /// Falls back to matching the product identifier for custom/unknown package types.
    private var identifier: String {
        package.storeProduct.productIdentifier.lowercased()
    }

    var planType: String {
        switch package.packageType {
        case .monthly:
            return "Monthly"
        case .annual:
            return "Yearly"
        case .lifetime:
            return "Lifetime"
        default:
            if identifier.contains("month") {
                return "Monthly"
            } else if identifier.contains("annual") || identifier.contains("year") {
                return "Yearly"
            } else if identifier.contains("lifetime") || identifier.contains("life") {
                return "Lifetime"
            } else {
                return "Pro"
            }
        }
    }

    /// Short per-unit caption shown under the price in the compact card.
    var unitCaption: String {
        switch planType {
        case "Monthly":
            return "per month"
        case "Yearly":
            return "per year"
        case "Lifetime":
            return "one-time"
        default:
            return ""
        }
    }

    /// Percentage saved by paying yearly instead of 12× monthly, computed from real store prices.
    private var savingsPercent: Int? {
        guard planType == "Yearly", let monthlyPackage else { return nil }
        let yearlyPrice = package.storeProduct.price
        let annualizedMonthly = monthlyPackage.storeProduct.price * 12
        guard annualizedMonthly > 0, yearlyPrice < annualizedMonthly else { return nil }
        let fraction = (annualizedMonthly - yearlyPrice) / annualizedMonthly
        let percent = NSDecimalNumber(decimal: fraction * 100).intValue
        return percent > 0 ? percent : nil
    }

    /// Badge shown at the top of the card (savings on the yearly plan).
    var badge: String? {
        guard let savingsPercent else { return nil }
        return "SAVE \(savingsPercent)%"
    }

    #if DEBUG
    /// Reports which step of the savings calculation fails, for the yearly card.
    var savingsDebug: String {
        guard planType == "Yearly" else { return "notYr:\(planType)" }
        guard let monthlyPackage else { return "noMonthly" }
        let yearly = package.storeProduct.price
        let annualized = monthlyPackage.storeProduct.price * 12
        guard annualized > 0 else { return "ann=0" }
        guard yearly < annualized else { return "y>=a \(yearly)/\(annualized)" }
        let fraction = (annualized - yearly) / annualized
        let percent = NSDecimalNumber(decimal: fraction * 100).intValue
        return "ok:\(percent)"
    }
    #endif


    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                // Badge slot — fixed height so all cards align even when only one has a badge.
                // DEBUG: show the savings-calc failure point so we can see why it's nil.
                ZStack {
                    Text(badge ?? savingsDebug)
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundColor(.onAppAccent)
                        .lineLimit(2)
                        .minimumScaleFactor(0.5)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.appAccent, in: Capsule())
                }
                .frame(height: 30)

                Text(planType)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.appTextPrimary)

                VStack(spacing: 2) {
                    Text(package.storeProduct.localizedPriceString)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.appTextPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text(unitCaption)
                        .font(.system(size: 11))
                        .foregroundColor(Color.appTextSecondary)
                }

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .appAccent : Color.appTextSecondary)
                    .font(.system(size: 20))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 8)
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

extension ProFeature {
    var iconColor: Color {
        switch self {
        case .unlimitedRoutines: return Color(red: 0.95, green: 0.55, blue: 0.19)
        case .advancedProgress: return Color(red: 0.20, green: 0.48, blue: 0.96)
        case .effortTracking: return Color(red: 0.88, green: 0.38, blue: 0.50)
        case .supersets: return Color(red: 0.30, green: 0.72, blue: 0.40)
        case .accentThemes: return Color(red: 0.58, green: 0.36, blue: 0.90)
        }
    }
}

struct ProBadge: View {
    var body: some View {
        Text("PRO")
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .tracking(0.7)
            .foregroundColor(.onAppAccent)
            .padding(.horizontal, 6)
            .frame(height: 18)
            .background(Color.appAccent)
            .clipShape(Capsule())
    }
}

struct LockedProFeatureCard: View {
    let feature: ProFeature
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                IconTile(color: feature.iconColor) {
                    Image(systemName: feature.systemImage)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.appTextPrimary)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(feature.title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.appTextPrimary)
                        ProBadge()
                    }
                    Text(feature.description)
                        .font(.system(size: 12))
                        .foregroundColor(.appTextSecondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)
                Image(systemName: "lock.fill")
                    .foregroundColor(.appTextSecondary)
            }
            .padding(14)
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: AppDesign.cardRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppDesign.cardRadius, style: .continuous)
                    .strokeBorder(Color.appBorder, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

extension View {
    func proPaywall(feature: Binding<ProFeature?>) -> some View {
        fullScreenCover(item: feature) { selectedFeature in
            PaywallView(focusedFeature: selectedFeature)
        }
    }
}

#Preview {
    PaywallView()
        .environmentObject(RevenueCatService.shared)
}
