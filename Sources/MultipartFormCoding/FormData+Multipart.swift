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
import RFC_2183
import RFC_7578

// MARK: - Default Boundary Generation

/// Generates a unique multipart/form-data boundary.
///
/// RFC 2046 (§5.1.1) no longer ships a random-boundary generator on
/// `RFC_2046.Boundary`; the default boundary is now produced consumer-side.
/// The `"----FormBoundary" + UUID` form is boundary-grammar-valid by
/// construction (ASCII prefix + hex/hyphen UUID, 52 chars ≤ 70), so it is
/// built via the pre-validated `__unchecked` initializer.
private func generateFormBoundary() -> RFC_2046.Boundary {
    RFC_2046.Boundary(__unchecked: (), rawValue: "----FormBoundary\(UUID().uuidString)")
}

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
            // Use typed Content-Disposition header
            guard let disposition = part.headers.contentDisposition,
                  disposition.type == .formData else {
                continue
            }

            // Extract field name from Content-Disposition
            guard let fieldName = disposition.name else {
                continue
            }

            // Check if this part has a filename (indicating a file upload)
            if let filename = disposition.filename {
                let contentType = part.headers.contentType?.headerValue ?? "application/octet-stream"

                self.append(
                    name: fieldName,
                    file: Form.Data.File(
                        name: filename.value,
                        type: contentType,
                        body: part.content.rawValue.map(\.underlying)
                    )
                )
            } else {
                // Text field - parse content as string
                if let stringValue = String(bytes: part.content.rawValue.map(\.underlying), encoding: .utf8) {
                    self.append(name: fieldName, value: stringValue)
                }
            }
        }
    }

    /// Parses the field name from a Content-Disposition header.
    ///
    /// - Parameter disposition: The Content-Disposition header value
    /// - Returns: The field name, or nil if parsing fails
    ///
    /// - Deprecated: Use `RFC_2183.ContentDisposition(_:).name` instead
    @available(*, deprecated, message: "Use RFC_2183.ContentDisposition(_:).name instead")
    private static func parseFieldName(from disposition: String) -> String? {
        (try? RFC_2183.ContentDisposition(disposition))?.name
    }

    /// Parses the filename from a Content-Disposition header.
    ///
    /// - Parameter disposition: The Content-Disposition header value
    /// - Returns: The filename, or nil if not present
    ///
    /// - Deprecated: Use `RFC_2183.ContentDisposition(_:).filename` instead
    @available(*, deprecated, message: "Use RFC_2183.ContentDisposition(_:).filename instead")
    private static func parseFilename(from disposition: String) -> String? {
        (try? RFC_2183.ContentDisposition(disposition))?.filename?.value
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
    ///   - boundary: Optional custom boundary. If nil, generates a secure random boundary
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
    public init(_ formData: Form.Data.Entry.List, boundary: RFC_2046.Boundary? = nil) throws {
        // Create body parts manually to preserve multiple values for same field name
        var parts: [RFC_2046.BodyPart] = []

        for entry in formData {
            switch entry.value {
            case .string(let value):
                // Create text field part using typed Headers
                var headers = RFC_2046.BodyPart.Headers()
                headers.contentDisposition = RFC_2183.ContentDisposition.formData(name: entry.name)
                headers.contentType = .textPlainUTF8
                parts.append(RFC_2046.BodyPart(
                    headers: headers,
                    content: RFC_2046.BodyPart.Content(value)
                ))

            case .file(let file):
                // Create file upload part using typed Headers
                var headers = RFC_2046.BodyPart.Headers()
                headers.contentDisposition = RFC_2183.ContentDisposition.formData(
                    name: entry.name,
                    filename: try? RFC_2183.Filename(file.name)
                )
                headers.contentType = !file.type.isEmpty
                    ? try? RFC_2045.ContentType(file.type)
                    : nil
                parts.append(RFC_2046.BodyPart(
                    headers: headers,
                    content: RFC_2046.BodyPart.Content(file.body.map { Byte($0) })
                ))
            }
        }

        // Create multipart with all parts
        self = try RFC_2046.Multipart(
            subtype: .formData,
            parts: parts,
            boundary: boundary ?? generateFormBoundary()
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
    public func multipartContentType(boundary: RFC_2046.Boundary? = nil) -> (contentType: RFC_2045.ContentType, boundary: RFC_2046.Boundary) {
        let actualBoundary = boundary ?? generateFormBoundary()
        return (
            contentType: RFC_2045.ContentType(
                __unchecked: (),
                type: "multipart",
                subtype: "form-data",
                parameters: [.boundary: actualBoundary.rawValue]
            ),
            boundary: actualBoundary
        )
    }
}
