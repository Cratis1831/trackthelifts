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
    private let secondaryColor = Color.appTextSecondary

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
                    .foregroundColor(.appTextPrimary)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)

                    Text("\(totalWorkouts.formatted()) \(totalWorkouts == 1 ? "Workout" : "Workouts")")
                        .font(.system(size: 15))
                        .foregroundColor(secondaryColor)
                }

                Spacer(minLength: 0)
            }
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
                .fill(Color.appBorder)

            if let image = profile.avatarImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if let initials = profile.initials {
                Text(initials)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.appTextPrimary)
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
                .foregroundColor(.onAppAccent)
                .padding(6)
                .background(Color.appAccent)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.appCanvas, lineWidth: 2))
        }
    }
}

#Preview {
    ZStack {
        Color.appCanvas.ignoresSafeArea()
        ProfileHeaderView(totalWorkouts: 1500)
            .padding(20)
    }
}
