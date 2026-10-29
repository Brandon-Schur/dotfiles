// zoomctl — small Accessibility helper for driving the Zoom meeting window.
//
// Spawned by the Stream Deck plugin (so macOS attributes the Accessibility
// permission to "Elgato Stream Deck"). Commands:
//   zoomctl status                 -> JSON: trusted, meeting window present, window titles
//   zoomctl trust                  -> trigger the macOS Accessibility permission prompt
//   zoomctl react <emoji> <name>   -> send any reaction (quick panel, named panel reactions, or emoji search)
//   zoomctl toggle chat|participants
//   zoomctl dump [all]             -> print the AX tree of the meeting window (debugging)
//   zoomctl press <regex>          -> press first matching button in any Zoom window (debugging)
//
// Exit codes: 0 ok, 1 failure (details on stderr), 2 usage, 3 not trusted, 4 no meeting.

import AppKit
import ApplicationServices
import Foundation

let zoomBundleID = "us.zoom.xos"

// MARK: - AX helpers

func attr(_ e: AXUIElement, _ name: String) -> CFTypeRef? {
    var v: CFTypeRef?
    return AXUIElementCopyAttributeValue(e, name as CFString, &v) == .success ? v : nil
}

func str(_ e: AXUIElement, _ name: String) -> String? {
    guard let v = attr(e, name) else { return nil }
    if CFGetTypeID(v) == CFStringGetTypeID() { return (v as! String) }
    return nil
}

func children(_ e: AXUIElement) -> [AXUIElement] {
    (attr(e, kAXChildrenAttribute) as? [AXUIElement]) ?? []
}

func role(_ e: AXUIElement) -> String { str(e, kAXRoleAttribute) ?? "?" }

/// All human-readable labels an element exposes; Zoom is inconsistent about which one it uses.
func labels(_ e: AXUIElement) -> [String] {
    [kAXTitleAttribute, kAXDescriptionAttribute, kAXHelpAttribute, kAXValueAttribute, "AXIdentifier"]
        .compactMap { str(e, $0) }
        .filter { !$0.isEmpty }
}

/// Breadth-first search, bounded so a huge tree (gallery view) can't hang us.
func find(_ root: AXUIElement, limit: Int = 6000, _ pred: (AXUIElement) -> Bool) -> AXUIElement? {
    var queue = [root]
    var seen = 0
    while !queue.isEmpty && seen < limit {
        let e = queue.removeFirst()
        seen += 1
        if pred(e) { return e }
        queue.append(contentsOf: children(e))
    }
    return nil
}

func findAll(_ root: AXUIElement, limit: Int = 6000, _ pred: (AXUIElement) -> Bool) -> [AXUIElement] {
    var queue = [root]
    var out: [AXUIElement] = []
    var seen = 0
    while !queue.isEmpty && seen < limit {
        let e = queue.removeFirst()
        seen += 1
        if pred(e) { out.append(e) }
        queue.append(contentsOf: children(e))
    }
    return out
}

func isPressable(_ e: AXUIElement) -> Bool {
    var names: CFArray?
    guard AXUIElementCopyActionNames(e, &names) == .success, let arr = names as? [String] else { return false }
    return arr.contains(kAXPressAction as String)
}

func labelMatches(_ e: AXUIElement, _ regex: String) -> Bool {
    labels(e).contains { $0.range(of: regex, options: [.regularExpression, .caseInsensitive]) != nil }
}

@discardableResult
func press(_ e: AXUIElement) -> Bool {
    AXUIElementPerformAction(e, kAXPressAction as CFString) == .success
}

func dump(_ e: AXUIElement, depth: Int = 0, maxDepth: Int = 25, budget: inout Int) {
    guard depth <= maxDepth, budget > 0 else { return }
    budget -= 1
    let ls = labels(e).map { "\"\($0.prefix(60))\"" }.joined(separator: " ")
    print(String(repeating: "  ", count: depth) + role(e) + (ls.isEmpty ? "" : " " + ls) + (isPressable(e) ? " [press]" : ""))
    for c in children(e) { dump(c, depth: depth + 1, maxDepth: maxDepth, budget: &budget) }
}

