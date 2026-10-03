import AppKit
import Carbon.HIToolbox
import ImageIO
import SwiftUI
import TextGrabCore

/// The Clipboard History Switcher (⌃⇧1): a search box over a list of history items.
/// It's a non-activating panel, so the app you're in stays active and receives the paste.
@MainActor
final class ClipboardSwitcher: NSObject, NSWindowDelegate {
  private let viewModel = SwitcherViewModel()
  private var panel: SwitcherPanel?
  private var keyMonitor: Any?
  /// Called with the chosen history position after the panel has closed.
  var onChoose: (Int) -> Void = { _ in }

  var isOpen: Bool { panel?.isVisible ?? false }

  func open(items: [ClipboardItem]) {
    viewModel.reset(items: items)
    let panel = self.panel ?? makePanel()
    self.panel = panel
    panel.setFrameTopLeftPoint(topLeftOnMouseScreen(size: panel.frame.size))
    panel.makeKeyAndOrderFront(nil)
    if keyMonitor == nil {
      keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
        let handled = MainActor.assumeIsolated { self?.handle(event) ?? false }
        return handled ? nil : event
      }
    }
  }

  func close() {
    if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
    keyMonitor = nil
    panel?.orderOut(nil)
  }

  func windowDidResignKey(_ notification: Notification) {
    close()  // clicked elsewhere or switched apps
  }

  /// Arrow keys, Return and Esc drive the list; everything else goes to the search field.
  /// Returns whether the key was handled here.
  private func handle(_ event: NSEvent) -> Bool {
    guard event.window === panel else { return false }
    switch Int(event.keyCode) {
    case kVK_DownArrow: viewModel.state.moveSelection(by: 1)
    case kVK_UpArrow: viewModel.state.moveSelection(by: -1)
    case kVK_Return, kVK_ANSI_KeypadEnter: choose(viewModel.state.selectedPosition)
    case kVK_Escape: close()
    default: return false
    }
    return true
  }

  private func choose(_ position: Int?) {
    guard let position else {
      NSSound.beep()
      return
    }
    close()
    onChoose(position)
  }

  private func makePanel() -> SwitcherPanel {
    let size = NSSize(width: 560, height: 420)
    let panel = SwitcherPanel(
      contentRect: NSRect(origin: .zero, size: size),
      styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    panel.isFloatingPanel = true
    panel.level = .modalPanel
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
    panel.hidesOnDeactivate = false
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = true
    panel.delegate = self
    panel.contentView = NSHostingView(
      rootView: ClipboardSwitcherView(
        viewModel: viewModel, onChoose: { [weak self] in self?.choose($0) }))
    return panel
  }

  /// Centered horizontally, a little above the middle, on the screen with the mouse.
  private func topLeftOnMouseScreen(size: NSSize) -> NSPoint {
    let mouse = NSEvent.mouseLocation
    let screen =
      NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
    let visible = screen?.visibleFrame ?? NSRect(origin: .zero, size: size)
    return NSPoint(
      x: visible.midX - size.width / 2,
      y: visible.maxY - max((visible.height - size.height) / 3, 0))
  }
}

/// A borderless panel that can take keyboard focus without activating scoop.
private final class SwitcherPanel: NSPanel {
  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { false }
}

@MainActor
@Observable
final class SwitcherViewModel {
  var state = ClipboardSwitcherModel(items: [])
  /// Changes on every open, so the view can put focus back in the search field.
  private(set) var openCount = 0

  func reset(items: [ClipboardItem]) {
    state = ClipboardSwitcherModel(items: items)
    openCount += 1
  }
}

private struct ClipboardSwitcherView: View {
  let viewModel: SwitcherViewModel
  let onChoose: (Int) -> Void
  @FocusState private var searchFocused: Bool

  private var query: Binding<String> {
    Binding(get: { viewModel.state.query }, set: { viewModel.state.query = $0 })
  }

  var body: some View {
    VStack(spacing: 0) {
      TextField("Search clipboard history", text: query)
        .textFieldStyle(.plain)
        .font(.title3)
        .padding(14)
        .focused($searchFocused)
      Divider()
      list
    }
    .frame(width: 560, height: 420)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .onAppear { searchFocused = true }
    .onChange(of: viewModel.openCount) { searchFocused = true }
  }

