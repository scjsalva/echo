// Echo's notifier. Echo writes one file per notification into the outbox and
// launches this app, so notifications show with Echo's name and icon. Each is
// removed after 30 seconds. Clicking one takes an open Echo tab to that item,
// or opens a new tab when there isn't one.
import AppKit
import UserNotifications

let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Echo")
let outbox = base.appendingPathComponent("outbox")
let showFor: TimeInterval = 30

// A short log for troubleshooting, next to the outbox.
func log(_ line: String) {
  let file = base.appendingPathComponent("notifier.log")
  let entry = "\(ISO8601DateFormatter().string(from: Date())) \(line)\n"
  if let handle = try? FileHandle(forWritingTo: file) {
    handle.seekToEndOfFile()
    handle.write(entry.data(using: .utf8)!)
    try? handle.close()
  } else {
    try? entry.write(to: file, atomically: true, encoding: .utf8)
  }
}

func echoURL() -> String {
  let saved = try? String(contentsOf: base.appendingPathComponent("base_url"), encoding: .utf8)
  return saved?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "http://localhost:4848"
}

// Browsers that share Chrome's scripting dictionary, and Safari, which has its own.
let chromeLike = ["com.google.Chrome", "com.brave.Browser", "com.microsoft.edgemac", "com.vivaldi.Vivaldi", "company.thebrowser.Browser"]

func quoted(_ value: String) -> String {
  "\"" + value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
}

/// The link as a fragment for an open Echo tab: changing only the part after
/// `#` doesn't reload the page, so the tab opens the item in a drawer over
/// whatever you're looking at.
func linkFragment(_ target: String) -> String {
  guard let url = URLComponents(string: target) else { return "" }
  // Keep the query encoded: a PR key's "#" would otherwise end the link early.
  let link = url.percentEncodedPath + (url.percentEncodedQuery.map { "?" + $0 } ?? "")
  return "#echo-open=" + (link.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "")
}

/// Brings an open Echo tab in the default browser forward and hands it `target`.
func focusEchoTab(_ target: String) -> Bool {
  guard let browser = NSWorkspace.shared.urlForApplication(toOpen: URL(string: "http://localhost")!),
        let bundleID = Bundle(url: browser)?.bundleIdentifier,
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty else { return false }

  let select: String
  if chromeLike.contains(bundleID) {
    select = "set active tab index of w to i"
  } else if bundleID == "com.apple.Safari" {
    select = "set current tab of w to t"
  } else {
    return false
  }

  let script = """
  tell application id \(quoted(bundleID))
    repeat with w in windows
      set i to 0
      repeat with t in tabs of w
        set i to i + 1
        if (URL of t) starts with \(quoted(echoURL())) then
          set AppleScript's text item delimiters to "#"
          set pageURL to text item 1 of (URL of t as text)
          set AppleScript's text item delimiters to ""
          set URL of t to pageURL & \(quoted(linkFragment(target)))
          \(select)
          set index of w to 1
          activate
          return "found"
        end if
      end repeat
    end repeat
  end tell
  return "missing"
  """
  var error: NSDictionary?
  let result = NSAppleScript(source: script)?.executeAndReturnError(&error)
  if let error { log("focus failed: \(error)") }
  return result?.stringValue == "found"
}

func open(_ target: String) {
  if !focusEchoTab(target), let url = URL(string: target) { NSWorkspace.shared.open(url) }
}

final class Notifier: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
  let center = UNUserNotificationCenter.current()
  var lastPosted = Date()

  func applicationDidFinishLaunching(_ notification: Notification) {
    center.delegate = self
    center.requestAuthorization(options: [.alert, .sound]) { granted, error in
      log("authorization granted=\(granted) error=\(error?.localizedDescription ?? "none")")
      DispatchQueue.main.async { self.drain() }
    }
    // Keep checking while notifications are on screen, then quit once they're all gone.
    Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
      self.drain()
      if Date().timeIntervalSince(self.lastPosted) > showFor + 2 { NSApp.terminate(nil) }
    }
  }

  func drain() {
    let files = ((try? FileManager.default.contentsOfDirectory(at: outbox, includingPropertiesForKeys: nil)) ?? []).sorted { $0.path < $1.path }
    for file in files {
      guard let text = try? String(contentsOf: file, encoding: .utf8) else { continue }
      try? FileManager.default.removeItem(at: file)
      let fields = text.components(separatedBy: "\n")
      guard fields.count >= 4 else { continue }

      let content = UNMutableNotificationContent()
      content.title = fields[0]
      content.subtitle = fields[1]
      content.body = fields[2]
      if !fields[3].isEmpty { content.sound = UNNotificationSound(named: UNNotificationSoundName(fields[3])) }
      if fields.count >= 5, !fields[4].isEmpty { content.userInfo = ["url": fields[4]] }

      let id = file.lastPathComponent
      center.add(UNNotificationRequest(identifier: id, content: content, trigger: nil)) { error in
        log("posted \(id) error=\(error?.localizedDescription ?? "none")")
      }
      lastPosted = Date()
      DispatchQueue.main.asyncAfter(deadline: .now() + showFor) {
        self.center.removeDeliveredNotifications(withIdentifiers: [id])
      }
    }
  }

  func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                              withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    completionHandler([.banner, .sound])
  }

  func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                              withCompletionHandler completionHandler: @escaping () -> Void) {
    open(response.notification.request.content.userInfo["url"] as? String ?? echoURL() + "/inbox")
    completionHandler()
  }
}

let app = NSApplication.shared
let delegate = Notifier()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
