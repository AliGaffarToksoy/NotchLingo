// swift-tools-version: 5.9
import PackageDescription
import Foundation

// Opt-in core-only tests for machines without Xcode's SwiftData macro plug-in.
// The default always builds the complete app and runs persistence tests too.
let coreOnly = ProcessInfo.processInfo.environment["NOTCHLINGO_CORE_ONLY"] == "1"
var products: [Product] = [.library(name: "NotchLingoCore", targets: ["NotchLingoCore"]),
                           .executable(name: "NotchLingoValidate", targets: ["NotchLingoValidate"])]
var targets: [Target] = [
    .target(name: "NotchLingoCore", path: ".",
            exclude: ["Sources/NotchLingoValidate", "Sources/NotchLingoApp", "Sources/NotchLingoStorage", "Tests", "Schema", "docs",
                      "Scripts", "README.md", "LICENSE", "CONTRIBUTING.md", "ROADMAP.md"],
            sources: ["Sources/NotchLingoCore"], resources: [.copy("Decks")]),
    .executableTarget(name: "NotchLingoValidate", dependencies: ["NotchLingoCore"]),
    .testTarget(name: "NotchLingoCoreTests", dependencies: ["NotchLingoCore"])
]
if !coreOnly {
    products.append(.executable(name: "NotchLingo", targets: ["NotchLingoApp"]))
    targets += [
        .target(name: "NotchLingoStorage", dependencies: ["NotchLingoCore"]),
        .executableTarget(name: "NotchLingoApp", dependencies: ["NotchLingoCore", "NotchLingoStorage"]),
        .testTarget(name: "NotchLingoStorageTests", dependencies: ["NotchLingoCore", "NotchLingoStorage"])
    ]
}
let package = Package(name: "NotchLingo", platforms: [.macOS(.v14)], products: products, targets: targets)
