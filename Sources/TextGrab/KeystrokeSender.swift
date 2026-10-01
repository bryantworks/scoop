import Carbon.HIToolbox
import CoreGraphics
import TextGrabCore

/// Posts ⌘V with synthetic key events (needs Accessibility permission).
@MainActor
struct CGEventKeystrokeSender: KeystrokeSender {
  func sendPaste() {
    let key = Self.keyCode(typing: "v") ?? CGKeyCode(kVK_ANSI_V)
    let source = CGEventSource(stateID: .combinedSessionState)
    source?.setLocalEventsFilterDuringSuppressionState(
      [.permitLocalMouseEvents, .permitSystemDefinedEvents],
      state: .eventSuppressionStateSuppressionInterval)
    for keyDown in [true, false] {
      let event = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: keyDown)
      // Set the flags outright so the ⌃⇧ still held from the shortcut doesn't leak in.
      event?.flags = .maskCommand
      event?.post(tap: .cgSessionEventTap)
    }
  }

  /// The key that types `character` with ⌘ held in the current keyboard layout, so ⌘V lands
  /// on the right key with Dvorak, AZERTY, "Dvorak – QWERTY ⌘" and so on.
  static func keyCode(typing character: String) -> CGKeyCode? {
    guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
      let rawLayout = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
    else { return nil }
    let layoutData = Unmanaged<CFData>.fromOpaque(rawLayout).takeUnretainedValue() as Data
    let commandState = UInt32((cmdKey >> 8) & 0xFF)
    return layoutData.withUnsafeBytes { buffer -> CGKeyCode? in
      guard let layout = buffer.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self)
      else { return nil }
      for code in 0..<128 {
        var deadKeyState: UInt32 = 0
        var chars = [UniChar](repeating: 0, count: 4)
        var length = 0
        let status = UCKeyTranslate(
          layout, UInt16(code), UInt16(kUCKeyActionDisplay), commandState,
          UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysBit), &deadKeyState,
          chars.count, &length, &chars)
        if status == noErr, String(utf16CodeUnits: chars, count: length) == character {
          return CGKeyCode(code)
        }
      }
      return nil
    }
  }
}
