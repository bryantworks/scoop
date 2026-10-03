// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "TextGrab",
  platforms: [.macOS(.v14)],
  products: [
    .executable(name: "TextGrab", targets: ["TextGrab"])
  ],
  dependencies: [
    .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "3.1.0")
  ],
  targets: [
    .target(name: "TextGrabCore"),
    .executableTarget(
      name: "TextGrab",
      dependencies: [
        "TextGrabCore",
        .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
      ]
    ),
    // Draws the app icon at build time (scripts/bundle.sh); not shipped in the app.
    .executableTarget(name: "make-app-icon", dependencies: ["TextGrabCore"]),
    .testTarget(name: "TextGrabCoreTests", dependencies: ["TextGrabCore"]),
  ]
)
