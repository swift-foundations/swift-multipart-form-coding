// swift-tools-version: 6.3.1

import PackageDescription

extension String {
    static let multipartFormCoding: Self = "MultipartFormCoding"
}

extension String { var tests: Self { self + " Tests" } }

extension Target.Dependency {
    static var multipartFormCoding: Self { .target(name: .multipartFormCoding) }
    static var rfc2045: Self { .product(name: "RFC 2045", package: "swift-rfc-2045") }
    static var rfc2046: Self { .product(name: "RFC 2046", package: "swift-rfc-2046") }
    static var rfc2183: Self { .product(name: "RFC 2183", package: "swift-rfc-2183") }
    static var rfc7578: Self { .product(name: "RFC 7578", package: "swift-rfc-7578") }
    static var whatwgHTMLForms: Self { .product(name: "WHATWG HTML Forms", package: "swift-whatwg-html") }
    static var whatwgHTMLFormData: Self { .product(name: "WHATWG HTML FormData", package: "swift-whatwg-html") }
}

let package = Package(
    name: "swift-multipart-form-coding",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
        .tvOS(.v26),
        .watchOS(.v26)
    ],
    products: [
        .library(name: .multipartFormCoding, targets: [.multipartFormCoding])
    ],
    dependencies: [
        .package(url: "https://github.com/swift-ietf/swift-rfc-2045.git", branch: "main"),
        .package(url: "https://github.com/swift-ietf/swift-rfc-2046.git", branch: "main"),
        .package(url: "https://github.com/swift-ietf/swift-rfc-2183.git", branch: "main"),
        .package(url: "https://github.com/swift-ietf/swift-rfc-7578.git", branch: "main"),
        .package(url: "https://github.com/swift-whatwg/swift-whatwg-html.git", branch: "main")
    ],
    targets: [
        .target(
            name: .multipartFormCoding,
            dependencies: [
                .rfc2045,
                .rfc2046,
                .rfc2183,
                .rfc7578,
                .whatwgHTMLForms,
                .whatwgHTMLFormData
            ]
        ),
        .testTarget(
            name: .multipartFormCoding.tests,
            dependencies: [
                .multipartFormCoding
            ]
        )
    ]
)

for target in package.targets {
    target.swiftSettings?.append(
        contentsOf: [
            .enableUpcomingFeature("MemberImportVisibility")
        ]
    )
}
