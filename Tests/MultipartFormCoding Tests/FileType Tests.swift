import Testing
import Foundation
import RFC_2045
@testable import MultipartFormCoding

// Note: FileUpload is now at package level, not under Multipart namespace

@Suite("FileType Document Validation")
struct FileTypeDocumentTests {

    @Test("PDF validates with correct magic number")
    func testValidPDF() throws {
        let upload = try FileUpload(
            fieldName: "document",
            filename: "report.pdf",
            fileType: .pdf
        )

        var validPDF = Data("%PDF-1.4\n".utf8)
        validPDF.append(Data(repeating: 0x00, count: 100))

        try upload.validate(validPDF)
    }

    @Test("PDF rejects invalid magic number")
    func testInvalidPDF() throws {
        let upload = try FileUpload(
            fieldName: "document",
            filename: "report.pdf",
            fileType: .pdf
        )

        let invalidData = Data("Not a PDF".utf8)

        #expect(throws: FileUpload.Error.self) {
            try upload.validate(invalidData)
        }
    }

    @Test("CSV validates with UTF-8 text")
    func testValidCSV() throws {
        let upload = try FileUpload(
            fieldName: "data",
            filename: "data.csv",
            fileType: .csv
        )

        let validCSV = Data("name,email\nJohn,john@example.com".utf8)
        try upload.validate(validCSV)
    }

    @Test("CSV rejects invalid UTF-8")
    func testInvalidCSV() throws {
        let upload = try FileUpload(
            fieldName: "data",
            filename: "data.csv",
            fileType: .csv
        )

        let invalidData = Data([0xFF, 0xFE, 0xFF, 0xFE])

        #expect(throws: FileUpload.Error.self) {
            try upload.validate(invalidData)
        }
    }
}

@Suite("FileType Generic Formats")
struct FileTypeGenericTests {

    @Test("JSON accepts valid JSON")
    func testJSON() throws {
        let upload = try FileUpload(
            fieldName: "config",
            filename: "config.json",
            fileType: .json
        )

        let jsonData = Data("{\"key\": \"value\"}".utf8)
        try upload.validate(jsonData)  // No validation
    }

    @Test("JSON has correct content type")
    func testJSONContentType() throws {
        #expect(FileUpload.FileType.json.contentType.type == "application")
        #expect(FileUpload.FileType.json.contentType.subtype == "json")
    }

    @Test("Text accepts any data")
    func testText() throws {
        let upload = try FileUpload(
            fieldName: "notes",
            filename: "notes.txt",
            fileType: .text
        )

        let textData = Data("Some text content".utf8)
        try upload.validate(textData)
    }

    @Test("Text has correct content type")
    func testTextContentType() throws {
        #expect(FileUpload.FileType.text.contentType.type == "text")
        #expect(FileUpload.FileType.text.contentType.subtype == "plain")
    }

    @Test("Excel has correct content type")
    func testExcelContentType() throws {
        #expect(FileUpload.FileType.excel.contentType.type == "application")
        #expect(FileUpload.FileType.excel.contentType.subtype.contains("spreadsheetml"))
    }

    @Test("Excel has correct file extension")
    func testExcelExtension() throws {
        #expect(FileUpload.FileType.excel.fileExtension == "xlsx")
    }
}

@Suite("FileType Office Documents")
struct FileTypeOfficeTests {

    @Test("DOCX has correct content type")
    func testDOCXContentType() throws {
        #expect(FileUpload.FileType.docx.contentType.type == "application")
        #expect(FileUpload.FileType.docx.contentType.subtype.contains("wordprocessingml"))
    }

    @Test("DOCX has correct file extension")
    func testDOCXExtension() throws {
        #expect(FileUpload.FileType.docx.fileExtension == "docx")
    }

    @Test("DOC has correct content type")
    func testDOCContentType() throws {
        #expect(FileUpload.FileType.doc.contentType.type == "application")
        #expect(FileUpload.FileType.doc.contentType.subtype == "msword")
    }

    @Test("DOC has correct file extension")
    func testDOCExtension() throws {
        #expect(FileUpload.FileType.doc.fileExtension == "doc")
    }
}

@Suite("FileType Archive Formats")
struct FileTypeArchiveTests {

    @Test("ZIP has correct content type")
    func testZIPContentType() throws {
        #expect(FileUpload.FileType.zip.contentType.type == "application")
        #expect(FileUpload.FileType.zip.contentType.subtype == "zip")
    }

    @Test("ZIP has correct file extension")
    func testZIPExtension() throws {
        #expect(FileUpload.FileType.zip.fileExtension == "zip")
    }
}

@Suite("FileType Audio Formats")
struct FileTypeAudioTests {

    @Test("MP3 has correct content type")
    func testMP3ContentType() {
        #expect(FileUpload.FileType.mp3.contentType.type == "audio")
        #expect(FileUpload.FileType.mp3.contentType.subtype == "mpeg")
    }

    @Test("MP3 has correct file extension")
    func testMP3Extension() {
        #expect(FileUpload.FileType.mp3.fileExtension == "mp3")
    }

    @Test("WAV has correct content type")
    func testWAVContentType() throws {
        #expect(FileUpload.FileType.wav.contentType.type == "audio")
        #expect(FileUpload.FileType.wav.contentType.subtype == "wav")
    }

    @Test("WAV has correct file extension")
    func testWAVExtension() throws {
        #expect(FileUpload.FileType.wav.fileExtension == "wav")
    }
}

@Suite("FileType Video Formats")
struct FileTypeVideoTests {

