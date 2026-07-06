//
//  Haptics.swift
//  TrackTheLifts
//

import UIKit

/// Thin imperative wrapper over UIKit's feedback generators, so call sites inside action
/// functions can fire haptics with one line. Convention: fire after an action succeeds
/// (post-save), not on button-down, so the feedback reflects reality.
enum Haptics {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    /// Strongest feedback UIKit exposes: a full-intensity heavy impact stacked with the
    /// notification generator's success buzz. Used for the rest-timer-complete alert, which
    /// needs to be noticeable even if the phone isn't in hand. Only fires while the app is
    /// active — UIKit feedback generators are no-ops when the app is backgrounded.
    static func restTimerComplete() {
        let impact = UIImpactFeedbackGenerator(style: .heavy)
        impact.prepare()
        impact.impactOccurred(intensity: 1.0)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
