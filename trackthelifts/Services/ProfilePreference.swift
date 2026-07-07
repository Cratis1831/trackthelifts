//
//  ProfilePreference.swift
//  TrackTheLifts
//

import SwiftUI

/// The user's profile name and avatar photo, kept entirely on device. The name lives in
/// `UserDefaults`; the avatar is written to a file in the app's Documents directory so the
/// (potentially large) image data never bloats `UserDefaults`. Nothing here leaves the phone.
@Observable
class ProfilePreference {
    static let shared = ProfilePreference()

    @ObservationIgnored
    private let userDefaults = UserDefaults.standard

    @ObservationIgnored
    private let nameKey = "profileName"

    @ObservationIgnored
    private lazy var avatarURL: URL = {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent("profile_avatar.jpg")
    }()

    var name: String {
        didSet {
            userDefaults.set(name, forKey: nameKey)
        }
    }

    /// The avatar image, or `nil` when the user hasn't chosen one yet.
    private(set) var avatarImage: UIImage?

    private init() {
        self.name = userDefaults.string(forKey: nameKey) ?? ""
        if let data = try? Data(contentsOf: avatarURL) {
            self.avatarImage = UIImage(data: data)
        }
    }

    /// The user's initials for the avatar's empty state (up to two uppercase letters, like a
    /// standard avatar). Returns `nil` when no name has been entered.
    var initials: String? {
        let words = name
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
        guard !words.isEmpty else { return nil }

        let letters: [Character]
        if words.count == 1 {
            letters = Array(words[0].prefix(1))
        } else {
            letters = [words.first, words.last]
                .compactMap { $0?.first }
        }

        let result = String(letters).uppercased()
        return result.isEmpty ? nil : result
    }

    /// Persist a newly picked avatar (JPEG-encoded) to disk, or clear it when passed `nil`.
    func setAvatar(_ image: UIImage?) {
        avatarImage = image
        if let image, let data = image.jpegData(compressionQuality: 0.9) {
            try? data.write(to: avatarURL, options: .atomic)
        } else {
            try? FileManager.default.removeItem(at: avatarURL)
        }
    }
}