func sleepMs(_ ms: Int) { usleep(useconds_t(ms * 1000)) }

/// Poll until `body` returns non-nil or the timeout elapses.
func waitFor<T>(_ timeoutMs: Int, step: Int = 75, _ body: () -> T?) -> T? {
    var waited = 0
    while waited <= timeoutMs {
        if let v = body() { return v }
        sleepMs(step)
        waited += step
    }
    return nil
}

// MARK: - Zoom lookup

func zoomApp() -> (NSRunningApplication, AXUIElement)? {
    guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: zoomBundleID).first else { return nil }
    return (app, AXUIElementCreateApplication(app.processIdentifier))
}

func windows(_ app: AXUIElement) -> [AXUIElement] {
    (attr(app, kAXWindowsAttribute) as? [AXUIElement]) ?? []
}

func isMeetingTitle(_ t: String) -> Bool {
    t.range(of: "^Zoom (Meeting|Webinar)", options: .regularExpression) != nil
}

func meetingWindow(_ app: AXUIElement) -> AXUIElement? {
    windows(app).first { isMeetingTitle(str($0, kAXTitleAttribute) ?? "") }
}

var cleanupHook: () -> Void = {}

func fail(_ msg: String, code: Int32 = 1) -> Never {
    cleanupHook()
    FileHandle.standardError.write((msg + "\n").data(using: .utf8)!)
    exit(code)
}

func requireTrusted() {
    if !AXIsProcessTrusted() { fail("not trusted for Accessibility", code: 3) }
}

func sendKey(_ pid: pid_t, keyCode: CGKeyCode, flags: CGEventFlags) {
    let src = CGEventSource(stateID: .hidSystemState)
    for down in [true, false] {
        guard let ev = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: down) else { continue }
        ev.flags = flags
        ev.postToPid(pid)
    }
}

// MARK: - Commands

func cmdStatus() {
    let trusted = AXIsProcessTrusted()
    var titles: [String] = []
    var running = false
    if let (_, app) = zoomApp() {
        running = true
        if trusted { titles = windows(app).compactMap { str($0, kAXTitleAttribute) } }
    }
    let meeting = titles.contains(where: isMeetingTitle)
    let obj: [String: Any] = ["trusted": trusted, "running": running, "meetingWindow": meeting, "titles": titles]
    let data = try! JSONSerialization.data(withJSONObject: obj)
    print(String(data: data, encoding: .utf8)!)
}

func cmdTrust() {
    let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
    print(AXIsProcessTrustedWithOptions(opts) ? "trusted" : "prompted")
}

func cmdDump(all: Bool) {
    requireTrusted()
    guard let (_, app) = zoomApp() else { fail("zoom not running", code: 4) }
    let targets = all ? windows(app) : [meetingWindow(app)].compactMap { $0 }
    if targets.isEmpty { fail("no meeting window", code: 4) }
    var budget = 4000
    for w in targets { dump(w, budget: &budget) }
}

// MARK: - Focus / cursor session
//
// Zoom only exposes its meeting toolbar to Accessibility while the toolbar is visible,
// which requires Zoom to be frontmost and the pointer over the meeting window. We
// bring Zoom forward, nudge the pointer there, and put both back afterwards.

var restoreActions: [() -> Void] = []
func restoreAll() {
    for r in restoreActions.reversed() { r() }
    restoreActions.removeAll()
}
cleanupHook = restoreAll

/// NSRunningApplication.activate() is ignored for background CLI processes on recent macOS;
/// `open -b` goes through Launch Services and reliably brings the app back.
func reactivate(_ app: NSRunningApplication) {
    if let id = app.bundleIdentifier {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        p.arguments = ["-b", id]
        try? p.run()
        p.waitUntilExit()
    } else {
        app.activate()
    }
}

func focusZoom(_ zoom: NSRunningApplication) {
    let previous = NSWorkspace.shared.frontmostApplication
    guard previous?.processIdentifier != zoom.processIdentifier else { return }
    zoom.activate()
    sleepMs(200)
    if let p = previous { restoreActions.append { sleepMs(100); reactivate(p) } }
}

