//
//  OnboardingView.swift
//  TrackTheLifts
//

import SwiftUI

/// First-launch walkthrough shown once, gated by `hasCompletedOnboarding` in `ContentView`.
/// Can be re-shown any time via "Reset Onboarding" in Settings, for testing.
///
/// Three pages: an animated welcome, a staggered tour of the app's core features, and a final
/// call to action. Each page animates in when it becomes the current page and resets when it
/// swipes away, so revisiting a page replays its entrance.
struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var currentPage = 0

    private static let pageCount = 3

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Soft accent wash behind the content so the black canvas doesn't read flat.
            Circle()
                .fill(Color.appAccent.opacity(0.14))
                .frame(width: 420, height: 420)
                .blur(radius: 100)
                .offset(y: -240)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button("Skip") {
                        hasCompletedOnboarding = true
                    }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color(red: 0.56, green: 0.56, blue: 0.58))
                    .padding(.trailing, 24)
                    .padding(.top, 8)
                    // Keep the layout stable on the last page; just fade the button away.
                    .opacity(currentPage == Self.pageCount - 1 ? 0 : 1)
                    .animation(.easeOut(duration: 0.2), value: currentPage)
                }

                TabView(selection: $currentPage) {
                    WelcomePage(isActive: currentPage == 0)
                        .tag(0)
                    FeaturesPage(isActive: currentPage == 1)
                        .tag(1)
                    ReadyPage(isActive: currentPage == 2)
                        .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                pageIndicator
                    .padding(.bottom, 24)

                Button {
                    if currentPage < Self.pageCount - 1 {
                        withAnimation {
                            currentPage += 1
                        }
                    } else {
                        hasCompletedOnboarding = true
                    }
                } label: {
                    Text(currentPage == Self.pageCount - 1 ? "Start Lifting" : "Continue")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .background(
                            Capsule().fill(Color.appAccent)
                        )
                        .shadow(color: Color.appAccent.opacity(0.35), radius: 12, y: 6)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
        }
    }

    /// Custom page dots: the current page stretches into an accent capsule.
    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<Self.pageCount, id: \.self) { index in
                Capsule()
                    .fill(index == currentPage ? Color.appAccent : Color(red: 0.25, green: 0.25, blue: 0.27))
                    .frame(width: index == currentPage ? 24 : 8, height: 8)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: currentPage)
    }
}

// MARK: - Page 1: Welcome

private struct WelcomePage: View {
    let isActive: Bool
    @State private var showMark = false
    @State private var showText = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.appAccent, Color.appAccent.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 112, height: 112)
                .overlay(
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 50, weight: .medium))
                        .foregroundColor(.white)
                        .rotationEffect(.degrees(showMark ? -45 : -90))
                )
                .shadow(color: Color.appAccent.opacity(0.45), radius: 24, y: 10)
                .scaleEffect(showMark ? 1 : 0.5)
                .opacity(showMark ? 1 : 0)

            VStack(spacing: 14) {
                Text("Welcome to")
                    .font(.system(size: 15, weight: .semibold))
                    .tracking(2)
                    .textCase(.uppercase)
                    .foregroundColor(Color(red: 0.56, green: 0.56, blue: 0.58))

                Text("Track The Lifts")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.white)

                Text("The fastest way to log your lifts and watch your strength grow.")
                    .font(.system(size: 16))
                    .foregroundColor(Color(red: 0.66, green: 0.66, blue: 0.68))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 44)
            }
            .padding(.top, 32)
            .opacity(showText ? 1 : 0)
            .offset(y: showText ? 0 : 16)

            Spacer()
            Spacer()
        }
        .onAppear { if isActive { animateIn() } }
        .onChange(of: isActive) { _, active in
            if active { animateIn() } else { reset() }
        }
    }

    private func animateIn() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            showMark = true
        }
        withAnimation(.easeOut(duration: 0.5).delay(0.25)) {
            showText = true
        }
    }

    private func reset() {
        showMark = false
        showText = false
    }
}

// MARK: - Page 2: Feature tour

private struct OnboardingFeature: Identifiable {
    let symbol: String
    let color: Color
    let title: String
    let detail: String

    var id: String { title }
}

private struct FeaturesPage: View {
    let isActive: Bool
    @State private var showHeader = false
    @State private var visibleRows = 0

