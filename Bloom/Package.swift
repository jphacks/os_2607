// swift-tools-version: 6.0
import PackageDescription
import Foundation

let package = Package(
    name: "BloomBackend",
    platforms: [.macOS(.v13), .iOS(.v17)],
    products: [.library(name: "BloomBackend", targets: ["BloomBackend"])],
    dependencies: [.package(url: "https://github.com/supabase/supabase-swift.git", exact: "2.49.0")],
    targets: [
        .target(name: "BloomBackend", dependencies: [.product(name: "Supabase", package: "supabase-swift")],
                path: "Bloom/backend", exclude: ["Database", "README.md", "Config/Supabase.xcconfig", "Config/Info.plist"] +
                    (FileManager.default.fileExists(atPath: "Bloom/backend/Config/Supabase.local.xcconfig") ? ["Config/Supabase.local.xcconfig"] : [])),
        .testTarget(name: "BloomBackendTests", dependencies: ["BloomBackend"], path: "Tests/BloomBackendTests")
    ],
    swiftLanguageModes: [.v5]
)
