// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "TextGrab",
  platforms: [.macOS(.v14)],
  products: [
    .executable(name: "TextGrab", targets: ["TextGrab"])
  ],
  dependencies: [
    .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.0.0")
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
    .testTarget(name: "TextGrabCoreTests", dependencies: ["TextGrabCore"]),
  ]
)