    // The app's current core features, in the order a new lifter meets them. Update this list
    // when a headline feature ships so onboarding never drifts out of date again.
    private static let features: [OnboardingFeature] = [
        OnboardingFeature(
            symbol: "dumbbell.fill",
            color: Color(red: 0.90, green: 0.30, blue: 0.24),
            title: "Log Every Set",
            detail: "Weight, reps, and warm-up or working sets, with last session's numbers beside each one."
        ),
        OnboardingFeature(
            symbol: "timer",
            color: Color(red: 0.20, green: 0.48, blue: 0.96),
            title: "Automatic Rest Timer",
            detail: "Starts the moment you check off a set and alerts you even when the app is closed."
        ),
        OnboardingFeature(
            symbol: "trophy.fill",
            color: Color(red: 0.85, green: 0.62, blue: 0.20),
            title: "Personal Records",
            detail: "New weight, estimated 1RM, and volume bests are spotted and celebrated automatically."
        ),
        OnboardingFeature(
            symbol: "square.on.square",
            color: Color(red: 0.58, green: 0.36, blue: 0.90),
            title: "Reusable Routines",
            detail: "Save any workout as a routine and start your next session in one tap."
        ),
        OnboardingFeature(
            symbol: "chart.line.uptrend.xyaxis",
            color: Color(red: 0.30, green: 0.72, blue: 0.40),
            title: "Progress Charts",
            detail: "Consistency, training volume, and estimated 1RM trends for every exercise."
        ),
        OnboardingFeature(
            symbol: "square.and.arrow.up",
            color: Color(red: 0.20, green: 0.68, blue: 0.70),
            title: "Your Data, Anywhere",
            detail: "Your full history is editable and exports to CSV whenever you want it."
        ),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 12)

            VStack(alignment: .leading, spacing: 8) {
                Text("Built for the way you train")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)

                Text("Everything below is already in the app, ready on day one.")
                    .font(.system(size: 15))
                    .foregroundColor(Color(red: 0.56, green: 0.56, blue: 0.58))
            }
            .padding(.horizontal, 28)
            .opacity(showHeader ? 1 : 0)
            .offset(y: showHeader ? 0 : 12)

            VStack(spacing: 14) {
                ForEach(Array(Self.features.enumerated()), id: \.element.id) { index, feature in
                    featureRow(feature)
                        .opacity(index < visibleRows ? 1 : 0)
                        .offset(x: index < visibleRows ? 0 : 28)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)

            Spacer(minLength: 12)
        }
        .onAppear { if isActive { animateIn() } }
        .onChange(of: isActive) { _, active in
            if active { animateIn() } else { reset() }
        }
    }

    private func featureRow(_ feature: OnboardingFeature) -> some View {
        HStack(spacing: 14) {
            IconTile(color: feature.color, size: 40, cornerRadius: 11) {
                Image(systemName: feature.symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(feature.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)

                Text(feature.detail)
                    .font(.system(size: 13))
                    .foregroundColor(Color(red: 0.62, green: 0.62, blue: 0.64))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }

    private func animateIn() {
        withAnimation(.easeOut(duration: 0.4)) {
            showHeader = true
        }
        for index in 0..<Self.features.count {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.15 + Double(index) * 0.09)) {
                visibleRows = max(visibleRows, index + 1)
            }
        }
    }

    private func reset() {
        showHeader = false
        visibleRows = 0
    }
}

// MARK: - Page 3: Ready

private struct ReadyPage: View {
    let isActive: Bool
    @State private var showSeal = false
    @State private var showText = false
    @State private var ringExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                // One-shot ring that expands and fades behind the seal as it pops in.
                Circle()
                    .stroke(Color.appAccent.opacity(ringExpanded ? 0 : 0.5), lineWidth: 2)
                    .frame(width: 96, height: 96)
                    .scaleEffect(ringExpanded ? 1.9 : 1)

                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 72))
                    .foregroundColor(.appAccent)
                    .shadow(color: Color.appAccent.opacity(0.4), radius: 20, y: 8)
                    .scaleEffect(showSeal ? 1 : 0.4)
                    .opacity(showSeal ? 1 : 0)
            }

            VStack(spacing: 14) {
                Text("You're All Set")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(.white)

                Text("Your first workout is one tap away. Every set you log makes the picture of your progress sharper.")
                    .font(.system(size: 16))
                    .foregroundColor(Color(red: 0.66, green: 0.66, blue: 0.68))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 44)
            }
            .padding(.top, 28)
            .opacity(showText ? 1 : 0)
            .offset(y: showText ? 0 : 16)

            Spacer()
            Spacer()
        }
        .onAppear { if isActive { animateIn() } }
        .onChange(of: isActive) { _, active in
            if active { animateIn() } else { reset() }
        }
    }

    private func animateIn() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
            showSeal = true
        }
        withAnimation(.easeOut(duration: 0.9).delay(0.1)) {
            ringExpanded = true
        }
        withAnimation(.easeOut(duration: 0.5).delay(0.25)) {
            showText = true
        }
    }

    private func reset() {
        showSeal = false
        showText = false
        ringExpanded = false
    }
}

#Preview {
    OnboardingView()
}
