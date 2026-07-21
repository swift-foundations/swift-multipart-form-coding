// Batch-0 parity corpus: tiny local fixture helper (compare-or-record).
//
// Intentionally self-contained so this package does not gain a dependency on
// swift-url-routing's URL Routing Test Support.

import Foundation
import Testing

enum Corpus {
    static let directory = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("__Corpus__")

    /// Compare-or-record: writes the fixture if absent; otherwise byte-compares
    /// and records an issue with a diff-style message on mismatch.
    static func compareOrRecord(
        _ produced: String,
        named name: String,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        let url = directory.appendingPathComponent(name + ".txt")
        let producedData = Data(produced.utf8)
        if FileManager.default.fileExists(atPath: url.path) {
            let expectedData = try Data(contentsOf: url)
            if expectedData != producedData {
                let expected = String(decoding: expectedData, as: UTF8.self)
                Issue.record(
                    """
                    Corpus mismatch for \(name)
                    --- expected ---
                    \(expected)
                    --- actual ---
                    \(produced)
                    """,
                    sourceLocation: sourceLocation
                )
            }
        } else {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            try producedData.write(to: url)
        }
    }
}
