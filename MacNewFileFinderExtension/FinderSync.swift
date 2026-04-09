import Cocoa
import FinderSync
import UniformTypeIdentifiers

@objc(FinderSync)
final class FinderSync: FIFinderSync {
    private static let menuIconSize = NSSize(width: 16, height: 16)

    private enum MenuIcon {
        case fileType(String)
    }

    private enum FileCreationKind {
        case empty(fileExtension: String)
        case template(resourceName: String, fileExtension: String)
        case openXML(fileExtension: String, structure: [String: String])

        var fileExtension: String {
            switch self {
            case let .empty(fileExtension), let .template(_, fileExtension), let .openXML(fileExtension, _):
                return fileExtension
            }
        }
    }

    private struct MenuAction {
        let titleKey: String
        let icon: MenuIcon?
        let selector: Selector
    }

    private let quickActions: [MenuAction] = [
        MenuAction(titleKey: "Copy Path", icon: nil, selector: #selector(copyPathToClipboard(_:))),
        MenuAction(titleKey: "Open New Terminal", icon: nil, selector: #selector(openTerminalAtPath(_:))),
    ]

    private let creationActions: [MenuAction] = [
        MenuAction(titleKey: "Text File", icon: .fileType("txt"), selector: #selector(createNewTextFile(_:))),
        MenuAction(titleKey: "Markdown File", icon: .fileType("md"), selector: #selector(createNewMarkdownFile(_:))),
        MenuAction(titleKey: "Pages Document", icon: .fileType("pages"), selector: #selector(createNewPagesDocument(_:))),
        MenuAction(titleKey: "Numbers Spreadsheet", icon: .fileType("numbers"), selector: #selector(createNewNumbersDocument(_:))),
        MenuAction(titleKey: "Keynote Presentation", icon: .fileType("key"), selector: #selector(createNewKeynoteDocument(_:))),
    ]

    override init() {
        super.init()
        FIFinderSyncController.default().directoryURLs = [URL(fileURLWithPath: "/")]
    }

    override func beginObservingDirectory(at url: URL) {
    }

    override func endObservingDirectory(at url: URL) {
    }

    override func requestBadgeIdentifier(for url: URL) {
    }

    override var toolbarItemName: String {
        NSLocalizedString("New File", comment: "Finder toolbar item name")
    }

    override var toolbarItemToolTip: String {
        NSLocalizedString("MacNewFileFinderExtension: Click the toolbar item for a menu.", comment: "Finder toolbar tooltip")
    }

    override var toolbarItemImage: NSImage {
        makeSymbolImage(named: "plus", accessibilityDescription: toolbarItemName) ?? NSImage()
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu {
        let menu = NSMenu(title: "")
        quickActions
            .map(makeMenuItem(for:))
            .forEach(menu.addItem(_:))

        let newFileMenu = NSMenu(title: "")
        creationActions
            .map(makeMenuItem(for:))
            .forEach(newFileMenu.addItem(_:))

        let mainItem = NSMenuItem(title: NSLocalizedString("New File", comment: "Finder new file submenu"), action: nil, keyEquivalent: "")
        mainItem.submenu = newFileMenu
        menu.addItem(mainItem)

        return menu
    }

    @objc private func copyPathToClipboard(_ sender: Any?) {
        guard let targetURL = targetDirectoryURL() else { return }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(targetURL.path, forType: .string)
        NSLog("Copied path to clipboard: %@", targetURL.path)
    }

    @objc private func openTerminalAtPath(_ sender: Any?) {
        guard let targetURL = targetDirectoryURL() else { return }

        do {
            try runAppleScriptShellCommand("open -a Terminal \(shellQuoted(targetURL.path))")
            NSLog("Opened Terminal at: %@", targetURL.path)
        } catch {
            NSLog("Failed to open Terminal: %@", error.localizedDescription)
        }
    }

    @objc private func createNewPagesDocument(_ sender: Any?) {
        createFile(kind: .template(resourceName: "Blank", fileExtension: "pages"))
    }

    @objc private func createNewNumbersDocument(_ sender: Any?) {
        createFile(kind: .template(resourceName: "Blank", fileExtension: "numbers"))
    }

    @objc private func createNewKeynoteDocument(_ sender: Any?) {
        createFile(kind: .template(resourceName: "Blank", fileExtension: "key"))
    }

    @objc private func createNewTextFile(_ sender: Any?) {
        createFile(kind: .empty(fileExtension: "txt"))
    }

    @objc private func createNewMarkdownFile(_ sender: Any?) {
        createFile(kind: .empty(fileExtension: "md"))
    }

    private func makeMenuItem(for action: MenuAction) -> NSMenuItem {
        let item = NSMenuItem(title: NSLocalizedString(action.titleKey, comment: "Finder menu item"), action: action.selector, keyEquivalent: "")

        if let image = makeMenuIcon(for: action.icon) {
            item.image = image
        }

        return item
    }

    private func makeMenuIcon(for icon: MenuIcon?) -> NSImage? {
        guard let icon else { return nil }

        let image: NSImage
        switch icon {
        case let .fileType(fileType):
            let contentType = UTType(filenameExtension: fileType) ?? .data
            image = NSWorkspace.shared.icon(for: contentType)
        }

        image.size = Self.menuIconSize
        return image
    }

    private func targetDirectoryURL() -> URL? {
        let controller = FIFinderSyncController.default()

        if let url = controller.targetedURL() {
            return url
        }

        if let selectedURL = controller.selectedItemURLs()?.first {
            return selectedURL.hasDirectoryPath ? selectedURL : selectedURL.deletingLastPathComponent()
        }

        NSLog("No target URL")
        return nil
    }

    private func uniqueFileURL(in directory: URL, fileExtension: String) -> URL {
        let baseName = NSLocalizedString("Untitled", comment: "Default new file name")
        let fileManager = FileManager.default
        var counter = 0

        while true {
            let suffix = counter == 0 ? "" : " (\(counter))"
            let candidate = directory.appendingPathComponent("\(baseName)\(suffix).\(fileExtension)")
            if !fileManager.fileExists(atPath: candidate.path) {
                return candidate
            }
            counter += 1
        }
    }

    private func createFile(kind: FileCreationKind) {
        guard let directory = targetDirectoryURL() else { return }
        let destinationURL = uniqueFileURL(in: directory, fileExtension: kind.fileExtension)

        do {
            switch kind {
            case let .empty(fileExtension):
                try runAppleScriptShellCommand("touch \(shellQuoted(destinationURL.path))")
                NSLog("Created empty %@ file", fileExtension)
            case let .template(resourceName, fileExtension):
                try copyBundledTemplate(named: resourceName, withExtension: fileExtension, to: destinationURL)
            case let .openXML(_, structure):
                try createOpenXMLDocument(structure: structure, at: destinationURL)
            }

            reveal(destinationURL)
        } catch {
            NSLog("Failed to create %@ document: %@", kind.fileExtension, error.localizedDescription)
        }
    }

    private func copyBundledTemplate(named resourceName: String, withExtension fileExtension: String, to destinationURL: URL) throws {
        guard let templateURL = Bundle(for: Self.self).url(forResource: resourceName, withExtension: fileExtension) else {
            throw NSError(domain: "FinderSync", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Missing bundled template \(resourceName).\(fileExtension)",
            ])
        }

        try runAppleScriptShellCommand("cp -R \(shellQuoted(templateURL.path)) \(shellQuoted(destinationURL.path))")
    }

    private func createOpenXMLDocument(structure: [String: String], at destinationURL: URL) throws {
        let fileManager = FileManager.default
        let workspace = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: workspace, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: workspace) }

        for (relativePath, content) in structure {
            let fileURL = workspace.appendingPathComponent(relativePath)
            try fileManager.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
        }

        try zipDocument(from: workspace, to: destinationURL)
    }

    private func zipDocument(from sourceDirectory: URL, to destinationURL: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.currentDirectoryURL = sourceDirectory
        process.arguments = ["-r", destinationURL.path, "."]

        let errorPipe = Pipe()
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorOutput = String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let standardOutput = String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            throw NSError(domain: "FinderSync", code: Int(process.terminationStatus), userInfo: [
                NSLocalizedDescriptionKey: errorOutput?.isEmpty == false ? errorOutput! : (standardOutput?.isEmpty == false ? standardOutput! : "zip failed"),
            ])
        }
    }

    private func reveal(_ fileURL: URL) {
        NSLog("Created: %@", fileURL.path)
        NSWorkspace.shared.activateFileViewerSelecting([fileURL])
    }

    private func runAppleScriptShellCommand(_ command: String) throws {
        let script = NSAppleScript(source: "do shell script \(appleScriptStringLiteral(command))")
        var error: NSDictionary?
        script?.executeAndReturnError(&error)

        if let error {
            throw NSError(domain: "FinderSync", code: 1, userInfo: [
                NSLocalizedDescriptionKey: error.description,
            ])
        }
    }

    private func shellQuoted(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    private func appleScriptStringLiteral(_ value: String) -> String {
        "\"\(value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))\""
    }

    private func makeSymbolImage(named symbolName: String, accessibilityDescription: String?) -> NSImage? {
        let configuration = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular, scale: .small)
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: accessibilityDescription)?
            .withSymbolConfiguration(configuration)
        image?.isTemplate = true
        return image
    }
}
