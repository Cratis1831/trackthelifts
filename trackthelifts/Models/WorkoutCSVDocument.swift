//
//  WorkoutCSVDocument.swift
//  TrackTheLifts
//

import CoreTransferable
import Foundation
import UniformTypeIdentifiers

/// Wraps generated CSV text so it can be handed to `ShareLink`, which turns it into a real file
/// for the recipient app (Mail, AirDrop, Files, etc.) to consume.
struct WorkoutCSVDocument: Transferable {
    let text: String

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .commaSeparatedText) { document in
            Data(document.text.utf8)
        }
    }
}