func frame(_ e: AXUIElement) -> CGRect? {
    guard let p = attr(e, kAXPositionAttribute), let s = attr(e, kAXSizeAttribute) else { return nil }
    var pt = CGPoint.zero, sz = CGSize.zero
    AXValueGetValue(p as! AXValue, .cgPoint, &pt)
    AXValueGetValue(s as! AXValue, .cgSize, &sz)
    return CGRect(origin: pt, size: sz)
}

func movePointer(_ to: CGPoint) {
    CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: to, mouseButton: .left)?
        .post(tap: .cghidEventTap)
}

var pointerSaved = false
func savePointer() {
    guard !pointerSaved, let here = CGEvent(source: nil)?.location else { return }
    pointerSaved = true
    restoreActions.append { CGWarpMouseCursorPosition(here) }
}

func click(_ e: AXUIElement) -> Bool {
    guard let f = frame(e) else { return false }
    savePointer()
    let c = CGPoint(x: f.midX, y: f.midY)
    for t in [CGEventType.mouseMoved, .leftMouseDown, .leftMouseUp] {
        CGEvent(mouseEventSource: nil, mouseType: t, mouseCursorPosition: c, mouseButton: .left)?.post(tap: .cghidEventTap)
        sleepMs(40)
    }
    return true
}

/// Labels are like "Yes, Not checked" or "🔥, 1/4"; compare on the first comma-separated part.
func norm(_ s: String) -> String {
    let head = s.components(separatedBy: ", ").first ?? s
    return head.replacingOccurrences(of: "\u{FE0F}", with: "").trimmingCharacters(in: .whitespaces).lowercased()
}

func hasLabel(_ e: AXUIElement, _ wanted: [String]) -> Bool {
    let w = Set(wanted.map(norm).filter { !$0.isEmpty })
    return labels(e).contains { w.contains(norm($0)) }
}

func toolbarButton(_ win: AXUIElement, _ label: String) -> AXUIElement? {
    children(win).first { isPressable($0) && hasLabel($0, [label]) }
}

func revealToolbar(_ zoom: NSRunningApplication, _ win: AXUIElement, needing label: String) -> AXUIElement? {
    if let b = toolbarButton(win, label) { return b }
    focusZoom(zoom)
    if let b = waitFor(300, { toolbarButton(win, label) }) { return b }
    guard let f = frame(win) else { return nil }
    savePointer()
    let y = f.maxY - 60
    return waitFor(1500, step: 100) {
        movePointer(CGPoint(x: f.midX + CGFloat.random(in: -20...20), y: y))
        return toolbarButton(win, label)
    }
}

func menuWindow(_ app: AXUIElement) -> AXUIElement? {
    children(app).first { str($0, kAXTitleAttribute) == "Menu window" }
}

/// Send a reaction. `emoji` is the label to match: an emoji ("🔥"), a custom emoji code
/// (":gr_meow_thinking:"), or a named panel reaction ("Reading", "Yes"). `name` is the picker search term.
/// Order: React panel buttons -> "More reactions" picker search -> click the matching result.
func cmdReact(emoji: String, name: String) {
    requireTrusted()
    guard let (zoom, app) = zoomApp() else { fail("zoom not running", code: 4) }
    guard let win = meetingWindow(app) else { fail("no meeting window", code: 4) }
    defer { restoreAll() }

    guard let reactBtn = revealToolbar(zoom, win, needing: "React") else { fail("React button not found") }
    if menuWindow(app) != nil { // a panel left open from a previous press: close it first
        press(reactBtn)
        _ = waitFor(800) { menuWindow(app) == nil ? true : nil }
    }
    press(reactBtn)
    guard let panel = waitFor(1500, { menuWindow(app) }) else { fail("reactions panel did not open") }

    // 1. Directly on the panel (6 quick emoji, named reactions, Yes/No/Slow down/...)
    if let b = waitFor(400, { find(panel, { isPressable($0) && hasLabel($0, [emoji, name]) }) }) {
        press(b)
        return
    }

    // 2. Full picker
    guard let more = find(panel, { isPressable($0) && hasLabel($0, ["More reactions"]) }) else {
        fail("More reactions button not found")
    }
    press(more)
    let searchField: () -> AXUIElement? = {
        guard let m = menuWindow(app) else { return nil }
        return find(m, { role($0) == "AXTextField" && children($0).contains { hasLabel($0, ["Search"]) } })
    }
    guard let field = waitFor(1500, searchField) else { fail("emoji picker search field not found") }
    AXUIElementSetAttributeValue(field, kAXFocusedAttribute as CFString, kCFBooleanTrue)
    AXUIElementSetAttributeValue(field, kAXValueAttribute as CFString, name as CFString)

    let result: () -> AXUIElement? = {
        guard let m = menuWindow(app),
              let list = find(m, { role($0) == "AXList" && hasLabel($0, ["Search results"]) }) else { return nil }
        let items = children(list).filter { role($0) == "AXImage" }
        return items.first { hasLabel($0, [emoji]) }
    }
    guard let hit = waitFor(2500, result) else {
        if let r = toolbarButton(win, "React") { press(r) } // close the picker again
        fail("'\(emoji) \(name)' not found in emoji search")
    }
    if !click(hit) { fail("could not click emoji result") }
    sleepMs(150)
}

