//
//  SoundEffects.swift
//  TrackTheLifts
//

import AudioToolbox

/// Short system sound effects. Uses `AudioServicesPlaySystemSound` (no bundled assets, no
/// AVAudioSession takeover, so it won't interrupt the user's music).
enum SoundEffects {
    /// A brief chime played when the rest timer finishes.
    static func restTimerChime() {
        AudioServicesPlaySystemSound(1005)
    }
}
