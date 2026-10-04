/// Which built-in macOS sound (in /System/Library/Sounds) goes with a capture result.
public enum CaptureSound {
  /// scoop's Settings switch, "Play a sound when text is copied" (on unless turned off).
  public static let enabledKey = "captureSoundEnabled"
  /// Where macOS stores System Settings → Sound → "Play user interface sound effects".
  public static let systemSoundsKey = "com.apple.sound.uiaudio.enabled"

  /// The sound to play, or nil for none. Plays only while both scoop's switch and macOS's
  /// interface sounds are on. Cancelling a capture sends no event, so it stays silent.
  public static func name(for event: FeedbackEvent, enabled: Bool, systemSoundsOn: Bool) -> String?
  {
    guard enabled, systemSoundsOn else { return nil }
    switch event {
    case .copied: return "Frog"
    case .noText, .captureFailed, .recognitionFailed: return "Sosumi"
    // Permission alerts are a window of their own; Smart Paste keeps its own beep.
    case .permissionNeeded, .accessibilityNeeded, .nothingToPaste: return nil
    }
  }

  /// macOS leaves the setting unset until it's changed, which means on.
  public static func systemSoundsOn(storedValue: Int?) -> Bool {
    storedValue != 0
  }
}
