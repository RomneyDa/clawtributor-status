// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ClawtributorStatus",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "ClawtributorStatus", targets: ["ClawtributorStatus"])
    ],
    targets: [
        .executableTarget(
            name: "ClawtributorStatus",
            path: "Sources/ClawtributorStatus"
        )
    ]
)
