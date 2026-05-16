import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {

    var statusItem: NSStatusItem?
    var windowController: PadWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupMainMenu()
        windowController = PadWindowController()
    }

    func applicationDidResignActive(_ notification: Notification) {
        guard !PreferencesManager.shared.alwaysOnTop else { return }
        windowController?.window?.orderOut(nil)
    }

    // MARK: - StatusItem セットアップ

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            let icon = NSImage(systemSymbolName: "note.text", accessibilityDescription: "MenuPad")
                        ?? NSImage(systemSymbolName: "square.and.pencil", accessibilityDescription: "MenuPad")
            icon?.isTemplate = true
            button.image = icon
            button.action = #selector(handleClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.target = self
        }
    }

    // MARK: - メインメニュー（⌘ショートカットのルーティングに必要）

    private func setupMainMenu() {
        let mainMenu = NSMenu()

        let fileItem = NSMenuItem(title: "File", action: nil, keyEquivalent: "")
        mainMenu.addItem(fileItem)
        let fileMenu = NSMenu(title: "File")
        let saveItem = NSMenuItem(title: "保存", action: #selector(saveFile), keyEquivalent: "s")
        saveItem.target = self
        fileMenu.addItem(saveItem)
        mainMenu.setSubmenu(fileMenu, for: fileItem)

        let editItem = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        mainMenu.addItem(editItem)

        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(NSMenuItem(title: "Undo",       action: NSSelectorFromString("undo:"),       keyEquivalent: "z"))
        editMenu.addItem(NSMenuItem(title: "Redo",       action: NSSelectorFromString("redo:"),       keyEquivalent: "Z"))
        editMenu.addItem(.separator())
        editMenu.addItem(NSMenuItem(title: "Cut",        action: #selector(NSText.cut(_:)),           keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Copy",       action: #selector(NSText.copy(_:)),          keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Paste",      action: #selector(NSText.paste(_:)),         keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)),     keyEquivalent: "a"))
        mainMenu.setSubmenu(editMenu, for: editItem)

        let findItem = NSMenuItem(title: "Find", action: nil, keyEquivalent: "")
        mainMenu.addItem(findItem)
        let findMenu = NSMenu(title: "Find")

        let findFieldItem = NSMenuItem(title: "検索...", action: #selector(performFind), keyEquivalent: "f")
        findFieldItem.target = self
        findMenu.addItem(findFieldItem)

        let nextMatchItem = NSMenuItem(title: "次を検索", action: #selector(findNext), keyEquivalent: "g")
        nextMatchItem.target = self
        findMenu.addItem(nextMatchItem)

        let prevMatchItem = NSMenuItem(title: "前を検索", action: #selector(findPrevious), keyEquivalent: "G")
        prevMatchItem.target = self
        findMenu.addItem(prevMatchItem)

        mainMenu.setSubmenu(findMenu, for: findItem)

        NSApp.mainMenu = mainMenu
    }

    @objc private func performFind() {
        guard let wc = windowController else { return }
        AppDelegate.activateApp()
        wc.window?.makeKeyAndOrderFront(nil)
        wc.focusSearchField()
    }

    @objc private func findNext() {
        windowController?.nextMatch()
    }

    @objc private func findPrevious() {
        windowController?.prevMatch()
    }

    // MARK: - クリックハンドラ

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            toggleWindow()
        }
    }

    @objc func toggleWindow() {
        guard let wc = windowController, let window = wc.window else { return }
        if window.isVisible {
            window.orderOut(nil)
        } else {
            wc.reloadIfNeeded()
            AppDelegate.activateApp()
            window.makeKeyAndOrderFront(nil)
            window.makeFirstResponder(wc.padTextView)
        }
    }

    // MARK: - コンテキストメニュー

    private func showContextMenu() {
        let menu = NSMenu()

        let alwaysOnTopItem = NSMenuItem(
            title: "常に前面に表示",
            action: #selector(toggleAlwaysOnTop),
            keyEquivalent: ""
        )
        alwaysOnTopItem.state = PreferencesManager.shared.alwaysOnTop ? .on : .off
        alwaysOnTopItem.target = self
        menu.addItem(alwaysOnTopItem)

        let invisiblesItem = NSMenuItem(
            title: "空白文字を表示",
            action: #selector(toggleInvisibles),
            keyEquivalent: ""
        )
        invisiblesItem.state = PreferencesManager.shared.showsInvisibles ? .on : .off
        invisiblesItem.target = self
        menu.addItem(invisiblesItem)

        menu.addItem(.separator())

        menu.addItem(NSMenuItem(
            title: "終了",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))

        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    // MARK: - アクション

    @objc private func saveFile() {
        windowController?.save()
    }

    @objc private func toggleAlwaysOnTop() {
        let newValue = !PreferencesManager.shared.alwaysOnTop
        PreferencesManager.shared.alwaysOnTop = newValue
        windowController?.setAlwaysOnTop(newValue)
    }

    @objc private func toggleInvisibles() {
        let newValue = !PreferencesManager.shared.showsInvisibles
        PreferencesManager.shared.showsInvisibles = newValue
        windowController?.padTextView?.setShowsInvisibles(newValue)
    }

    // macOS 14 で activate(ignoringOtherApps:) が非推奨になった。
    static func activateApp() {
        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
