import Cocoa
import FinderSync

@objc(FinderSync)
final class FinderSync: FIFinderSync {
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
        let symbolName: String
        let selector: Selector
    }

    private let quickActions: [MenuAction] = [
        MenuAction(titleKey: "Copy Path", symbolName: "doc.on.doc", selector: #selector(copyPathToClipboard(_:))),
        MenuAction(titleKey: "Open New Terminal", symbolName: "terminal", selector: #selector(openTerminalAtPath(_:))),
    ]

    private let creationActions: [MenuAction] = [
        MenuAction(titleKey: "Text File", symbolName: "doc.text", selector: #selector(createNewTextFile(_:))),
        MenuAction(titleKey: "Markdown File", symbolName: "text.alignleft", selector: #selector(createNewMarkdownFile(_:))),
        MenuAction(titleKey: "Microsoft Word Document", symbolName: "doc.richtext", selector: #selector(createNewWordDocument(_:))),
        MenuAction(titleKey: "Microsoft Excel Spreadsheet", symbolName: "tablecells", selector: #selector(createNewExcelDocument(_:))),
        MenuAction(titleKey: "Microsoft PowerPoint Presentation", symbolName: "rectangle.on.rectangle.angled", selector: #selector(createNewPowerPointDocument(_:))),
        MenuAction(titleKey: "Pages Document", symbolName: "doc.badge.plus", selector: #selector(createNewPagesDocument(_:))),
        MenuAction(titleKey: "Numbers Spreadsheet", symbolName: "tablecells.badge.ellipsis", selector: #selector(createNewNumbersDocument(_:))),
        MenuAction(titleKey: "Keynote Presentation", symbolName: "play.rectangle.on.rectangle", selector: #selector(createNewKeynoteDocument(_:))),
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
        mainItem.image = makeSymbolImage(named: "plus", accessibilityDescription: mainItem.title)
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

    @objc private func createNewWordDocument(_ sender: Any?) {
        createFile(kind: .openXML(fileExtension: "docx", structure: [
            "[Content_Types].xml": """
            <?xml version="1.0" encoding="UTF-8"?>
            <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
              <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
              <Default Extension="xml" ContentType="application/xml"/>
              <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
              <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
            </Types>
            """,
            "_rels/.rels": """
            <?xml version="1.0" encoding="UTF-8"?>
            <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
              <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
            </Relationships>
            """,
            "word/_rels/document.xml.rels": """
            <?xml version="1.0" encoding="UTF-8"?>
            <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
              <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
            </Relationships>
            """,
            "word/styles.xml": """
            <?xml version="1.0" encoding="UTF-8"?>
            <w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
              <w:docDefaults>
                <w:rPrDefault>
                  <w:rPr>
                    <w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:cs="Calibri"/>
                    <w:sz w:val="22"/>
                    <w:szCs w:val="22"/>
                  </w:rPr>
                </w:rPrDefault>
                <w:pPrDefault>
                  <w:pPr>
                    <w:spacing w:after="0" w:line="240" w:lineRule="auto"/>
                  </w:pPr>
                </w:pPrDefault>
              </w:docDefaults>
              <w:style w:type="paragraph" w:default="1" w:styleId="Normal">
                <w:name w:val="Normal"/>
                <w:rPr>
                  <w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:cs="Calibri"/>
                  <w:sz w:val="22"/>
                  <w:szCs w:val="22"/>
                </w:rPr>
              </w:style>
            </w:styles>
            """,
            "word/document.xml": """
            <?xml version="1.0" encoding="UTF-8"?>
            <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
              <w:body>
                <w:p><w:r><w:t></w:t></w:r></w:p>
              </w:body>
            </w:document>
            """,
        ]))
    }

    @objc private func createNewExcelDocument(_ sender: Any?) {
        createFile(kind: .openXML(fileExtension: "xlsx", structure: [
            "[Content_Types].xml": """
            <?xml version="1.0" encoding="UTF-8"?>
            <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
              <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
              <Default Extension="xml" ContentType="application/xml"/>
              <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
              <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
              <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
            </Types>
            """,
            "_rels/.rels": """
            <?xml version="1.0" encoding="UTF-8"?>
            <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
              <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
            </Relationships>
            """,
            "xl/workbook.xml": """
            <?xml version="1.0" encoding="UTF-8"?>
            <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
              <sheets><sheet name="Sheet1" sheetId="1" r:id="rId1"/></sheets>
            </workbook>
            """,
            "xl/_rels/workbook.xml.rels": """
            <?xml version="1.0" encoding="UTF-8"?>
            <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
              <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
              <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
            </Relationships>
            """,
            "xl/styles.xml": """
            <?xml version="1.0" encoding="UTF-8"?>
            <styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
              <fonts count="1"><font><sz val="11"/><name val="Calibri"/><family val="2"/></font></fonts>
              <fills count="2"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill></fills>
              <borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>
              <cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>
              <cellXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/></cellXfs>
            </styleSheet>
            """,
            "xl/worksheets/sheet1.xml": """
            <?xml version="1.0" encoding="UTF-8"?>
            <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
              <sheetData/>
            </worksheet>
            """,
        ]))
    }

    @objc private func createNewPowerPointDocument(_ sender: Any?) {
        createFile(kind: .openXML(fileExtension: "pptx", structure: [
            "[Content_Types].xml": """
            <?xml version="1.0" encoding="UTF-8"?>
            <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
              <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
              <Default Extension="xml" ContentType="application/xml"/>
              <Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>
              <Override PartName="/ppt/slides/slide1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>
            </Types>
            """,
            "_rels/.rels": """
            <?xml version="1.0" encoding="UTF-8"?>
            <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
              <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/>
            </Relationships>
            """,
            "ppt/presentation.xml": """
            <?xml version="1.0" encoding="UTF-8"?>
            <p:presentation xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
              <p:sldIdLst><p:sldId id="256" r:id="rId1"/></p:sldIdLst>
            </p:presentation>
            """,
            "ppt/_rels/presentation.xml.rels": """
            <?xml version="1.0" encoding="UTF-8"?>
            <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
              <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide1.xml"/>
            </Relationships>
            """,
            "ppt/slides/slide1.xml": """
            <?xml version="1.0" encoding="UTF-8"?>
            <p:sld xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
              <p:cSld>
                <p:spTree>
                  <p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>
                  <p:grpSpPr/>
                </p:spTree>
              </p:cSld>
            </p:sld>
            """,
        ]))
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

        if let image = makeSymbolImage(named: action.symbolName, accessibilityDescription: item.title) {
            item.image = image
        }

        return item
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
        let configuration = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular, scale: .medium)
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: accessibilityDescription)?
            .withSymbolConfiguration(configuration)
        image?.isTemplate = true
        return image
    }
}
