//
//  UIApplication+DismissKeyboard.swift
//  TrackTheLifts
//

import UIKit

/// Lets our tap-to-dismiss gesture coexist with every other gesture/button in the app instead of
/// stealing their touches.
private class KeyboardDismissGestureDelegate: NSObject, UIGestureRecognizerDelegate {
    static let shared = KeyboardDismissGestureDelegate()

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        true
    }

    /// Skip taps that land on another text field/text view, so switching focus directly between
    /// fields (e.g. Weight -> Reps) just moves focus instead of resigning it and having SwiftUI
    /// refocus a moment later — which was causing the keyboard to visibly dismiss and reappear.
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        var view: UIView? = touch.view
        while let current = view {
            if current is UITextField || current is UITextView {
                return false
            }
            view = current.superview
        }
        return true
    }
}

extension UIApplication {
    /// Adds a window-level tap gesture that resigns first responder on tap, so tapping anywhere
    /// outside a text field dismisses the keyboard — even in views that don't otherwise handle it.
    func enableTapToDismissKeyboard() {
        guard let window = connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })
        else { return }

        guard window.gestureRecognizers?.contains(where: { $0.name == "dismissKeyboardTap" }) != true else {
            return
        }

        let tapGesture = UITapGestureRecognizer(target: window, action: #selector(UIView.endEditing))
        tapGesture.name = "dismissKeyboardTap"
        tapGesture.cancelsTouchesInView = false
        tapGesture.delegate = KeyboardDismissGestureDelegate.shared
        window.addGestureRecognizer(tapGesture)
    }
}
