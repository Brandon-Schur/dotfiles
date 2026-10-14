// menubar_toggle — temporarily swap SketchyBar for the native macOS menu bar.
//
// Replaces the mouse-hover approach (sketchybar-toggle). The native menu bar
// stays auto-hidden underneath SketchyBar until you click the SketchyBar
// "menubar" button, which runs `menubar_toggle native`.
//
// Usage:
//   menubar_toggle native   hide SketchyBar, show the native menu bar, then keep
//                           running until the mouse leaves the menu bar (and any
//                           open menu dropdown) for LEAVE_DELAY, then swap back
//   menubar_toggle sketchy  auto-hide the native menu bar, show SketchyBar
//
// It flips the global `_HIHideMenuBar` preference and broadcasts the same
// distributed notification System Settings sends, so the change applies
// immediately. No Accessibility / Automation / Screen Recording permissions.

import AppKit
import CoreGraphics
import Foundation

let key = "_HIHideMenuBar" as CFString
let sketchybar = "/opt/homebrew/bin/sketchybar"

// Pixels below the top of the screen that still count as "on the menu bar".
// The menu bar is 39px on this display; the extra slack avoids flicker.
let MENU_BAR_ZONE: CGFloat = 50
// How long the mouse must stay off the menu bar before SketchyBar returns.
let LEAVE_DELAY: TimeInterval = 0.5
let POLL_INTERVAL: TimeInterval = 0.05
// CGWindow level of the native menu bar; dropdown menus, Control Center
// panels, etc. sit at or above it.
let MENU_BAR_LAYER = 24

func setNativeAutoHide(_ hide: Bool) {
  CFPreferencesSetValue(
    key, hide as CFBoolean, kCFPreferencesAnyApplication, kCFPreferencesCurrentUser,
    kCFPreferencesAnyHost)
  CFPreferencesAppSynchronize(kCFPreferencesAnyApplication)
  DistributedNotificationCenter.default().postNotificationName(
    NSNotification.Name("AppleInterfaceMenuBarHidingChangedNotification"),
    object: nil, userInfo: nil, deliverImmediately: true)
}

func sketchybarHidden(_ hidden: Bool) {
  let p = Process()
  p.executableURL = URL(fileURLWithPath: sketchybar)
  p.arguments = ["--bar", "hidden=\(hidden ? "on" : "off")"]
  try? p.run()
  p.waitUntilExit()
}

func showSketchy() {
  setNativeAutoHide(true)
  sketchybarHidden(false)
}

/// True while the mouse is over the menu bar strip of the screen it is on, or
/// over any on-screen window above the menu bar level (an open dropdown menu,
/// Control Center panel, etc.) so browsing a menu doesn't bring SketchyBar back.
func mouseOnMenuBar() -> Bool {
  // Global coordinates, origin top-left of the primary display (same as CGWindow bounds).
  guard let mouse = CGEvent(source: nil)?.location else { return true }

  let displays = NSScreen.screens.compactMap { s -> CGRect? in
    guard let id = s.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    else { return nil }
    return CGDisplayBounds(id)
  }
  if let d = displays.first(where: { $0.contains(mouse) }), mouse.y - d.minY <= MENU_BAR_ZONE {
    return true
  }

  let windows =
    CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
    as? [[String: Any]] ?? []
  for w in windows {
    guard let layer = w[kCGWindowLayer as String] as? Int, layer > MENU_BAR_LAYER,
      let owner = w[kCGWindowOwnerName as String] as? String, owner != "sketchybar",
      let b = w[kCGWindowBounds as String] as? NSDictionary,
      let rect = CGRect(dictionaryRepresentation: b)
    else { continue }
    if rect.contains(mouse) { return true }
  }
  return false
}

func showNativeUntilMouseLeaves() {
  // Always restore SketchyBar if we get killed (e.g. `sketchybar --reload`).
  for sig in [SIGTERM, SIGINT, SIGHUP] {
    signal(sig) { _ in
      showSketchy()
      exit(0)
    }
  }

  sketchybarHidden(true)
  setNativeAutoHide(false)

  var leftAt: Date?
  while true {
    Thread.sleep(forTimeInterval: POLL_INTERVAL)
    if mouseOnMenuBar() {
      leftAt = nil
    } else if let t = leftAt {
      if Date().timeIntervalSince(t) >= LEAVE_DELAY { break }
    } else {
      leftAt = Date()
    }
  }
  showSketchy()
}

switch CommandLine.arguments.dropFirst().first {
case "native": showNativeUntilMouseLeaves()
case "sketchy": showSketchy()
default:
  FileHandle.standardError.write("usage: menubar_toggle native|sketchy\n".data(using: .utf8)!)
  exit(1)
}