/// Chat / participants via the menu bar (View > Show/Hide …): works even with the toolbar hidden.
func cmdToggle(_ what: String) {
    requireTrusted()
    guard let (zoom, app) = zoomApp() else { fail("zoom not running", code: 4) }
    guard meetingWindow(app) != nil else { fail("no meeting window", code: 4) }
    defer { restoreAll() }
    guard ["chat", "participants"].contains(what) else { fail("usage: zoomctl toggle chat|participants", code: 2) }
    focusZoom(zoom)
    guard let bar = attr(app, kAXMenuBarAttribute), CFGetTypeID(bar) == AXUIElementGetTypeID() else {
        fail("menu bar not available")
    }
    let item = find(bar as! AXUIElement, limit: 3000) {
        role($0) == "AXMenuItem" && labelMatches($0, "^(show|hide|close) \(what)$")
    }
    guard let it = item else { fail("View > Show \(what) menu item not found") }
    press(it)
}

// MARK: - Calendar (Zoom Workplace's calendar side panel)

/// The "events" list in Zoom Workplace's calendar sidebar. Opens the sidebar if needed.
func calendarEvents(_ app: AXUIElement, openIfClosed: Bool) -> [AXUIElement]? {
    guard let main = windows(app).first(where: { str($0, kAXTitleAttribute) == "Zoom Workplace" }) else { return nil }
    let list: () -> AXUIElement? = {
        guard let ev = find(main, limit: 8000, { role($0) == "AXGroup" && hasLabel($0, ["events"]) }) else { return nil }
        return find(ev, { role($0) == "AXList" })
    }
    if let l = list() { return children(l) }
    guard openIfClosed,
          let btn = find(main, { isPressable($0) && labelMatches($0, "^Open calendar side panel") }) else { return nil }
    press(btn)
    return waitFor(2000) { list().map(children) }
}

/// "12:00 - 1:30 PM" / "11:30 AM - 12:15 PM" -> minutes since midnight (start, end).
func parseRange(_ s: String) -> (Int, Int)? {
    let re = try! NSRegularExpression(pattern: "^(\\d{1,2}):(\\d{2})\\s*(AM|PM)?\\s*-\\s*(\\d{1,2}):(\\d{2})\\s*(AM|PM)$")
    guard let m = re.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) else { return nil }
    func g(_ i: Int) -> String? {
        let r = m.range(at: i)
        return r.location == NSNotFound ? nil : String(s[Range(r, in: s)!])
    }
    func mins(_ h: Int, _ mm: Int, _ ap: String) -> Int { (h % 12 + (ap == "PM" ? 12 : 0)) * 60 + mm }
    let endAP = g(6)!
    let end = mins(Int(g(4)!)!, Int(g(5)!)!, endAP)
    var start = mins(Int(g(1)!)!, Int(g(2)!)!, g(3) ?? endAP)
    if g(3) == nil && start > end { start -= 12 * 60 } // "11:00 - 1:00 PM" means 11 AM
    return (start, end)
}

