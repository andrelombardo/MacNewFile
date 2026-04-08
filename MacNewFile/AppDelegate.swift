import Cocoa
import ServiceManagement

@objc(AppDelegate)
@MainActor
@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let finderExtensionBundleIdentifier = "com.louieyin.MacNewFile.MacNewFileFinderExtension"
    private static let statusSymbolName = "plus"

    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setExtensionEnabled(true)
        configureStatusItem()
        registerLoginItemIfNeeded()
    }

    func applicationWillTerminate(_ notification: Notification) {
        setExtensionEnabled(false)
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let icon = makeSymbolImage(named: Self.statusSymbolName, pointSize: 15) {
            item.button?.image = icon
        } else {
            item.button?.title = NSLocalizedString("NF", comment: "Fallback menu bar item title")
        }

        let menu = NSMenu()
        menu.addItem(withTitle: NSLocalizedString("MacNewFile is running", comment: "Status menu item"), action: nil, keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: NSLocalizedString("Quit", comment: "Quit menu item"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        item.menu = menu
        statusItem = item
    }

    private func registerLoginItemIfNeeded() {
        guard #available(macOS 13.0, *) else { return }

        let service = SMAppService.mainApp
        guard service.status != .enabled else { return }

        do {
            try service.register()
        } catch {
            NSLog("Failed to add to login items: %@", error.localizedDescription)
        }
    }

    private func setExtensionEnabled(_ enabled: Bool) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pluginkit")
        task.arguments = [
            "-e",
            enabled ? "use" : "ignore",
            "-i",
            Self.finderExtensionBundleIdentifier,
        ]

        do {
            try task.run()
            task.waitUntilExit()

            guard task.terminationStatus == 0 else {
                NSLog("pluginkit exited with status %d", task.terminationStatus)
                return
            }
        } catch {
            NSLog("Failed to configure Finder extension: %@", error.localizedDescription)
        }
    }

    private func makeSymbolImage(named symbolName: String, pointSize: CGFloat) -> NSImage? {
        let configuration = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .regular, scale: .medium)
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration)
        image?.isTemplate = true
        return image
    }
}
