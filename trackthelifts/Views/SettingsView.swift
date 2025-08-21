//
//  SettingsView.swift
//  TrackTheLifts
//
//  Created by Ashkan Sotoudeh on 2025-07-02.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var revenueCatService: RevenueCatService
    @State private var isPaywallPresented = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        
                        // Subscription Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Subscription")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(.white)
                            
                            // Current Tier Card
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Current Plan")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(Color(red: 0.56, green: 0.56, blue: 0.58))
                                        
                                        Text(revenueCatService.currentTier.displayName)
                                            .font(.system(size: 20, weight: .semibold))
                                            .foregroundColor(.white)
                                    }
                                    
                                    Spacer()
                                    
                                    if revenueCatService.currentTier == .premium {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.orange)
                                            .font(.system(size: 24))
                                    }
                                }
                                
                                // Features List
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(revenueCatService.currentTier.features, id: \.self) { feature in
                                        HStack(spacing: 8) {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.orange)
                                                .font(.system(size: 12, weight: .bold))
                                            
                                            Text(feature)
                                                .font(.system(size: 14))
                                                .foregroundColor(Color(red: 0.56, green: 0.56, blue: 0.58))
                                        }
                                    }
                                }
                                
                                // Upgrade Button (only for free tier)
                                if revenueCatService.currentTier == .free {
                                    Button(action: {
                                        isPaywallPresented = true
                                    }) {
                                        HStack {
                                            Text("Upgrade to Premium")
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundColor(.white)
                                            
                                            Spacer()
                                            
                                            Image(systemName: "arrow.right")
                                                .foregroundColor(.white)
                                                .font(.system(size: 14, weight: .medium))
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                        .background(Color.orange)
                                        .cornerRadius(8)
                                    }
                                    .padding(.top, 8)
                                }
                            }
                            .padding(16)
                            .background(Color(red: 0.11, green: 0.11, blue: 0.12))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(red: 0.17, green: 0.17, blue: 0.18), lineWidth: 1)
                            )
                            
                            // Restore Purchases Button
                            Button(action: {
                                Task {
                                    await revenueCatService.restorePurchases()
                                }
                            }) {
                                HStack {
                                    Text("Restore Purchases")
                                        .font(.system(size: 16))
                                        .foregroundColor(.orange)
                                    
                                    if revenueCatService.isLoading {
                                        Spacer()
                                        ProgressView()
                                            .scaleEffect(0.8)
                                            .tint(.orange)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color(red: 0.11, green: 0.11, blue: 0.12))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color(red: 0.17, green: 0.17, blue: 0.18), lineWidth: 1)
                                )
                            }
                            .disabled(revenueCatService.isLoading)
                        }
                        
                        // App Settings Section (placeholder for future settings)
                        VStack(alignment: .leading, spacing: 16) {
                            Text("App Settings")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(.white)
                            
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Additional settings will be added here")
                                    .font(.system(size: 16))
                                    .foregroundColor(Color(red: 0.56, green: 0.56, blue: 0.58))
                            }
                            .padding(16)
                            .background(Color(red: 0.11, green: 0.11, blue: 0.12))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(red: 0.17, green: 0.17, blue: 0.18), lineWidth: 1)
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Settings")
        }
        .fullScreenCover(isPresented: $isPaywallPresented) {
            PaywallView()
        }
    }
}

#Preview {
    SettingsView()
}
