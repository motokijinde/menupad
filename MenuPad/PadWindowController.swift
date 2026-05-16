import Cocoa

class PadWindowController: NSWindowController {

    private(set) var padTextView: PadTextView?
    private(set) var currentFileURL: URL?

    private var titleField: TitleTextField = {
        let f = TitleTextField()
        f.placeholderString = "タイトル"
        f.stringValue = "Untitled"
        f.isBordered = false
        f.drawsBackground = false
        f.alignment = .left
        f.font = NSFont.systemFont(ofSize: NSFont.systemFontSize, weight: .medium)
        f.translatesAutoresizingMaskIntoConstraints = false
        f.widthAnchor.constraint(equalToConstant: 140).isActive = true
        return f
    }()

    private var searchField: NSSearchField = {
        let f = NSSearchField()
        f.placeholderString = "検索"
        f.translatesAutoresizingMaskIntoConstraints = false
        f.widthAnchor.constraint(equalToConstant: 140).isActive = true
        return f
    }()

    private var searchMatches: [NSRange] = []
    private var isLocked = false
    private weak var lockItem: NSToolbarItem?
    private var needsReloadFromDisk = false

    static let menuPadDirectory: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("MenuPad")
    }()

    init() {
        let frame = PreferencesManager.shared.windowFrame
                 ?? NSRect(x: 0, y: 0, width: 420, height: 320)

        let panel = PadPanel(
            contentRect: frame,
            styleMask: [
                .titled,
                .closable,
                .resizable,
                .unifiedTitleAndToolbar,
            ],
            backing: .buffered,
            defer: false
        )
        panel.titleVisibility = .hidden
        panel.minSize = NSSize(width: 420, height: 150)
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = !PreferencesManager.shared.alwaysOnTop
        panel.level = PreferencesManager.shared.alwaysOnTop ? .floating : .normal

        super.init(window: panel)
        panel.delegate = self

        try? FileManager.default.createDirectory(at: Self.menuPadDirectory, withIntermediateDirectories: true)

        titleField.delegate = self
        searchField.delegate = self
        setupToolbar(in: panel)
        setupContent(in: panel)
        loadLastFile()

        if PreferencesManager.shared.windowFrame == nil {
            panel.center()
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    // MARK: - ツールバー

    private func setupToolbar(in panel: NSPanel) {
        let toolbar = NSToolbar(identifier: "PadToolbar")
        toolbar.delegate = self
        toolbar.allowsUserCustomization = false
        toolbar.displayMode = .iconOnly
        panel.toolbar = toolbar
    }

    // MARK: - コンテンツ構築

    private func setupContent(in panel: NSPanel) {
        guard let contentView = panel.contentView else { return }

        let scrollView = NSScrollView(frame: contentView.bounds)
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .legacy

        // ─────────────────────────────────────────────────────────
        // Storage → LayoutManager → Container → View の順に構築
        // ─────────────────────────────────────────────────────────
        let textStorage = NSTextStorage(string: "")

        let layoutManager = WhitespaceLayoutManager()
        layoutManager.showsInvisibles = PreferencesManager.shared.showsInvisibles
        textStorage.addLayoutManager(layoutManager)

        let textContainer = NSTextContainer(size: CGSize(
            width: scrollView.contentSize.width,
            height: CGFloat.greatestFiniteMagnitude
        ))
        textContainer.widthTracksTextView = true
        layoutManager.addTextContainer(textContainer)

        let textView = PadTextView(frame: scrollView.bounds, textContainer: textContainer)
        textView.autoresizingMask = [.width]
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.isRichText = false
        textView.allowsUndo = true
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.textColor = .labelColor
        textView.backgroundColor = .textBackgroundColor
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.enabledTextCheckingTypes &= ~NSTextCheckingResult.CheckingType.correction.rawValue

        let restoredFont = NSFont(name: "HackGenConsoleNF-Regular", size: 13)
                        ?? NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.font = restoredFont
        textView.typingAttributes[.font] = restoredFont

        textView.onTextDidChange = { [weak self] text in
            self?.saveTextToFile(text)
            let query = self?.searchField.stringValue ?? ""
            if !query.isEmpty { self?.performSearch(query, navigate: false) }
        }

        scrollView.documentView = textView

        let ruler = LineNumberRulerView(textView: textView, scrollView: scrollView)
        scrollView.verticalRulerView = ruler
        scrollView.hasVerticalRuler = true
        scrollView.rulersVisible = true

        contentView.addSubview(scrollView)
        self.padTextView = textView
    }

    // MARK: - ファイル操作

    private func loadLastFile() {
        if let path = PreferencesManager.shared.lastFilePath {
            let url = URL(fileURLWithPath: path)
            if FileManager.default.fileExists(atPath: url.path),
               let text = try? String(contentsOf: url, encoding: .utf8) {
                currentFileURL = url
                padTextView?.string = text
                padTextView?.undoManager?.removeAllActions()
                let name = url.deletingPathExtension().lastPathComponent
                titleField.stringValue = name
                window?.title = name
                window?.representedURL = url
                return
            }
        }
        // ファイルなし → 空の状態で起動
        titleField.stringValue = "Untitled"
        window?.title = "Untitled"
    }

    private func reloadFileFromDisk() {
        guard let url = currentFileURL else { return }
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { return }
            DispatchQueue.main.async {
                self?.padTextView?.string = text
                self?.padTextView?.undoManager?.removeAllActions()
            }
        }
    }

    private func saveTextToFile(_ text: String) {
        guard currentFileURL != nil || !text.isEmpty else { return }
        let url = resolvedFileURL()  // UI 操作があるのでメインスレッドで実行
        DispatchQueue.global(qos: .utility).async {
            try? text.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    // currentFileURL が nil のときはタイトルから新規ファイル URL を生成して確定する
    private func resolvedFileURL() -> URL {
        if let url = currentFileURL { return url }
        let name = titleField.stringValue.isEmpty ? "Untitled" : titleField.stringValue
        let url = uniqueURL(for: name)
        currentFileURL = url
        let actualName = url.deletingPathExtension().lastPathComponent
        if actualName != name {
            titleField.stringValue = actualName
            window?.title = actualName
        }
        window?.representedURL = url
        PreferencesManager.shared.lastFilePath = url.path
        return url
    }

    // 同名ファイルが存在する場合は "名前 2.txt", "名前 3.txt" … で回避
    private func uniqueURL(for name: String) -> URL {
        let base = Self.menuPadDirectory.appendingPathComponent(name).appendingPathExtension("txt")
        if !FileManager.default.fileExists(atPath: base.path) { return base }
        var i = 2
        while true {
            let candidate = Self.menuPadDirectory
                .appendingPathComponent("\(name) \(i)")
                .appendingPathExtension("txt")
            if !FileManager.default.fileExists(atPath: candidate.path) { return candidate }
            i += 1
        }
    }

    // タイトル確定時の処理（名前変更 or 新規ファイル名セット）
    private func applyTitleChange(_ newTitle: String) {
        let name = newTitle.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else {
            let current = currentFileURL?.deletingPathExtension().lastPathComponent ?? "Untitled"
            titleField.stringValue = current
            return
        }

        if let oldURL = currentFileURL {
            let newURL = Self.menuPadDirectory.appendingPathComponent(name).appendingPathExtension("txt")
            guard newURL != oldURL else { return }
            if FileManager.default.fileExists(atPath: newURL.path) {
                // 同名ファイルが既存 → 元のタイトルに戻す
                titleField.stringValue = oldURL.deletingPathExtension().lastPathComponent
                return
            }
            do {
                try FileManager.default.moveItem(at: oldURL, to: newURL)
                currentFileURL = newURL
                window?.title = name
                window?.representedURL = newURL
                PreferencesManager.shared.lastFilePath = newURL.path
            } catch {
                titleField.stringValue = oldURL.deletingPathExtension().lastPathComponent
            }
        } else {
            // ファイル未作成 → 即座に空ファイルを作成して lastFilePath を確定
            let newURL = uniqueURL(for: name)
            let actualName = newURL.deletingPathExtension().lastPathComponent
            try? "".write(to: newURL, atomically: true, encoding: .utf8)
            currentFileURL = newURL
            titleField.stringValue = actualName
            window?.title = actualName
            window?.representedURL = newURL
            PreferencesManager.shared.lastFilePath = newURL.path
        }
    }

    // MARK: - VS Code で開く

    @objc func openInVSCode() {
        let text = padTextView?.string ?? ""
        let url = resolvedFileURL()
        try? text.write(to: url, atomically: true, encoding: .utf8)

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-a", "Visual Studio Code", url.path]
        do {
            try task.run()
            needsReloadFromDisk = true
            window?.orderOut(nil)
        } catch {
            let alert = NSAlert()
            alert.messageText = "VS Code が見つかりません"
            alert.informativeText = "Visual Studio Code がインストールされていることを確認してください。"
            alert.runModal()
        }
    }

    // MARK: - 公開インターフェース

    func setAlwaysOnTop(_ enabled: Bool) {
        window?.level = enabled ? .floating : .normal
        (window as? NSPanel)?.hidesOnDeactivate = !enabled
    }

    @objc func save() {
        saveTextToFile(padTextView?.string ?? "")
    }

    func reloadIfNeeded() {
        guard needsReloadFromDisk else { return }
        needsReloadFromDisk = false
        reloadFileFromDisk()
    }

    // MARK: - ロック

    @objc func toggleLock() {
        isLocked.toggle()
        padTextView?.isEditable = !isLocked
        padTextView?.isSelectable = true
        lockItem?.image = NSImage(
            systemSymbolName: isLocked ? "lock" : "lock.open",
            accessibilityDescription: isLocked ? "ロック中" : "編集をロック"
        )
        lockItem?.toolTip = isLocked ? "ロック中（クリックで解除）" : "編集をロック"
    }
}

// MARK: - 検索

extension PadWindowController {

    func focusSearchField() {
        window?.makeFirstResponder(searchField)
        searchField.selectText(nil)
    }

    @objc func nextMatch() {
        guard !searchMatches.isEmpty, let tv = padTextView else { return }
        let cursor = tv.selectedRange().upperBound
        let target = searchMatches.first(where: { $0.location >= cursor }) ?? searchMatches[0]
        tv.scrollRangeToVisible(target)
        tv.setSelectedRange(target)
    }

    @objc func prevMatch() {
        guard !searchMatches.isEmpty, let tv = padTextView else { return }
        let cursor = tv.selectedRange().location
        let target = searchMatches.last(where: { $0.upperBound <= cursor }) ?? searchMatches[searchMatches.count - 1]
        tv.scrollRangeToVisible(target)
        tv.setSelectedRange(target)
    }

    func performSearch(_ query: String, navigate: Bool = true) {
        searchMatches = []
        guard let tv = padTextView else { return }
        clearHighlights()
        guard !query.isEmpty else { return }

        let text = tv.string as NSString
        var range = NSRange(location: 0, length: text.length)
        while range.location < text.length {
            let found = text.range(of: query, options: .caseInsensitive, range: range)
            if found.location == NSNotFound { break }
            searchMatches.append(found)
            let next = found.upperBound
            range = NSRange(location: next, length: text.length - next)
        }

        highlightMatches()

        guard navigate, !searchMatches.isEmpty else { return }
        let cursor = tv.selectedRange().location
        let target = searchMatches.first(where: { $0.location >= cursor }) ?? searchMatches[0]
        tv.scrollRangeToVisible(target)
        tv.setSelectedRange(target)
    }

    private func highlightMatches() {
        guard let tv = padTextView, let lm = tv.layoutManager else { return }
        let full = NSRange(location: 0, length: (tv.string as NSString).length)
        lm.removeTemporaryAttribute(.backgroundColor, forCharacterRange: full)

        let color = NSColor.systemYellow.withAlphaComponent(0.45)
        for range in searchMatches {
            lm.addTemporaryAttribute(.backgroundColor, value: color, forCharacterRange: range)
        }
    }

    private func clearHighlights() {
        guard let tv = padTextView, let lm = tv.layoutManager else { return }
        let full = NSRange(location: 0, length: (tv.string as NSString).length)
        lm.removeTemporaryAttribute(.backgroundColor, forCharacterRange: full)
    }


}

// MARK: - NSToolbarDelegate

extension NSToolbarItem.Identifier {
    static let titleField = NSToolbarItem.Identifier("TitleField")
    static let searchField = NSToolbarItem.Identifier("SearchField")
    static let prevMatch  = NSToolbarItem.Identifier("PrevMatch")
    static let nextMatch  = NSToolbarItem.Identifier("NextMatch")
    static let openInCode  = NSToolbarItem.Identifier("OpenInCode")
    static let lockToggle  = NSToolbarItem.Identifier("LockToggle")
}

extension PadWindowController: NSToolbarDelegate {

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier identifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        switch identifier {
        case .titleField:
            let item = NSToolbarItem(itemIdentifier: identifier)
            item.view = titleField
            return item

        case .searchField:
            let item = NSToolbarItem(itemIdentifier: identifier)
            item.view = searchField
            return item

        case .prevMatch:
            let item = NSToolbarItem(itemIdentifier: identifier)
            item.image = NSImage(systemSymbolName: "chevron.up", accessibilityDescription: "前を検索")
            item.toolTip = "前を検索 (⌘⇧G)"
            item.label = "前へ"
            item.target = self
            item.action = #selector(prevMatch)
            return item

        case .nextMatch:
            let item = NSToolbarItem(itemIdentifier: identifier)
            item.image = NSImage(systemSymbolName: "chevron.down", accessibilityDescription: "次を検索")
            item.toolTip = "次を検索 (⌘G)"
            item.label = "次へ"
            item.target = self
            item.action = #selector(nextMatch)
            return item

        case .openInCode:
            let item = NSToolbarItem(itemIdentifier: identifier)
            item.image = NSImage(systemSymbolName: "chevron.left.forwardslash.chevron.right",
                                 accessibilityDescription: "VS Codeで開く")
            item.toolTip = "VS Codeで開く"
            item.label = "VS Code"
            item.target = self
            item.action = #selector(openInVSCode)
            return item

        case .lockToggle:
            let item = NSToolbarItem(itemIdentifier: identifier)
            item.image = NSImage(systemSymbolName: "lock.open", accessibilityDescription: "編集をロック")
            item.toolTip = "編集をロック"
            item.label = "ロック"
            item.target = self
            item.action = #selector(toggleLock)
            lockItem = item
            return item

        default:
            return nil
        }
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.titleField, .flexibleSpace, .searchField, .prevMatch, .nextMatch, .openInCode, .lockToggle]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.flexibleSpace, .titleField, .searchField, .prevMatch, .nextMatch, .openInCode, .lockToggle]
    }
}

