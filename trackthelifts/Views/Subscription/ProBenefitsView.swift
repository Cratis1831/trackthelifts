import SwiftUI

/// Shown when a subscribed user taps the compact "Pro" row in Settings. Surfaces the same
/// feature list advertised on the paywall, plus the subscription-management affordances (App
/// Store's subscription page, Restore Purchases) that don't need real estate in Settings once
/// someone's already subscribed but must stay reachable somewhere per App Store guidelines.
struct ProBenefitsView: View {
    @EnvironmentObject var revenueCatService: RevenueCatService
    @Environment(\.dismiss) private var dismiss
    @State private var showRestoreErrorAlert = false
    @State private var showRestoreResultAlert = false
    @State private var restoreResultMessage = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appCanvas
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(spacing: 8) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 44))
                                .foregroundColor(.appAccent)

                            Text("You're a Pro Member")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.appTextPrimary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)

                        VStack(alignment: .leading, spacing: 16) {
                            Text("Your Benefits")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.appTextPrimary)

                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(ProFeature.allCases) { feature in
                                    FeatureRow(
                                        icon: feature.systemImage,
                                        iconColor: feature.iconColor,
                                        title: feature.title,
                                        description: feature.description
                                    )
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 0) {
                            Link(destination: URL(string: "https://apps.apple.com/account/subscriptions")!) {
                                HStack {
                                    Text("Manage Subscription")
                                        .font(.system(size: 16))
                                        .foregroundColor(.appTextPrimary)
                                    Spacer()
                                    Image(systemName: "arrow.up.right")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(Color.appTextSecondary)
                                }
                                .padding(.vertical, 12)
                            }

                            Divider()
                                .background(Color.appBorder)

                            Button {
                                Task {
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
                            } label: {
                                HStack {
                                    Text("Restore Purchases")
                                        .font(.system(size: 16))
                                        .foregroundColor(.appTextPrimary)
                                    Spacer()
                                    if revenueCatService.isLoading {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    }
                                }
                                .padding(.vertical, 12)
                            }
                            .disabled(revenueCatService.isLoading)
                        }
                        .padding(.horizontal, 16)
                        .background(Color.appSurface)
                        .cornerRadius(AppDesign.cardRadius)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppDesign.cardRadius)
                                .stroke(Color.appBorder, lineWidth: 1)
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Pro Benefits")
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
        .alert("Restore Failed", isPresented: $showRestoreErrorAlert) {
            Button("OK") { }
        } message: {
            Text(revenueCatService.lastError?.localizedDescription ?? "Couldn't restore your purchases. Please try again.")
        }
        .alert("Restore Purchases", isPresented: $showRestoreResultAlert) {
            Button("OK") { }
        } message: {
            Text(restoreResultMessage)
        }
    }
}

#Preview {
    ProBenefitsView()
        .environmentObject(RevenueCatService.shared)
}
