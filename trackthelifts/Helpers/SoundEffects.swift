//
//  SoundEffects.swift
//  TrackTheLifts
//

import AudioToolbox
import Foundation

/// Short sound effects played via `AudioServicesPlaySystemSound` (no AVAudioSession takeover, so
/// it won't interrupt the user's music). This only plays while the app is active/foreground — for
/// the app-minimized case, `RestTimerManager` schedules a local notification that carries the same
/// bundled chime (`SoundEffects.restTimerSoundName`) so the sound matches in both states.
enum SoundEffects {
    /// The bundled rest-timer chime, referenced by both the in-app player and the completion
    /// notification so they sound identical.
    static let restTimerSoundName = "RestTimerChime.caf"

    /// Registered once from the bundled `.caf`. Falls back to a system sound if the file is missing.
    private static let restTimerSoundID: SystemSoundID = {
        guard let url = Bundle.main.url(forResource: "RestTimerChime", withExtension: "caf") else {
            return 1005
        }
        var soundID: SystemSoundID = 0
        AudioServicesCreateSystemSoundID(url as CFURL, &soundID)
        return soundID
    }()

    /// Plays the rest-timer chime, used when the timer finishes while the app is in the foreground.
    static func restTimerChime() {
        AudioServicesPlaySystemSound(restTimerSoundID)
    }
}