func cmdMeetings() {
    requireTrusted()
    guard let (_, app) = zoomApp() else { fail("zoom not running", code: 4) }
    guard let items = calendarEvents(app, openIfClosed: true) else { fail("calendar sidebar not found") }
    var out: [[String: Any]] = []
    for it in items {
        let texts = findAll(it, limit: 200, { role($0) == "AXStaticText" }).compactMap { str($0, kAXValueAttribute) ?? str($0, kAXTitleAttribute) ?? str($0, kAXDescriptionAttribute) }
        guard let title = texts.first,
              texts.contains(where: { $0.hasPrefix("Today") }),
              let range = texts.lazy.compactMap(parseRange).first else { continue }
        let joinable = find(it, limit: 200, { isPressable($0) && role($0) == "AXButton" && labelMatches($0, "^Join") }) != nil
        out.append(["title": title, "start": range.0, "end": range.1, "joinable": joinable])
    }
    let data = try! JSONSerialization.data(withJSONObject: out)
    print(String(data: data, encoding: .utf8)!)
}

func cmdJoin(_ title: String) {
    requireTrusted()
    guard let (zoom, app) = zoomApp() else { fail("zoom not running", code: 4) }
    guard let items = calendarEvents(app, openIfClosed: true) else { fail("calendar sidebar not found") }
    for it in items {
        let texts = findAll(it, limit: 200, { role($0) == "AXStaticText" }).compactMap { str($0, kAXValueAttribute) ?? str($0, kAXTitleAttribute) }
        guard texts.first == title else { continue }
        if let b = find(it, limit: 200, { isPressable($0) && role($0) == "AXButton" && labelMatches($0, "^Join") }) {
            zoom.activate()
            press(b)
            return
        }
        fail("meeting has no Join button yet")
    }
    fail("meeting not found: \(title)")
}

// MARK: - Focus (Do Not Disturb) state

/// macOS shows a Focus item in the menu bar while a Focus is active ("Show in Menu Bar: When Active").
func cmdFocus() {
    requireTrusted()
    var label = ""
    if let cc = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.controlcenter").first {
        let ax = AXUIElementCreateApplication(cc.processIdentifier)
        if let bar = attr(ax, "AXExtrasMenuBar"), CFGetTypeID(bar) == AXUIElementGetTypeID() {
            for item in children(bar as! AXUIElement) {
                let id = str(item, "AXIdentifier") ?? ""
                let desc = str(item, kAXDescriptionAttribute) ?? ""
                if id.lowercased().contains("focus") || desc.range(of: "focus|do not disturb", options: [.regularExpression, .caseInsensitive]) != nil {
                    label = desc.isEmpty ? id : desc
                }
            }
        }
    }
    let data = try! JSONSerialization.data(withJSONObject: ["active": !label.isEmpty, "label": label])
    print(String(data: data, encoding: .utf8)!)
}

// MARK: - Slack (focus mode toggle, DM count)

let slackBundleID = "com.tinyspeck.slackmacgap"

func slackWindow() -> (NSRunningApplication, AXUIElement)? {
    guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: slackBundleID).first else { return nil }
    let ax = AXUIElementCreateApplication(app.processIdentifier)
    // Electron only builds its full accessibility tree when asked.
    AXUIElementSetAttributeValue(ax, "AXManualAccessibility" as CFString, kCFBooleanTrue)
    guard let w = windows(ax).first(where: { (str($0, kAXTitleAttribute) ?? "").hasSuffix("Slack") }) ?? windows(ax).first else { return nil }
    return (app, w)
}

/// Slack's sidebar toggle reads "Exit focus mode" while on; other labels containing "focus mode" mean off.
func slackFocusButton(_ w: AXUIElement) -> AXUIElement? {
    find(w, limit: 40000, { role($0).contains("Button") && labelMatches($0, "focus mode") })
}

