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
import RFC_2045
import RFC_2046
import RFC_2183
import RFC_7578
import Testing
import WHATWG_HTML_FormData
import WHATWG_HTML_Forms

@testable import MultipartFormCoding

@Suite
struct FormDataConversionTests {

    @Test
    func `Form.Data.Entry.List to Multipart conversion with text fields`() throws {
        // Arrange
        var formData = Form.Data.Entry.List()
        formData.append(name: "username", value: "alice")
        formData.append(name: "email", value: "alice@example.com")

        // Act
        let multipart = try RFC_2046.Multipart(formData)

        // Assert
        #expect(multipart.subtype == .formData)
        #expect(multipart.parts.count >= 2)

        let fields = multipart.extractFormFields()
        #expect(fields["username"] == "alice")
        #expect(fields["email"] == "alice@example.com")
    }

    @Test
    func `Form.Data.Entry.List to Multipart conversion with file`() throws {
        // Arrange
        var formData = Form.Data.Entry.List()
        formData.append(name: "username", value: "alice")
        formData.append(
            name: "avatar",
            file: Form.Data.File(
                name: "photo.jpg",
                type: "image/jpeg",
                body: [0xFF, 0xD8, 0xFF, 0xE0]  // JPEG magic number
            )
        )

        // Act
        let multipart = try RFC_2046.Multipart(formData)

        // Assert
        #expect(multipart.subtype == .formData)
        #expect(multipart.parts.count >= 2)

        // Check text field
        let fields = multipart.extractFormFields()
        #expect(fields["username"] == "alice")

        // Check file field exists in parts
        let hasAvatarPart = multipart.parts.contains { part in
            guard let disposition = part.headers[.contentDisposition] else { return false }
            return disposition.contains("name=\"avatar\"")
                && disposition.contains("filename=\"photo.jpg\"")
        }
        #expect(hasAvatarPart)
    }

    @Test
    func `Multipart to Form.Data.Entry.List conversion with text fields`() throws {
        // Arrange
        let multipart = try RFC_2046.Multipart.formData(
            fields: [
                "username": "bob",
                "age": "30",
            ],
            files: []
        )

        // Act
        let formData = try Form.Data.Entry.List(multipart)

        // Assert
        #expect(formData.count == 2)
        #expect(formData.first(named: "username")?.stringValue == "bob")
        #expect(formData.first(named: "age")?.stringValue == "30")
    }

    @Test
    func `Multipart to Form.Data.Entry.List conversion with file`() throws {
        // Arrange
        let imageData: [UInt8] = [0xFF, 0xD8, 0xFF, 0xE0]  // JPEG magic number
        let file = try RFC_7578.Form.Data.File(
            fieldName: "photo",
            filename: try RFC_2183.Filename("image.jpg"),
            contentType: .imageJPEG,
            content: imageData
        )

        let multipart = try RFC_2046.Multipart.formData(
            fields: ["caption": "My photo"],
            files: [file]
        )

        // Act
        let formData = try Form.Data.Entry.List(multipart)

        // Assert
        #expect(formData.count == 2)

        // Check text field
        #expect(formData.first(named: "caption")?.stringValue == "My photo")

        // Check file field
        let photoFile = formData.first(named: "photo")?.fileValue
        #expect(photoFile != nil)
        #expect(photoFile?.name == "image.jpg")
        #expect(photoFile?.type == "image/jpeg")
        #expect(photoFile?.body == imageData)
    }

    @Test
    func `Round-trip conversion preserves data`() throws {
        // Arrange
        var original = Form.Data.Entry.List()
        original.append(name: "field1", value: "value1")
        original.append(name: "field2", value: "value2")
        original.append(
            name: "file1",
            file: Form.Data.File(
                name: "test.txt",
                type: "text/plain",
                body: Array("Hello, World!".utf8)
            )
        )

        // Act - Convert to multipart and back
        let multipart = try RFC_2046.Multipart(original)
        let restored = try Form.Data.Entry.List(multipart)

        // Assert
        #expect(restored.count == original.count)
        #expect(restored.first(named: "field1")?.stringValue == "value1")
        #expect(restored.first(named: "field2")?.stringValue == "value2")

        let restoredFile = restored.first(named: "file1")?.fileValue
        #expect(restoredFile?.name == "test.txt")
        #expect(restoredFile?.body == Array("Hello, World!".utf8))
    }

    @Test
    func `Content-Type header generation`() {
        // Arrange
        let formData = Form.Data.Entry.List()

        // Act
        let (contentType, boundary) = formData.multipartContentType()

        // Assert
        #expect(contentType.type == "multipart")
        #expect(contentType.subtype == "form-data")
        #expect(contentType.parameters[.boundary] == boundary.rawValue)
        #expect(!boundary.rawValue.isEmpty)
    }

    @Test
    func `Custom boundary is preserved`() throws {
        // Arrange
        var formData = Form.Data.Entry.List()
        formData.append(name: "test", value: "value")

        let customBoundary = try RFC_2046.Boundary("MyCustomBoundary123")

        // Act
        let multipart = try RFC_2046.Multipart(formData, boundary: customBoundary)

        // Assert
        #expect(multipart.boundary == customBoundary)
    }

    @Test
    func `Empty Form.Data.Entry.List throws error`() {
        // Arrange
        let emptyFormData = Form.Data.Entry.List()

        // Act & Assert
        #expect(throws: Error.self) {
            _ = try RFC_2046.Multipart(emptyFormData)
        }
    }

    @Test
    func `Multiple values for same field name preserved`() throws {
        // Arrange
        var formData = Form.Data.Entry.List()
        formData.append(name: "interests", value: "swift")
        formData.append(name: "interests", value: "web")
        formData.append(name: "interests", value: "server")

        // Act
        let multipart = try RFC_2046.Multipart(formData)
        let restored = try Form.Data.Entry.List(multipart)

        // Assert
        let interests = restored.all(named: "interests")
        #expect(interests.count == 3)
        #expect(interests[0].stringValue == "swift")
        #expect(interests[1].stringValue == "web")
        #expect(interests[2].stringValue == "server")
    }
}
