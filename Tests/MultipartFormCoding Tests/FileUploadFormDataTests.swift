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

@Suite("FileUpload Form.Data Conversion Tests")
struct FileUploadFormDataTests {

    @Test("Create Form.Data.File from FileUpload with PDF")
    func fileUploadToPDFFile() throws {
        // Arrange
        let upload = try FileUpload(
            fieldName: "document",
            filename: "report.pdf",
            fileType: .pdf
        )

        let pdfData = Data("%PDF-1.4\n".utf8)

        // Act
        let file = try Form.Data.File(upload: upload, data: pdfData)

        // Assert
        #expect(file.name == "report.pdf")
        #expect(file.type == "application/pdf")
        #expect(file.body == pdfData)
    }

    @Test("Create Form.Data.File from FileUpload with CSV")
    func fileUploadToCSVFile() throws {
        // Arrange
        let upload = try FileUpload(
            fieldName: "data",
            filename: "data.csv",
            fileType: .csv
        )

        let csvData = Data("name,age\nalice,30\nbob,25\n".utf8)

        // Act
        let file = try Form.Data.File(upload: upload, data: csvData)

        // Assert
        #expect(file.name == "data.csv")
        #expect(file.type == "text/csv")
        #expect(file.body == csvData)
    }

    @Test("Create Form.Data.File with validation failure throws")
    func fileUploadValidationFailure() throws {
        // Arrange
        let upload = try FileUpload(
            fieldName: "document",
            filename: "report.pdf",
            fileType: .pdf
        )

        // Invalid PDF data (missing magic number)
        let invalidData = Data("Not a PDF".utf8)

        // Act & Assert
        #expect(throws: FileUpload.Error.self) {
            _ = try Form.Data.File(upload: upload, data: invalidData)
        }
    }

    @Test("Create Form.Data.Entry from FileUpload")
    func fileUploadToEntry() throws {
        // Arrange
        let upload = try FileUpload(
            fieldName: "avatar",
            filename: "photo.jpg",
            fileType: .image(.jpeg)
        )

        // JPEG magic number
        let imageData = Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10])

        // Act
        let entry = try Form.Data.Entry(upload: upload, data: imageData)

        // Assert
        #expect(entry.name == "avatar")
        #expect(entry.value.isFile)

        let file = entry.value.fileValue
        #expect(file?.name == "photo.jpg")
        #expect(file?.type == "image/jpeg")
        #expect(file?.body == imageData)
    }

    @Test("FileType.mimeType returns correct value for PDF")
    func fileTypeMimeTypePDF() {
        // Arrange
        let fileType = FileUpload.FileType.pdf

        // Act
        let mimeType = fileType.mimeType

        // Assert
        #expect(mimeType == "application/pdf")
    }

    @Test("FileType.mimeType returns correct value for CSV")
    func fileTypeMimeTypeCSV() {
        // Arrange
        let fileType = FileUpload.FileType.csv

        // Act
        let mimeType = fileType.mimeType

        // Assert
        #expect(mimeType == "text/csv")
    }

    @Test("FileType.mimeType returns correct value for image types")
    func fileTypeMimeTypeImage() {
        // Arrange
        let jpegType = FileUpload.FileType.image(.jpeg)
        let pngType = FileUpload.FileType.image(.png)

        // Act & Assert
        #expect(jpegType.mimeType == "image/jpeg")
        #expect(pngType.mimeType == "image/png")
    }

    @Test("FileUpload size limit validation")
    func fileUploadSizeLimitValidation() throws {
        // Arrange
        let upload = try FileUpload(
            fieldName: "file",
            filename: "small.txt",
            fileType: .text,
            maxSize: 10 // Very small limit
        )

        let tooLargeData = Data("This is definitely more than 10 bytes".utf8)

        // Act & Assert
        #expect(throws: FileUpload.Error.fileTooLarge(size: tooLargeData.count, maxSize: 10)) {
            _ = try Form.Data.File(upload: upload, data: tooLargeData)
        }
    }

    @Test("FileUpload integration with Form.Data.Entry.List")
    func fileUploadEntryListIntegration() throws {
        // Arrange
        let upload = try FileUpload(
            fieldName: "attachment",
            filename: "document.pdf",
            fileType: .pdf,
            maxSize: 1024 * 1024 // 1MB
        )

        let pdfData = Data("%PDF-1.5\nSome content".utf8)

        // Act
        var formData = Form.Data.Entry.List()
        formData.append(name: "title", value: "Important Document")
        formData.append(try Form.Data.Entry(upload: upload, data: pdfData))

        // Assert
        #expect(formData.count == 2)
        #expect(formData.first(named: "title")?.stringValue == "Important Document")

        let attachmentFile = formData.first(named: "attachment")?.fileValue
        #expect(attachmentFile?.name == "document.pdf")
        #expect(attachmentFile?.type == "application/pdf")
    }
}
