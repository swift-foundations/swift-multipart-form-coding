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

import Testing
import Foundation
@testable import MultipartFormCoding
import WHATWG_HTML_Forms
import WHATWG_HTML_FormData
import RFC_2046
import RFC_7578
import RFC_2045
import RFC_2183

@Suite("Form.Data ↔ Multipart Conversion Tests")
struct FormDataConversionTests {

    @Test("Form.Data.Entry.List to Multipart conversion with text fields")
    func formDataToMultipartTextOnly() throws {
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

    @Test("Form.Data.Entry.List to Multipart conversion with file")
    func formDataToMultipartWithFile() throws {
        // Arrange
        var formData = Form.Data.Entry.List()
        formData.append(name: "username", value: "alice")
        formData.append(
            name: "avatar",
            file: Form.Data.File(
                name: "photo.jpg",
                type: "image/jpeg",
                body: [0xFF, 0xD8, 0xFF, 0xE0] // JPEG magic number
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
            return disposition.contains("name=\"avatar\"") && disposition.contains("filename=\"photo.jpg\"")
        }
        #expect(hasAvatarPart)
    }

    @Test("Multipart to Form.Data.Entry.List conversion with text fields")
    func multipartToFormDataTextOnly() throws {
        // Arrange
        let multipart = try RFC_2046.Multipart.formData(
            fields: [
                "username": "bob",
                "age": "30"
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

    @Test("Multipart to Form.Data.Entry.List conversion with file")
    func multipartToFormDataWithFile() throws {
        // Arrange
        let imageData: [UInt8] = [0xFF, 0xD8, 0xFF, 0xE0] // JPEG magic number
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

    @Test("Round-trip conversion preserves data")
    func roundTripConversion() throws {
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

    @Test("Content-Type header generation")
    func contentTypeGeneration() {
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

    @Test("Custom boundary is preserved")
    func customBoundary() throws {
        // Arrange
        var formData = Form.Data.Entry.List()
        formData.append(name: "test", value: "value")

        let customBoundary = try RFC_2046.Boundary("MyCustomBoundary123")

        // Act
        let multipart = try RFC_2046.Multipart(formData, boundary: customBoundary)

        // Assert
        #expect(multipart.boundary == customBoundary)
    }

    @Test("Empty Form.Data.Entry.List throws error")
    func emptyFormDataThrows() {
        // Arrange
        let emptyFormData = Form.Data.Entry.List()

        // Act & Assert
        #expect(throws: Error.self) {
            _ = try RFC_2046.Multipart(emptyFormData)
        }
    }

    @Test("Multiple values for same field name preserved")
    func multipleValues() throws {
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
