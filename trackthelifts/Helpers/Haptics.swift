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
}