  @ViewBuilder private var list: some View {
    let results = viewModel.state.results
    if results.isEmpty {
      Text(viewModel.state.items.isEmpty ? "Nothing copied yet" : "No matches")
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    } else {
      ScrollViewReader { proxy in
        ScrollView {
          LazyVStack(spacing: 2) {
            ForEach(results, id: \.position) { result in
              SwitcherRow(
                result: result, isSelected: result.position == viewModel.state.selectedPosition
              )
              .id(result.position)
              .contentShape(Rectangle())
              .onTapGesture(count: 2) { onChoose(result.position) }
              .onTapGesture { viewModel.state.select(position: result.position) }
            }
          }
          .padding(6)
        }
        .onChange(of: viewModel.state.selectedPosition) { _, position in
          if let position { proxy.scrollTo(position) }
        }
      }
    }
  }
}

private struct SwitcherRow: View {
  let result: ClipboardSearch.Result
  let isSelected: Bool

  var body: some View {
    HStack(spacing: 10) {
      Image(nsImage: AppIcons.icon(for: result.item.sourceBundleID))
        .resizable()
        .frame(width: 28, height: 28)
      VStack(alignment: .leading, spacing: 2) {
        if let thumbnail = Thumbnails.thumbnail(for: result.item) {
          Image(nsImage: thumbnail.image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxWidth: 240, maxHeight: 56, alignment: .leading)
            .clipShape(RoundedRectangle(cornerRadius: 4))
          caption(["Image \(thumbnail.pixelWidth) × \(thumbnail.pixelHeight)", appName])
        } else {
          Text(ClipboardSearch.preview(result.item))
            .lineLimit(2)
            .truncationMode(.tail)
          caption([appName])
        }
      }
      Spacer(minLength: 8)
      // 1 is your latest copy, matching Settings ("2nd latest copy" is ⌃⇧2).
      Text("\(result.position + 1)")
        .font(.body.monospacedDigit())
        .foregroundStyle(.secondary)
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 6)
    .background(
      isSelected ? Color.accentColor.opacity(0.25) : .clear,
      in: RoundedRectangle(cornerRadius: 8))
  }

  private var appName: String? { result.item.sourceAppName }

  @ViewBuilder private func caption(_ parts: [String?]) -> some View {
    let text = parts.compactMap { $0 }.joined(separator: " · ")
    if !text.isEmpty {
      Text(text).font(.caption).foregroundStyle(.secondary)
    }
  }
}

/// Small previews of image items, made once per item without decoding the full image.
@MainActor
private enum Thumbnails {
  struct Thumbnail {
    let image: NSImage
    let pixelWidth: Int
    let pixelHeight: Int
  }

  private static var cache: [UUID: Thumbnail] = [:]

  static func thumbnail(for item: ClipboardItem) -> Thumbnail? {
    if let cached = cache[item.id] { return cached }
    guard let data = item.imageData,
      let source = CGImageSourceCreateWithData(data as CFData, nil),
      let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
      let cgImage = CGImageSourceCreateThumbnailAtIndex(
        source, 0,
        [
          kCGImageSourceCreateThumbnailFromImageAlways: true,
          kCGImageSourceCreateThumbnailWithTransform: true,
          kCGImageSourceThumbnailMaxPixelSize: 480,
        ] as CFDictionary)
    else { return nil }
    let thumbnail = Thumbnail(
      image: NSImage(cgImage: cgImage, size: .zero),
      pixelWidth: properties[kCGImagePropertyPixelWidth] as? Int ?? cgImage.width,
      pixelHeight: properties[kCGImagePropertyPixelHeight] as? Int ?? cgImage.height)
    // The history is small, so dropping everything now and then keeps this from growing.
    if cache.count > 100 { cache.removeAll() }
    cache[item.id] = thumbnail
    return thumbnail
  }
}

/// App icons by bundle ID, looked up once each.
@MainActor
private enum AppIcons {
  private static var cache: [String: NSImage] = [:]
  private static let fallback =
    NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Clipboard item")
    ?? NSImage()

  static func icon(for bundleID: String?) -> NSImage {
    guard let bundleID else { return fallback }
    if let icon = cache[bundleID] { return icon }
    let icon =
      NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID).map {
        NSWorkspace.shared.icon(forFile: $0.path)
      } ?? fallback
    cache[bundleID] = icon
    return icon
  }
}