    @Test("MP4 has correct content type")
    func testMP4ContentType() {
        #expect(FileUpload.FileType.mp4.contentType.type == "video")
        #expect(FileUpload.FileType.mp4.contentType.subtype == "mp4")
    }

    @Test("MP4 has correct file extension")
    func testMP4Extension() {
        #expect(FileUpload.FileType.mp4.fileExtension == "mp4")
    }
}

@Suite("FileType Database Formats")
struct FileTypeDatabaseTests {

    @Test("SQLite has correct content type")
    func testSQLiteContentType() throws {
        #expect(FileUpload.FileType.sqlite.contentType.type == "application")
        #expect(FileUpload.FileType.sqlite.contentType.subtype == "x-sqlite3")
    }

    @Test("SQLite has correct file extension")
    func testSQLiteExtension() throws {
        #expect(FileUpload.FileType.sqlite.fileExtension == "sqlite")
    }
}

@Suite("FileType Programming Files")
struct FileTypeProgrammingTests {

    @Test("Swift has correct content type")
    func testSwiftContentType() throws {
        #expect(FileUpload.FileType.swift.contentType.type == "text")
        #expect(FileUpload.FileType.swift.contentType.subtype == "x-swift")
    }

    @Test("Swift has correct file extension")
    func testSwiftExtension() throws {
        #expect(FileUpload.FileType.swift.fileExtension == "swift")
    }

    @Test("JavaScript has correct content type")
    func testJavaScriptContentType() throws {
        #expect(FileUpload.FileType.javascript.contentType.type == "application")
        #expect(FileUpload.FileType.javascript.contentType.subtype == "javascript")
    }

    @Test("JavaScript has correct file extension")
    func testJavaScriptExtension() throws {
        #expect(FileUpload.FileType.javascript.fileExtension == "js")
    }
}

@Suite("FileType Font and Graphics")
struct FileTypeFontGraphicsTests {

    @Test("TTF has correct content type")
    func testTTFContentType() throws {
        #expect(FileUpload.FileType.ttf.contentType.type == "font")
        #expect(FileUpload.FileType.ttf.contentType.subtype == "ttf")
    }

    @Test("TTF has correct file extension")
    func testTTFExtension() throws {
        #expect(FileUpload.FileType.ttf.fileExtension == "ttf")
    }

    @Test("SVG has correct content type")
    func testSVGContentType() throws {
        #expect(FileUpload.FileType.svg.contentType.type == "image")
        #expect(FileUpload.FileType.svg.contentType.subtype == "svg+xml")
    }

    @Test("SVG has correct file extension")
    func testSVGExtension() throws {
        #expect(FileUpload.FileType.svg.fileExtension == "svg")
    }
}

@Suite("FileType Custom Creation")
struct FileTypeCustomTests {

    @Test("Creates custom FileType with validation")
    func testCustomFileTypeWithValidation() throws {
        // Use a simple validation that doesn't require mutation
        let customType = FileUpload.FileType(
            contentType: RFC_2045.ContentType(type: "application", subtype: "custom"),
            fileExtension: "cst"
        ) { data in
            guard !data.isEmpty else {
                throw FileUpload.Error.emptyData
            }
        }

        let upload = try FileUpload(
            fieldName: "custom",
            filename: "test.cst",
            fileType: customType
        )

        let data = Data([0x01, 0x02, 0x03])
        try upload.validate(data)  // Should not throw
    }

    @Test("Creates custom FileType without validation")
    func testCustomFileTypeNoValidation() throws {
        let customType = FileUpload.FileType(
            contentType: RFC_2045.ContentType(type: "application", subtype: "test"),
            fileExtension: "tst"
        )

        let upload = try FileUpload(
            fieldName: "test",
            filename: "test.tst",
            fileType: customType
        )

        let data = Data([0x01, 0x02, 0x03])
        try upload.validate(data)  // Should not throw
    }

    @Test("Custom FileType validation throws custom errors")
    func testCustomFileTypeCustomError() throws {
        let customType = FileUpload.FileType(
            contentType: RFC_2045.ContentType(type: "application", subtype: "strict"),
            fileExtension: "str"
        ) { data in
            if data.count < 10 {
                throw FileUpload.Error.contentMismatch(
                    expected: "at least 10 bytes",
                    detected: "\(data.count) bytes"
                )
            }
        }

        let upload = try FileUpload(
            fieldName: "strict",
            filename: "test.str",
            fileType: customType
        )

        let smallData = Data([0x01, 0x02])

        #expect(throws: FileUpload.Error.self) {
            try upload.validate(smallData)
        }
    }
}

@Suite("FileType Image Factory")
struct FileTypeImageFactoryTests {

    @Test("image() factory creates valid FileType from ImageType")
    func testImageFactory() throws {
        let jpegFileType = FileUpload.FileType.image(.jpeg)

        #expect(jpegFileType.contentType.type == "image")
        #expect(jpegFileType.contentType.subtype == "jpeg")
        #expect(jpegFileType.fileExtension == "jpg")
    }

    @Test("image() factory preserves validation")
    func testImageFactoryValidation() throws {
        let pngFileType = FileUpload.FileType.image(.png)

        let upload = try FileUpload(
            fieldName: "photo",
            filename: "test.png",
            fileType: pngFileType
        )

        var validPNG = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        validPNG.append(Data(repeating: 0x00, count: 100))

        try upload.validate(validPNG)  // Should pass

        let invalidData = Data(repeating: 0x00, count: 8)

        #expect(throws: FileUpload.Error.self) {
            try upload.validate(invalidData)
        }
    }
}
