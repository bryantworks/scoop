import os

/// App-wide constants shared by the library and the app shell.
public enum AppInfo {
  public static let bundleIdentifier = "com.bryantworks.textgrab"

  public static func logger(_ category: String) -> Logger {
    Logger(subsystem: bundleIdentifier, category: category)
  }
}
