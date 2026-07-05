//
//  OnboardingView.swift
//  TrackTheLifts
//

import SwiftUI

/// First-launch walkthrough shown once, gated by `hasCompletedOnboarding` in `ContentView`.
/// Can be re-shown any time via "Reset Onboarding" in Settings, for testing.
struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var currentPage = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            systemImage: "dumbbell.fill",
            title: "Welcome to Track The Lifts",
            message: "Log your workouts, track every set, and watch your strength grow over time."
        ),
        OnboardingPage(
            systemImage: "plus.circle.fill",
            title: "Create & Log Workouts",
            message: "Start a workout, add exercises, and log weight and reps for every set as you go."
        ),
        OnboardingPage(
            systemImage: "chart.line.uptrend.xyaxis",
            title: "Track Progress & PRs",
            message: "See your consistency, training volume, and personal records update automatically as you train."
        ),
        OnboardingPage(
            systemImage: "checkmark.seal.fill",
            title: "You're All Set",
            message: "Let's log your first workout."
        ),
    ]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        pageView(page)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))

                Button {
                    if currentPage < pages.count - 1 {
                        withAnimation {
                            currentPage += 1
                        }
                    } else {
                        hasCompletedOnboarding = true
                    }
                } label: {
                    Text(currentPage < pages.count - 1 ? "Next" : "Get Started")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
    }

    private func pageView(_ page: OnboardingPage) -> some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: page.systemImage)
                .font(.system(size: 70))
                .foregroundColor(.orange)

            Text(page.title)
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            Text(page.message)
                .font(.system(size: 16))
                .foregroundColor(Color(red: 0.56, green: 0.56, blue: 0.58))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
            Spacer()
        }
    }
}

private struct OnboardingPage {
    let systemImage: String
    let title: String
    let message: String
}

#Preview {
    OnboardingView()
}
