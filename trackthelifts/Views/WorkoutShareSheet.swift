//
//  WorkoutShareSheet.swift
//  TrackTheLifts
//

import Photos
import SwiftData
import SwiftUI

/// Previews the story-format workout card and hands the rendered 1080×1920 image to the system
/// share sheet (Instagram, TikTok, Messages…) or saves it straight to Photos.
struct WorkoutShareSheet: View {
    let summary: WorkoutShareSummary
    let source: ShareCardAnalyticsSource

    @Environment(\.dismiss) private var dismiss
    @State private var style: WorkoutShareCardStyle = .midnight
    @State private var renderedImage: UIImage?
    @State private var saveState: SaveState = .idle

    private enum SaveState: Equatable {
        case idle
        case saving
        case saved
        case failed(String)
    }

    private var theme: AppTheme { ThemePreference.shared.theme }

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                GeometryReader { proxy in
                    let size = WorkoutShareCardView.canvasSize
                    let scale = min(proxy.size.width / size.width, proxy.size.height / size.height)
                    WorkoutShareCardView(summary: summary, style: style, theme: theme)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .strokeBorder(Color.appBorder, lineWidth: 1)
                        }
                        .scaleEffect(scale)
                        .frame(width: size.width * scale, height: size.height * scale)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .shadow(color: .black.opacity(0.5), radius: 24, y: 12)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Workout share card preview")
                }

                Picker("Card style", selection: $style) {
                    ForEach(WorkoutShareCardStyle.allCases) { style in
                        Text(style.displayName).tag(style)
                    }
                }
                .pickerStyle(.segmented)

                HStack(spacing: 10) {
                    Button {
                        Task { await saveToPhotos() }
                    } label: {
                        Label(saveButtonTitle, systemImage: saveState == .saved ? "checkmark" : "arrow.down.to.line")
                    }
                    .buttonStyle(AppSecondaryButtonStyle())
                    .disabled(renderedImage == nil || saveState == .saving)

                    if let renderedImage {
                        ShareLink(
                            item: Image(uiImage: renderedImage),
                            preview: SharePreview(summary.workoutName, image: Image(uiImage: renderedImage))
                        ) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(AppPrimaryButtonStyle())
                    } else {
                        Button {} label: {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(AppPrimaryButtonStyle())
                        .disabled(true)
                    }
                }

                if case .failed(let message) = saveState {
                    Text(message)
                        .font(.appCaption)
                        .foregroundStyle(Color.appTextSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
            .background(Color.appCanvas.ignoresSafeArea())
            .navigationTitle("Share Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(Color.appTextPrimary)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            render()
            AnalyticsService.track(.shareCardOpened(
                source: source,
                hasPersonalRecord: !summary.personalRecords.isEmpty
            ))
        }
        .onChange(of: style) {
            Haptics.selection()
            saveState = .idle
            render()
        }
    }

    private var saveButtonTitle: String {
        switch saveState {
        case .saving: return "Saving…"
        case .saved: return "Saved"
        case .idle, .failed: return "Save"
        }
    }

    @MainActor
    private func render() {
        let renderer = ImageRenderer(content: WorkoutShareCardView(summary: summary, style: style, theme: theme))
        renderer.scale = WorkoutShareCardView.exportScale
        renderer.isOpaque = true
        renderedImage = renderer.uiImage
    }

    @MainActor
    private func saveToPhotos() async {
        guard let image = renderedImage else { return }
        saveState = .saving

        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            Haptics.error()
            saveState = .failed("Allow ForgeLyte Lift to add photos in Settings to save your card.")
            return
        }

        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }
            Haptics.success()
            saveState = .saved
            AnalyticsService.track(.shareCardSaved(style: style.rawValue))
        } catch {
            print("Failed to save share card: \(error)")
            Haptics.error()
            saveState = .failed("Your card couldn't be saved. Please try again.")
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Workout.self, Exercise.self, Bodypart.self, ExerciseSet.self,
        configurations: config
    )

    let exercise = Exercise(name: "Bench Press")
    let workout = Workout(title: "Push Day", date: .now, completedAt: .now, createdAt: .now.addingTimeInterval(-3_900))
    container.mainContext.insert(exercise)
    container.mainContext.insert(workout)
    for order in 0..<3 {
        let set = ExerciseSet(weight: 225, reps: 5, order: order, exercise: exercise, workout: workout, isCompleted: true)
        container.mainContext.insert(set)
        workout.exerciseSets.append(set)
    }

    return WorkoutShareSheet(
        summary: WorkoutShareSummary(
            workout: workout,
            personalRecords: [
                WorkoutPersonalRecord(exerciseName: "Bench Press", kind: .weight, performance: LiftPerformance(weight: 225, reps: 5)),
            ],
            unitLabel: "lb"
        ),
        source: .completion
    )
}
