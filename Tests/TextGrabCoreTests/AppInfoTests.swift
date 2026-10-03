import Foundation
import Testing

@testable import TextGrabCore

/// The repo root, found from this file's path (Tests/TextGrabCoreTests/AppInfoTests.swift).
private let repoRoot = URL(filePath: #filePath)
  .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

@Test func bundleIdentifierMatchesInfoPlist() throws {
  let data = try Data(contentsOf: repoRoot.appending(path: "Resources/Info.plist"))
  let plist = try #require(
    try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
  #expect(plist["CFBundleIdentifier"] as? String == AppInfo.bundleIdentifier)
}

/// install.sh uses the bundle ID to remove settings and permissions on uninstall.
@Test func bundleIdentifierMatchesInstallScript() throws {
  let script = try String(contentsOf: repoRoot.appending(path: "install.sh"), encoding: .utf8)
  let line = try #require(
    script.split(separator: "\n").first { $0.hasPrefix("BUNDLE_ID=") })
  #expect(line == "BUNDLE_ID=\"\(AppInfo.bundleIdentifier)\"")
}
