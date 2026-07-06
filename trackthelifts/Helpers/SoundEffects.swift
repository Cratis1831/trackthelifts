//
//  SoundEffects.swift
//  TrackTheLifts
//

import AudioToolbox

/// Short system sound effects. Uses `AudioServicesPlaySystemSound` (no bundled assets, no
/// AVAudioSession takeover, so it won't interrupt the user's music). This only plays while the
/// app is active/foreground — for the app-minimized case, `RestTimerManager` schedules a local
/// notification instead, which iOS plays a sound for on its own.
enum SoundEffects {
    /// The system alarm tone, played when the rest timer finishes.
    static func restTimerChime() {
        AudioServicesPlaySystemSound(1005)
    }
}