func slackDMs(_ w: AXUIElement) -> Int? {
    let tabs = findAll(w, limit: 40000, { role($0) == "AXRadioButton" && labelMatches($0, "^DMs\\b") })
    var best: Int?
    for t in tabs {
        for l in labels(t) {
            if let r = l.range(of: "(\\d+) unread", options: .regularExpression) {
                let n = Int(l[r].split(separator: " ")[0]) ?? 0
                best = max(best ?? 0, n)
            }
        }
    }
    return best ?? (tabs.isEmpty ? nil : 0)
}

func cmdSlackStatus() {
    requireTrusted()
    var obj: [String: Any] = ["running": false]
    if let (_, w) = slackWindow() {
        obj["running"] = true
        if let b = slackFocusButton(w) { obj["focus"] = labelMatches(b, "^exit focus mode") }
        if let d = slackDMs(w) { obj["dms"] = d }
        // The profile button's presence image reads e.g. "Active, notifications snoozed".
        if let u = find(w, limit: 40000, { role($0) == "AXPopUpButton" && labelMatches($0, "^User:") }) {
            // First child image is the status emoji ("tomato emoji"); absent when no status is set.
            obj["statusEmoji"] = findAll(u, limit: 50, { role($0) == "AXImage" })
                .compactMap { labels($0).first }.first { $0.hasSuffix(" emoji") }.map { String($0.dropLast(6)) } ?? ""
            obj["paused"] = find(u, limit: 50, { labelMatches($0, "notifications snoozed|notifications paused") }) != nil
        }
    }
    let data = try! JSONSerialization.data(withJSONObject: obj)
    print(String(data: data, encoding: .utf8)!)
}

func cmdSlackFocus() {
    requireTrusted()
    guard let (_, w) = slackWindow() else { fail("slack not running", code: 4) }
    guard let b = waitFor(1500, { slackFocusButton(w) }) else { fail("Slack focus mode button not found") }
    let wasOn = labelMatches(b, "^exit focus mode")
    press(b)
    let now = waitFor(3000, step: 150) { () -> Bool? in
        guard let nb = slackFocusButton(w) else { return nil }
        let on = labelMatches(nb, "^exit focus mode")
        return on != wasOn ? on : nil
    }
    guard let on = now else { fail("focus mode did not change") }
    print(on ? "on" : "off")
}

/// Slack "Pause notifications" (the 💤 status), via profile menu > Notifications submenu.
/// Needs Slack frontmost briefly because the submenu only opens on pointer hover.
/// Prints "resumed" or "paused: <menu text>". Turns focus mode off first. `list` prints the options only.
func cmdSlackDnd(_ duration: String) {
    requireTrusted()
    guard let (slack, w) = slackWindow() else { fail("slack not running", code: 4) }
    defer { restoreAll() }
    // He prefers Pause over focus mode: leave focus mode first (Slack blocks pausing while it's on).
    if duration != "list" && duration != "resume", let b = slackFocusButton(w), labelMatches(b, "^exit focus mode") {
        press(b)
        _ = waitFor(3000, step: 150) { slackFocusButton(w).flatMap { labelMatches($0, "^exit focus mode") ? nil : true } }
        sleepMs(300)
    }
    let previous = NSWorkspace.shared.frontmostApplication
    if previous?.processIdentifier != slack.processIdentifier {
        slack.activate()
        sleepMs(400)
        if let p = previous { restoreActions.append { sleepMs(150); reactivate(p) } }
    }
    guard let user = find(w, limit: 40000, { role($0) == "AXPopUpButton" && labelMatches($0, "^User:") }) else {
        fail("Slack profile button not found")
    }
    press(user)
    let closeMenu = { if find(w, limit: 40000, { role($0) == "AXMenu" }) != nil { press(user) } }
    guard let notif = waitFor(1500, { find(w, limit: 40000, { role($0) == "AXMenuItem" && labelMatches($0, "^Notifications") }) }),
          let f = frame(notif) else { closeMenu(); fail("Notifications menu item not found") }
    savePointer()
    let sub: () -> AXUIElement? = {
        findAll(w, limit: 40000, { role($0) == "AXMenu" }).first { m in
            find(m, { role($0) == "AXMenuItem" && labelMatches($0, "^Notifications") }) == nil
        }
    }
    // The submenu opens on hover; wiggle across the item (and press it) until it appears.
    var tries = 0
    guard let submenu = waitFor(4000, step: 200, { () -> AXUIElement? in
        tries += 1
        movePointer(CGPoint(x: f.minX + f.width * CGFloat.random(in: 0.3...0.8), y: f.midY + CGFloat.random(in: -3...3)))
        if tries % 5 == 0 { press(notif) }
        return sub()
    }) else { closeMenu(); fail("Notifications submenu did not open") }

    let items = findAll(submenu, { role($0) == "AXMenuItem" })
    if duration == "list" {
        print(items.map { labels($0).joined(separator: " | ") }.joined(separator: "\n"))
        closeMenu()
        return
    }
    if let resume = items.first(where: { labelMatches($0, "^resume notifications") }) {
        if labelMatches(resume, "turn off focus mode") { closeMenu(); fail("focus mode is on", code: 5) }
        press(resume)
        print(duration == "resume" ? "off" : "resumed")
        return
    }
    if duration == "resume" { closeMenu(); print("off"); return } // already not paused: never pause here
    // Pause options are labelled like "For 30 minutes", "For 1 hour", "Until tomorrow".
    let want = duration.lowercased()
    let pick = items.first { labels($0).contains { $0.lowercased().contains(want) } }
        ?? items.first { labelMatches($0, "hour") }
        ?? items.first { labelMatches($0, "minute") }
    guard let p = pick else {
        let seen = items.flatMap(labels).joined(separator: " / ")
        closeMenu()
        fail("no pause option matching '\(duration)'; saw: \(seen)")
    }
    let text = labels(p).first ?? duration
    press(p)
    print("paused: \(text)")
}

