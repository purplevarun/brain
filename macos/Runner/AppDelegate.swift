import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  /// brain is keyboard-first; the stock Edit/View/Window/Help menus only
  /// duplicate what shortcuts already do, so we drop them from the menu bar.
  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)
    let dropTitles = ["Edit", "View", "Window", "Help"]
    if let menu = NSApplication.shared.mainMenu {
      for item in menu.items where dropTitles.contains(item.title) {
        menu.removeItem(item)
      }
    }
  }
}
