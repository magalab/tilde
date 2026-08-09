// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Tilde",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v15),
    ],
    products: [
        .executable(name: "Tilde", targets: ["TildeApp"]),
        .executable(name: "tilde-cli", targets: ["TildeCLI"]),
        .executable(name: "TildeBenchmark", targets: ["TildeBenchmark"]),
        .library(name: "TildeCore", targets: ["TildeCore"]),
        .library(name: "TildeDocument", targets: ["TildeDocument"]),
        .library(name: "TildeEditor", targets: ["TildeEditor"]),
        .library(name: "TildeMarkdown", targets: ["TildeMarkdown"]),
        .library(name: "TildeQuickLook", targets: ["TildeQuickLook"]),
        .library(name: "TildeApplication", targets: ["TildeApplication"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/gonzalezreal/textual.git",
            revision: "01b51875a5406eefc95f52a058cb059e7bc94dc4"
        ),
        .package(
            url: "https://github.com/swiftlang/swift-markdown.git",
            revision: "27b7fc1a19068bcea3d2072db0ce86360d1400ed"
        ),
    ],
    targets: [
        .target(
            name: "TildeCore",
            resources: [.process("Resources")]
        ),
        .target(
            name: "TildeDocument",
            dependencies: ["TildeCore"]
        ),
        .target(
            name: "TildeEditor",
            dependencies: ["TildeCore", "TildeDocument"]
        ),
        .target(
            name: "TildeMarkdown",
            dependencies: [
                "TildeCore",
                "TildeDocument",
                .product(name: "Textual", package: "textual"),
            ]
        ),
        .target(
            name: "TildeQuickLook",
            dependencies: [
                "TildeCore",
                .product(name: "Markdown", package: "swift-markdown"),
            ]
        ),
        .target(
            name: "TildeApplication",
            dependencies: [
                "TildeCore",
                "TildeDocument",
                "TildeEditor",
                "TildeMarkdown",
            ]
        ),
        .executableTarget(
            name: "TildeApp",
            dependencies: ["TildeApplication"]
        ),
        .executableTarget(
            name: "TildeCLI",
            dependencies: ["TildeCore"]
        ),
        .executableTarget(
            name: "TildeBenchmark",
            dependencies: [
                "TildeCore",
                "TildeDocument",
                "TildeMarkdown",
                "TildeQuickLook",
            ]
        ),
        .testTarget(
            name: "TildeCoreTests",
            dependencies: ["TildeCore"]
        ),
        .testTarget(
            name: "TildeDocumentTests",
            dependencies: ["TildeCore", "TildeDocument"]
        ),
        .testTarget(
            name: "TildeEditorTests",
            dependencies: ["TildeCore", "TildeEditor"]
        ),
        .testTarget(
            name: "TildeMarkdownTests",
            dependencies: ["TildeCore", "TildeDocument", "TildeMarkdown"]
        ),
        .testTarget(
            name: "TildeQuickLookTests",
            dependencies: ["TildeCore", "TildeQuickLook"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