// MARK: - NSTextFieldDelegate / NSSearchFieldDelegate（タイトル・検索フィールド共用）

extension PadWindowController: NSSearchFieldDelegate {

    func controlTextDidChange(_ obj: Notification) {
        guard let field = obj.object as? NSSearchField, field === searchField else { return }
        performSearch(field.stringValue)
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        if let field = obj.object as? NSTextField, field === titleField {
            applyTitleChange(field.stringValue)
            window?.makeFirstResponder(padTextView)
        }
        // 検索フィールドは入力中にライブ検索するため、endEditing では何もしない
    }
}

// MARK: - NSWindowDelegate

extension PadWindowController: NSWindowDelegate {
    func windowDidResignKey(_ notification: Notification) {
        guard !PreferencesManager.shared.alwaysOnTop else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let window = self?.window, window.isVisible, !window.isKeyWindow else { return }
            window.orderOut(nil)
        }
    }

    func windowDidBecomeKey(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let tv = self?.padTextView,
                  let lm = tv.layoutManager,
                  let tc = tv.textContainer,
                  let sv = tv.enclosingScrollView else { return }
            lm.ensureLayout(for: tc)
            let usedHeight = lm.usedRect(for: tc).maxY
            let required = usedHeight + tv.textContainerInset.height * 2
            tv.setFrameSize(NSSize(width: tv.frame.width,
                                   height: max(required, sv.contentSize.height)))
            // tile() の完了を待ってから makeFirstResponder を呼ぶ
            DispatchQueue.main.async {
                self?.window?.makeFirstResponder(tv)
            }
        }
    }
    func windowDidResize(_ notification: Notification) {
        PreferencesManager.shared.windowFrame = window?.frame
    }
    func windowDidMove(_ notification: Notification) {
        PreferencesManager.shared.windowFrame = window?.frame
    }
}

// MARK: - PadPanel

/// NSPanel のサブクラス
/// nonactivatingPanel スタイルを持つ NSPanel は canBecomeKey が false になり
/// FindBar（⌘F）やフォントパネルへのキー操作が届かない。
class PadPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

// MARK: - TitleTextField

final class TitleTextField: NSTextField {
    override var focusRingMaskBounds: NSRect {
        bounds.insetBy(dx: -3, dy: -2)
    }
    override func drawFocusRingMask() {
        NSBezierPath(roundedRect: focusRingMaskBounds, xRadius: 4, yRadius: 4).fill()
    }
}

