// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NoteMark",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "NoteMark", targets: ["NoteMark"])],
    targets: [
        .target(name: "NoteMarkCore"),
        .executableTarget(name: "NoteMark", dependencies: ["NoteMarkCore"]),
        .testTarget(name: "NoteMarkCoreTests", dependencies: ["NoteMarkCore"])
    ],
    swiftLanguageModes: [.v5]
)