/// Slack DnD = status "🍅 Focus" (from Recent statuses) with "Pause notifications until status is
/// cleared" ticked (VIPs still get through). Off = "Clear status" in the profile menu.
/// `mode`: on | off | toggle. Prints "on" or "off".
func cmdSlackStatusDnd(_ mode: String, statusText: String, emojiName: String) {
    requireTrusted()
    guard let (slack, w) = slackWindow() else { fail("slack not running", code: 4) }
    defer { restoreAll() }
    let user: () -> AXUIElement? = { find(w, limit: 40000, { role($0) == "AXPopUpButton" && labelMatches($0, "^User:") }) }
    guard let u0 = user() else { fail("Slack profile button not found") }
    let pausedNow = find(u0, limit: 50, { labelMatches($0, "notifications snoozed|notifications paused") }) != nil
    let turnOn = mode == "on" || (mode == "toggle" && !pausedNow)

    let previous = NSWorkspace.shared.frontmostApplication
    if previous?.processIdentifier != slack.processIdentifier {
        slack.activate()
        sleepMs(400)
        if let p = previous { restoreActions.append { sleepMs(150); reactivate(p) } }
    }
    // Focus mode blocks pausing; he prefers DnD, so leave focus mode first.
    if turnOn, let b = slackFocusButton(w), labelMatches(b, "^exit focus mode") {
        press(b)
        _ = waitFor(3000, step: 150) { slackFocusButton(w).flatMap { labelMatches($0, "^exit focus mode") ? nil : true } }
    }
    guard let u = user() else { fail("Slack profile button not found") }
    press(u)
    let menuOpen = { find(w, limit: 40000, { role($0) == "AXMenu" }) != nil }
    guard waitFor(1500, { menuOpen() ? true : nil }) != nil else { fail("profile menu did not open") }

    if !turnOn {
        // The menu renders in stages; "Clear status" only exists when a status is set.
        let hasStatus = findAll(u, limit: 50, { role($0) == "AXImage" }).contains { labels($0).contains { $0.hasSuffix(" emoji") } }
        if hasStatus {
            guard let clear = waitFor(2000, { find(w, limit: 40000, { role($0) == "AXButton" && labelMatches($0, "^clear status$") }) }) else {
                press(u)
                fail("Clear status button not found")
            }
            press(clear)
            let cleared = waitFor(2500, step: 150) { () -> Bool? in
                guard let u2 = user() else { return nil }
                let still = findAll(u2, limit: 50, { role($0) == "AXImage" }).contains { labels($0).contains { $0.hasSuffix(" emoji") } }
                return still ? nil : true
            }
            if cleared == nil { fail("status did not clear") }
        } else {
            press(u) // no status set; close the menu
        }
        // Also end any separate pause (e.g. a timed one). "resume" never pauses, so this is safe.
        sleepMs(600)
        restoreAll()
        cmdSlackDnd("resume")
        return
    }

    guard let edit = find(w, limit: 40000, { role($0) == "AXMenuItem" && labelMatches($0, "^(edit|set a) status|^update your status") }) else {
        press(u)
        fail("Edit status menu item not found")
    }
    press(edit)
    let dialog: () -> AXUIElement? = { find(w, limit: 40000, { role($0) == "AXGroup" && labelMatches($0, "^set a status") }) }
    guard let dlg = waitFor(2000, dialog) else { fail("status dialog did not open") }
    let cancel = { if let c = find(dlg, { role($0) == "AXButton" && hasLabel($0, ["Cancel"]) }) ?? find(dlg, { role($0) == "AXButton" && hasLabel($0, ["Close"]) }) { press(c) } }

    // Start from empty so the Recent list shows, then pick the saved tomato status.
    if let clearAll = find(dlg, { role($0) == "AXButton" && hasLabel($0, ["Clear all"]) }) { press(clearAll) }
    let recentPattern = "set status to \(NSRegularExpression.escapedPattern(for: statusText)) :\(emojiName):"
    guard let recent = waitFor(1500, { find(dlg, limit: 4000, { role($0) == "AXButton" && labelMatches($0, recentPattern) }) }) else {
        cancel()
        fail("'\(statusText) :\(emojiName):' not in Recent statuses; set it once by hand in Slack")
    }
    press(recent)
    guard let box = waitFor(1500, { find(dlg, limit: 4000, { role($0) == "AXCheckBox" && labelMatches($0, "^pause notifications") }) }) else {
        cancel()
        fail("pause-notifications checkbox not found")
    }
    if (attr(box, kAXValueAttribute) as? NSNumber)?.intValue != 1 {
        press(box)
        _ = waitFor(1000) { (attr(box, kAXValueAttribute) as? NSNumber)?.intValue == 1 ? true : nil }
    }
    guard let save = find(dlg, limit: 4000, { role($0) == "AXButton" && hasLabel($0, ["Save"]) }) else {
        cancel()
        fail("Save button not found")
    }
    press(save)
    guard waitFor(3000, step: 150, { dialog() == nil ? true : nil }) != nil else { fail("status dialog did not close after Save") }
    print("on")
}

