import SwiftUI
import RevenueCat

struct PaywallView: View {
    var focusedFeature: ProFeature? = nil
    var placement: String

    @EnvironmentObject var revenueCatService: RevenueCatService
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPackage: Package?
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showRestoreErrorAlert = false
    @State private var showRestoreResultAlert = false
    @State private var restoreResultMessage = ""

    @State private var hasUserChosenPackage = false
    @State private var didPurchase = false
    @State private var didSelectPlan = false

    init(focusedFeature: ProFeature? = nil, placement: String? = nil) {
        self.focusedFeature = focusedFeature
        if let placement {
            self.placement = placement
        } else if let focusedFeature {
            self.placement = AnalyticsProFeature(focusedFeature).activationPalPlacement
        } else {
            self.placement = "settings"
        }
    }

    var purchaseButtonText: String {
        guard let package = selectedPackage else {
            return "Select a Plan"
        }
        return SubscriptionOfferPresentation.purchaseButtonTitle(
            plan: package.planKind,
            price: package.storeProduct.localizedPriceString,
            intro: package.introOfferSummary,
            isIntroEligible: revenueCatService.isEligibleForFreeTrial(package)
        )
    }

    private var selectedIntroEligible: Bool {
        guard let selectedPackage else { return false }
        return revenueCatService.isEligibleForFreeTrial(selectedPackage)
    }

    /// Savings versus paying this storefront's monthly price for 12 months.
    private var annualSavingsPercent: Int? {
        guard
            let monthlyPackage = revenueCatService.monthlyPackage,
            let annualPackage = revenueCatService.annualPackage
        else { return nil }

        return SubscriptionOfferPresentation.yearlySavingsPercent(
            monthlyPrice: monthlyPackage.storeProduct.price,
            annualPrice: annualPackage.storeProduct.price
        )
    }

    private var legalFooterText: String {
        guard let package = selectedPackage else {
            return "Subscription automatically renews unless canceled at least 24 hours before the end of the current period."
        }
        return SubscriptionOfferPresentation.legalFooter(
            plan: package.planKind,
            price: package.storeProduct.localizedPriceString,
            intro: package.introOfferSummary,
            isIntroEligible: selectedIntroEligible
        )
    }

