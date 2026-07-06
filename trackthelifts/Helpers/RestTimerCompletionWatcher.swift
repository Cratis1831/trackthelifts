//
//  RestTimerCompletionWatcher.swift
//  TrackTheLifts
//

import SwiftUI

/// App-wide watcher that plays the rest-timer completion chime/haptic exactly once, on whatever
/// screen the user is on — but only while the scene is active. When the timer finishes while the
/// app is backgrounded or the phone is locked, the scheduled completion notification is the sole
/// alert; this watcher stays silent so the chime and the notification never double up.
///
/// Living at the app root (rather than on the workout screen's rest-timer banner) means the alert
/// still fires when the user has navigated to another tab, and the strict `scenePhase == .active`
/// gate stops the in-app chime from sounding in the locked state, where the app is only `.inactive`
/// and a screen-local ticker would otherwise fire alongside the notification.
private struct RestTimerCompletionWatcher: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    func body(content: Content) -> some View {
        content
            .onChange(of: scenePhase) { _, newPhase in
                // Record each foreground return so a timer that elapsed while away is recognized as
                // "finished in the background" and doesn't replay the chime once the app is active.
                if newPhase == .active {
                    RestTimerManager.shared.markBecameActive()
                }
            }
            .onReceive(ticker) { _ in
                guard scenePhase == .active else { return }
                if RestTimerManager.shared.consumeForegroundCompletion() {
                    Haptics.restTimerComplete()
                    if TimerSoundPreference.shared.isEnabled {
                        SoundEffects.restTimerChime()
                    }
                    RestTimerManager.shared.clearPendingNotification()
                }
            }
    }
}

extension View {
    /// Installs the app-wide rest-timer completion watcher (see `RestTimerCompletionWatcher`).
    func watchesRestTimerCompletion() -> some View {
        modifier(RestTimerCompletionWatcher())
    }
}
