// Batch-0 parity corpus: FormData/Multipart veneer wire-shape snapshots.
//
// Encodes a representative Form.Data.Entry.List (text fields, repeated field
// names, and a file part with fixed bytes/filename/contentType) with a PINNED
// boundary (the API accepts `boundary:` injection at
// Sources/MultipartFormCoding/FormData+Multipart.swift:156 and :228;
// `generateFormBoundary()` only fires when the boundary is nil, so no
// normalization is required). Snapshots the full body bytes as UTF-8 and the
// Content-Type value the encoder exposes, then parses the body back and
// snapshots the round-trip equality result.
//
// Note: the multipart Bool.Encoder strategies (.trueFalse/.yesNo/.numeric,
// dossier B2-06) live in swift-url-routing's RFC_2046.Multipart.Encoder, not
// in this package's surface; MultipartFormCoding exposes no Bool or array
// strategy axis. See __Corpus__/NOTES.txt.

import Foundation
import MultipartFormCoding
import RFC_2045
import RFC_2046
import Testing
import WHATWG_HTML_FormData
import WHATWG_HTML_Forms

@Suite("Multipart Coder Parity")
struct MultipartCoderParityTests {
    @Test("wire-shape corpus (compare-or-record)")
    func corpus() throws {
        // PINNED boundary: grammar-valid ASCII, well under the 70-char limit.
        let boundary = try RFC_2046.Boundary("----CoderParityBoundary0123456789")

        var formData = Form.Data.Entry.List()
        formData.append(name: "username", value: "alice")
        formData.append(name: "bio", value: "hello world\nsecond line ✓")
        formData.append(name: "tag", value: "swift")
        formData.append(name: "tag", value: "server")
        formData.append(
            name: "notes",
            file: Form.Data.File(
                name: "notes.txt",
                type: "text/plain",
                body: Array("fixed file bytes 0123\n".utf8)
            )
        )

        // Encode: full body bytes with the pinned boundary.
        let multipart = try RFC_2046.Multipart(formData, boundary: boundary)
        let bodyBytes = [Byte](multipart)
        let body = String(decoding: bodyBytes.map(\.underlying), as: UTF8.self)
        try Corpus.compareOrRecord(body, named: "multipart-body")

        // Encode: the Content-Type value the encoder exposes.
        let (contentType, usedBoundary) = formData.multipartContentType(boundary: boundary)
        #expect(usedBoundary.rawValue == boundary.rawValue)
        try Corpus.compareOrRecord(
            contentType.headerValue + "\n",
            named: "multipart-contentType"
        )

        // Decode: parse the body back and compare entry lists.
        var roundtrip: String
        do {
            let parsed = try RFC_2046.Multipart.parse(
                from: bodyBytes,
                parser: .init(boundary: boundary, subtype: .formData)
            )
            let decoded = try Form.Data.Entry.List(parsed)
            if decoded == formData {
                roundtrip = "roundtrip: equal"
            } else {
                roundtrip = "roundtrip: mismatch\ndecoded: \(decoded)"
            }
        } catch {
            roundtrip = "roundtrip: parse-error: \(error)"
        }
        try Corpus.compareOrRecord(roundtrip + "\n", named: "multipart-roundtrip")

        let known =
            roundtrip == "roundtrip: equal"
            ? "none\n"
            : "multipart-body: \(roundtrip)\n"
        try Corpus.compareOrRecord(known, named: "KNOWN-NON-ROUNDTRIP")
    }
}
