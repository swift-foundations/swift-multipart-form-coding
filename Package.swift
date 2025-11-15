// swift-tools-version:6.1

import PackageDescription

extension String {
    static let multipartFormCoding: Self = "MultipartFormCoding"
}

extension String { var tests: Self { self + " Tests" } }

extension Target.Dependency {
    static var multipartFormCoding: Self { .target(name: .multipartFormCoding) }
    static var rfc2045: Self { .product(name: "RFC 2045", package: "swift-rfc-2045") }
    static var rfc2046: Self { .product(name: "RFC 2046", package: "swift-rfc-2046") }
    static var rfc7578: Self { .product(name: "RFC 7578", package: "swift-rfc-7578") }
}

let package = Package(
    name: "swift-multipart-form-coding",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
        .tvOS(.v17),
        .watchOS(.v10)
    ],
    products: [
        .library(name: .multipartFormCoding, targets: [.multipartFormCoding])
    ],
    dependencies: [
        .package(url: "https://github.com/swift-standards/swift-rfc-2045.git", from: "0.1.0"),
        .package(url: "https://github.com/swift-standards/swift-rfc-2046.git", from: "0.2.0"),
        .package(url: "https://github.com/swift-standards/swift-rfc-7578.git", from: "0.2.2")
    ],
    targets: [
        .target(
            name: .multipartFormCoding,
            dependencies: [
                .rfc2045,
                .rfc2046,
                .rfc7578
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