    private var displayedFeatures: [ProFeature] {
        let features = ProFeature.merchandised
        guard let focusedFeature, features.contains(focusedFeature) else { return features }
        return [focusedFeature] + features.filter { $0 != focusedFeature }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appCanvas
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Train for free. Upgrade when you want nutrition.")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.appTextPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("Smart nutrition tracking built into your workout app.")
                                .font(.system(size: 13))
                                .foregroundColor(.appTextSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.bottom, 4)

                        // Features Section
                        VStack(alignment: .leading, spacing: 7) {
                            ForEach(displayedFeatures) { feature in
                                FeatureRow(
                                    icon: feature.systemImage,
                                    iconColor: feature.iconColor,
                                    title: feature.title,
                                    description: feature.description
                                )
                            }
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
            .navigationTitle("ForgeLyte Lift Pro")
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
            ActivationPal.paywallShown(placement)
            selectDefaultPackageIfNeeded()
        }
        .onDisappear {
            if !didPurchase {
                ActivationPal.paywallDismissed()
            }
        }
        .onChange(of: revenueCatService.availablePackages.map(\.identifier)) {
            selectDefaultPackageIfNeeded()
        }
        .onChange(of: revenueCatService.hasEligibleMonthlyTrial) {
            selectDefaultPackageIfNeeded()
        }
        .onChange(of: revenueCatService.hasEligibleAnnualTrial) {
            selectDefaultPackageIfNeeded()
        }
        .appNotice(
            "Purchase Error",
            isPresented: $showingError,
            message: errorMessage
        )
        .appNotice(
            "Restore Failed",
            isPresented: $showRestoreErrorAlert,
            message: revenueCatService.lastError?.localizedDescription ?? "Couldn't restore your purchases. Please try again."
        )
        .appNotice(
            "Restore Purchases",
            isPresented: $showRestoreResultAlert,
            message: restoreResultMessage
        ) {
            if revenueCatService.currentTier == .pro {
                dismiss()
            }
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
            VStack(alignment: .leading, spacing: 8) {
                if let annualSavingsPercent {
                    Text("BEST VALUE · SAVE \(annualSavingsPercent)% WITH YEARLY")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundColor(.onAppAccent)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Color.appAccent, in: Capsule())
                }

                HStack(alignment: .top, spacing: 6) {
                    ForEach(revenueCatService.availablePackages, id: \.identifier) { package in
                        PackageCard(
                            package: package,
                            isSelected: selectedPackage?.identifier == package.identifier,
                            showsFreeTrial: revenueCatService.isEligibleForFreeTrial(package)
                        ) {
                            hasUserChosenPackage = true
                            selectedPackage = package
                            didSelectPlan = true
                            ActivationPal.paywallPlanSelected(package.activationPalPlan)
                        }
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
                if !didSelectPlan {
                    didSelectPlan = true
                    ActivationPal.paywallPlanSelected(package.activationPalPlan)
                }

                Task {
                    let success = await revenueCatService.purchasePackage(package)
                    if success {
                        didPurchase = true
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
                Text(legalFooterText)
                    .font(.system(size: 11))
                    .foregroundColor(Color.appTextSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)

                HStack(spacing: 6) {
                    Button("Restore Purchases") {
                        Task { await restorePurchases() }
                    }
                    .disabled(revenueCatService.isLoading)

                    Text("·")
                        .foregroundColor(Color.appTextSecondary)

                    Link("Terms of Service", destination: AppLinks.termsOfService)

                    Text("·")
                        .foregroundColor(Color.appTextSecondary)

                    Link("Privacy Policy", destination: AppLinks.privacyPolicy)
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

    // MARK: - Actions

    private func selectDefaultPackageIfNeeded() {
        guard !hasUserChosenPackage else { return }
        selectedPackage = revenueCatService.preferredPaywallPackage()
    }

    private func restorePurchases() async {
        let success = await revenueCatService.restorePurchases()
        if success {
            restoreResultMessage = revenueCatService.currentTier == .pro
                ? "Your Pro subscription has been restored."
                : "No active purchases were found to restore."
            showRestoreResultAlert = true
        } else {
            showRestoreErrorAlert = true
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            IconTile(color: iconColor, size: 28) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.appTextPrimary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.appTextPrimary)

                Text(description)
                    .font(.system(size: 10.5))
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
    var showsFreeTrial: Bool = false
    let action: () -> Void

    private var planKind: SubscriptionPlanKind { package.planKind }

    var planType: String { planKind.displayName }

    /// Short per-unit caption shown under the price in the compact card.
    private var trialCaption: String? {
        guard showsFreeTrial, let summary = package.introOfferSummary else { return nil }
        return SubscriptionOfferPresentation.trialCardCaption(for: summary)
    }

    private var renewalCaption: String {
        SubscriptionOfferPresentation.trialRenewalCaption(
            price: package.storeProduct.localizedPriceString,
            plan: planKind
        )
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Text(planType)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundColor(.appTextPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                VStack(spacing: 1) {
                    if let trialCaption {
                        Text(trialCaption)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.appTextPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text(renewalCaption)
                            .font(.system(size: 8.5, weight: .medium))
                            .foregroundColor(.appAccent)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    } else {
                        Text(package.storeProduct.localizedPriceString)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.appTextPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.62)
                        Text(planKind.unitCaption)
                            .font(.system(size: 8.5, weight: .medium))
                            .foregroundColor(Color.appTextSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .appAccent : Color.appTextSecondary)
                    .font(.system(size: 16))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 3)
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
        case .calorieTracking: return Color(red: 0.95, green: 0.55, blue: 0.19)
        case .foodSearch: return Color(red: 0.20, green: 0.48, blue: 0.96)
        case .barcodeScan: return Color(red: 0.30, green: 0.72, blue: 0.40)
        case .aiDescribe: return Color(red: 0.58, green: 0.36, blue: 0.90)
        case .foodPhoto: return Color(red: 0.88, green: 0.38, blue: 0.50)
        case .labelScan: return Color(red: 0.20, green: 0.68, blue: 0.70)
        case .nutritionBackup: return Color(red: 0.20, green: 0.48, blue: 0.96)
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
                .onAppear {
                    AnalyticsService.track(.paywallShown(feature: AnalyticsProFeature(selectedFeature)))
                }
        }
    }
}

#Preview {
    PaywallView()
        .environmentObject(RevenueCatService.shared)
}