// MARK: - main

let args = Array(CommandLine.arguments.dropFirst())
switch args.first {
case "status": cmdStatus()
case "trust": cmdTrust()
case "dump": cmdDump(all: args.count > 1 && args[1] == "all")
case "react" where args.count >= 3: cmdReact(emoji: args[1], name: args[2])
case "toggle" where args.count >= 2: cmdToggle(args[1])
case "meetings": cmdMeetings()
case "focus": cmdFocus()
case "slack-status": cmdSlackStatus()
case "slack-focus": cmdSlackFocus()
case "slack-dnd": cmdSlackDnd(args.count >= 2 ? args[1] : "1 hour")
case "slack-status-dnd": cmdSlackStatusDnd(args.count >= 2 ? args[1] : "toggle",
                                          statusText: args.count >= 3 ? args[2] : "Focus",
                                          emojiName: args.count >= 4 ? args[3] : "tomato")
case "join" where args.count >= 2: cmdJoin(args[1])
case "press" where args.count >= 2: // debugging: press the first button in any Zoom window matching a regex
    requireTrusted()
    guard let (_, app) = zoomApp() else { fail("zoom not running", code: 4) }
    guard let b = windows(app).lazy.compactMap({ w in find(w, { isPressable($0) && labelMatches($0, args[1]) }) }).first else { fail("no match") }
    press(b)
default: fail("usage: zoomctl status|trust|react <emoji> <name>|toggle chat|participants|dump [all]|press <regex>", code: 2)
}
