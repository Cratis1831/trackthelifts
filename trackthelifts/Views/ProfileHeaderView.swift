//
//  ProfileHeaderView.swift
//  TrackTheLifts
//

import SwiftUI
import PhotosUI

/// Top-of-profile row: a tappable circular avatar, an editable name field, and the user's total
/// workout count. Tapping the avatar opens the photo library so the user can pick a photo of
/// themselves. Everything here is stored on device via `ProfilePreference`.
struct ProfileHeaderView: View {
    let totalWorkouts: Int

    @State private var profile = ProfilePreference.shared
    @State private var selectedItem: PhotosPickerItem?

    private let avatarSize: CGFloat = 76
    private let secondaryColor = Color(red: 0.56, green: 0.56, blue: 0.58)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                PhotosPicker(selection: $selectedItem, matching: .images, photoLibrary: .shared()) {
                    avatar
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 4) {
                    TextField(
                        "",
                        text: $profile.name,
                        prompt: Text("Your Name").foregroundColor(secondaryColor)
                    )
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)

                    Text("\(totalWorkouts.formatted()) \(totalWorkouts == 1 ? "Workout" : "Workouts")")
                        .font(.system(size: 15))
                        .foregroundColor(secondaryColor)
                }

                Spacer(minLength: 0)
            }

            Text("Your photo and name stay on this device.")
                .font(.system(size: 12))
                .foregroundColor(secondaryColor)
        }
        .onChange(of: selectedItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    profile.setAvatar(image)
                }
            }
        }
    }

    @ViewBuilder
    private var avatar: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.17, green: 0.17, blue: 0.18))

            if let image = profile.avatarImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if let initials = profile.initials {
                Text(initials)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.white)
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: 32))
                    .foregroundColor(secondaryColor)
            }
        }
        .frame(width: avatarSize, height: avatarSize)
        .clipShape(Circle())
        .overlay(
            Circle().stroke(Color.appAccent, lineWidth: 2)
        )
        .overlay(alignment: .bottomTrailing) {
            Image(systemName: "camera.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)
                .padding(6)
                .background(Color.appAccent)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.black, lineWidth: 2))
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        ProfileHeaderView(totalWorkouts: 1500)
            .padding(20)
    }
}
