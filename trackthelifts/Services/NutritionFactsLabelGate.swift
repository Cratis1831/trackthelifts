//
//  NutritionFactsLabelGate.swift
//  TrackTheLifts
//

import Foundation
import UIKit
import Vision

enum NutritionFactsLabelGate {
    static let missingLabelMessage =
        "This doesn’t look like a Nutrition Facts label. Align the panel in the box — not the food or the front of the package."

    static func looksLikeNutritionFacts(_ lines: [String]) -> Bool {
        let blob = normalized(lines.joined(separator: " "))
        guard !blob.isEmpty else { return false }

        let hasHeading = headingTokens.contains { blob.contains($0) }
        guard hasHeading else { return false }

        let markerHits = markerTokens.reduce(into: 0) { count, token in
            if blob.contains(token) { count += 1 }
        }
        return markerHits >= 2
    }

    static func recognizedLines(in image: UIImage) async throws -> [String] {
        guard let cgImage = image.cgImage else { return [] }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["en-US", "en-CA", "fr-CA"]

        let handler = VNImageRequestHandler(
            cgImage: cgImage,
            orientation: .init(image.imageOrientation),
            options: [:]
        )
        try handler.perform([request])
        return request.results?.compactMap { $0.topCandidates(1).first?.string } ?? []
    }

    static func preparedJPEG(_ image: UIImage, maxSide: CGFloat = 1280, quality: CGFloat = 0.55) -> Data? {
        let scaled = image.scaledToMaxSide(maxSide)
        return scaled.jpegData(compressionQuality: quality)
    }

    private static let headingTokens = [
        "nutrition facts",
        "nutritionfacts",
        "valeur nutritive",
        "faits nutritionnels",
        "nutrition information"
    ]

    private static let markerTokens = [
        "calories",
        "serving size",
        "serving",
        "portion",
        "daily value",
        "valeur quotidienne",
        "% dv",
        "protein",
        "proteines",
        "carbohydrate",
        "glucides",
        "total fat",
        "lipides"
    ]

    private static func normalized(_ value: String) -> String {
        value
            .folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
            .replacingOccurrences(of: "\n", with: " ")
    }
}

private extension UIImage {
    func scaledToMaxSide(_ maxSide: CGFloat) -> UIImage {
        let longest = max(size.width, size.height)
        guard longest > maxSide, longest > 0 else { return self }
        let scale = maxSide / longest
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: target)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
    }
}

private extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
