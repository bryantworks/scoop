import Testing

@testable import TextGrabCore

@Test func bundleIdentifierMatchesInfoPlist() {
  #expect(AppInfo.bundleIdentifier == "com.bryantworks.textgrab")
}
