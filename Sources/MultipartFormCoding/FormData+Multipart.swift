// ===----------------------------------------------------------------------===//
//
// Copyright (c) 2025 Coen ten Thije Boonkkamp
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of project contributors
//
// SPDX-License-Identifier: Apache-2.0
//
// ===----------------------------------------------------------------------===//

import Foundation
import WHATWG_HTML_Forms
import WHATWG_HTML_FormData
import RFC_2045
import RFC_2046
import RFC_7578

// MARK: - Multipart → Form.Data.Entry.List

extension Form.Data.Entry.List {
    /// Creates a Form.Data.Entry.List by decoding multipart/form-data.
    ///
    /// This initializer parses multipart/form-data formatted data (RFC 7578)
    /// and converts it into the WHATWG HTML Form.Data model. It extracts both
    /// text fields and file uploads from the multipart parts.
    ///
    /// - Parameters:
    ///   - multipart: The parsed multipart data
    ///
    /// - Throws: Conversion errors if multipart data is malformed
    ///
    /// ## Example
    ///
    /// ```swift
    /// let multipart = try RFC_2046.Multipart.parse(data, boundary: boundary)
    /// let formData = try Form.Data.Entry.List(multipart)
    ///
    /// // Access the parsed data
    /// let username = formData.first(named: "username")?.stringValue
    /// let avatar = formData.first(named: "avatar")?.fileValue
    /// ```
    public init(_ multipart: RFC_2046.Multipart) throws {
        self.init()

        // Parse all parts directly to preserve multiple values for same field name
        for part in multipart.parts {
            // Parse Content-Disposition header
            guard let disposition = part.headers["Content-Disposition"],
                  disposition.contains("form-data") else {
                continue
            }

            // Extract field name
            guard let fieldName = Self.parseFieldName(from: disposition) else {
                continue
            }

            // Check if this part has a filename (indicating a file upload)
            if let filename = Self.parseFilename(from: disposition) {
                let contentType = part.headers["Content-Type"] ?? "application/octet-stream"

                self.append(
                    name: fieldName,
                    file: Form.Data.File(
                        name: filename,
                        type: contentType,
                        body: part.content
                    )
                )
            } else {
                // Text field - parse content as string
                if let stringValue = String(data: part.content, encoding: .utf8) {
                    self.append(name: fieldName, value: stringValue)
                }
            }
        }
    }

    /// Parses the field name from a Content-Disposition header.
    ///
    /// Extracts the value from: `name="fieldname"`
    ///
    /// - Parameter disposition: The Content-Disposition header value
    /// - Returns: The field name, or nil if parsing fails
    private static func parseFieldName(from disposition: String) -> String? {
        let pattern = #"name=\"([^\"]+)\""#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(
                in: disposition,
                range: NSRange(disposition.startIndex..., in: disposition)
              ),
              let range = Range(match.range(at: 1), in: disposition) else {
            return nil
        }
        return String(disposition[range])
    }

    /// Parses the filename from a Content-Disposition header.
    ///
    /// Extracts the value from: `filename="file.txt"`
    ///
    /// - Parameter disposition: The Content-Disposition header value
    /// - Returns: The filename, or nil if not present
    private static func parseFilename(from disposition: String) -> String? {
        let pattern = #"filename=\"([^\"]+)\""#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(
                in: disposition,
                range: NSRange(disposition.startIndex..., in: disposition)
              ),
              let range = Range(match.range(at: 1), in: disposition) else {
            return nil
        }
        return String(disposition[range])
    }
}

// MARK: - Form.Data.Entry.List → Multipart

extension RFC_2046.Multipart {
    /// Creates multipart/form-data from a Form.Data.Entry.List.
    ///
    /// This initializer encodes a WHATWG HTML Form.Data model into
    /// multipart/form-data format (RFC 7578) suitable for HTTP transmission.
    /// It automatically separates text fields from file uploads and applies
    /// the appropriate encoding for each.
    ///
    /// - Parameters:
    ///   - formData: The form data to encode
    ///   - boundary: Optional custom boundary string. If nil, generates a secure random boundary
    ///
    /// - Throws: Encoding errors if form data cannot be converted
    ///
    /// ## Example
    ///
    /// ```swift
    /// var formData = Form.Data.Entry.List()
    /// formData.append(name: "username", value: "alice")
    /// formData.append(
    ///     name: "avatar",
    ///     file: Form.Data.File(
    ///         name: "photo.jpg",
    ///         type: "image/jpeg",
    ///         body: imageData
    ///     )
    /// )
    ///
    /// let multipart = try RFC_2046.Multipart(formData, boundary: nil)
    /// let data = try multipart.encode()
    /// ```
    public init(_ formData: Form.Data.Entry.List, boundary: String? = nil) throws {
        // Create body parts manually to preserve multiple values for same field name
        var parts: [RFC_2046.BodyPart] = []

        for entry in formData {
            switch entry.value {
            case .string(let value):
                // Create text field part
                let headers = [
                    "Content-Disposition": "form-data; name=\"\(entry.name)\""
                ]
                let content = Data(value.utf8)
                parts.append(RFC_2046.BodyPart(headers: headers, content: content))

            case .file(let file):
                // Create file upload part
                var headers = [
                    "Content-Disposition": "form-data; name=\"\(entry.name)\"; filename=\"\(file.name)\""
                ]
                if !file.type.isEmpty {
                    headers["Content-Type"] = file.type
                }
                parts.append(RFC_2046.BodyPart(headers: headers, content: file.body))
            }
        }

        // Create multipart with all parts
        self = try RFC_2046.Multipart(
            subtype: .formData,
            parts: parts,
            boundary: boundary
        )
    }
}

// MARK: - Content-Type Header Generation

extension Form.Data.Entry.List {
    /// Generates a Content-Type header value for multipart/form-data encoding.
    ///
    /// Returns a properly typed RFC 2045 Content-Type including a unique
    /// boundary parameter. If no custom boundary is provided, a cryptographically
    /// secure random boundary is generated.
    ///
    /// - Parameter boundary: Optional custom boundary string
    /// - Returns: A tuple containing the RFC 2045 Content-Type and the boundary used
    ///
    /// ## Example
    ///
    /// ```swift
    /// let formData = Form.Data.Entry.List()
    /// let (contentType, boundary) = formData.multipartContentType()
    ///
    /// // Use in HTTP request
    /// request.setValue(contentType.headerValue, forHTTPHeaderField: "Content-Type")
    /// // contentType.headerValue = "multipart/form-data; boundary=----WebKitFormBoundary..."
    /// ```
    public func multipartContentType(boundary: String? = nil) -> (contentType: RFC_2045.ContentType, boundary: String) {
        let actualBoundary = boundary ?? RFC_2046.Multipart.generateBoundary()
        return (
            contentType: RFC_2045.ContentType(
                type: "multipart",
                subtype: "form-data",
                parameters: ["boundary": actualBoundary]
            ),
            boundary: actualBoundary
        )
    }
}
