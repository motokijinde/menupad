import Cocoa

class PadTextView: NSTextView {

    private var saveTimer: Timer?
    var onTextDidChange: ((String) -> Void)?

    // MARK: - テキスト変更検知・保存

    override func didChangeText() {
        super.didChangeText()

        // 行番号 ruler を有効化した影響で、isVerticallyResizable による
        // textView の自動リサイズ + scroller の visibility 再評価が
        // 取りこぼされることがある。明示的に高さを再計算して triggered する。
        if let sv = enclosingScrollView, let lm = layoutManager, let tc = textContainer {
            lm.ensureLayout(for: tc)
            let usedHeight = lm.usedRect(for: tc).maxY
            let required = usedHeight + textContainerInset.height * 2
            let newHeight = max(required, sv.contentSize.height)
            if abs(frame.size.height - newHeight) > 0.5 {
                setFrameSize(NSSize(width: frame.size.width, height: newHeight))
            }
            sv.reflectScrolledClipView(sv.contentView)
        }

        saveTimer?.invalidate()
        saveTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.onTextDidChange?(self.string)
        }
    }

    // MARK: - 空白文字可視化

    func setShowsInvisibles(_ show: Bool) {
        guard let lm = layoutManager as? WhitespaceLayoutManager else { return }
        lm.showsInvisibles = show
        lm.invalidateDisplay(forGlyphRange: NSRange(location: 0, length: lm.numberOfGlyphs))
    }

    // MARK: - Period substitution ブロック

    // スペース2回→ピリオド変換は NSTextInputContext レベルで行われるため
    // enabledTextCheckingTypes では防げない。insertText で直接インターセプトする。
    // パターン：置換範囲が1文字の空白 かつ 置換文字列が ". "
    override func insertText(_ string: Any, replacementRange: NSRange) {
        let plain: String
        switch string {
        case let s as String:           plain = s
        case let a as NSAttributedString: plain = a.string
        default:
            super.insertText(string, replacementRange: replacementRange)
            return
        }

        if plain == ". ",
           replacementRange.location != NSNotFound,
           replacementRange.length == 1,
           let ts = textStorage,
           replacementRange.location < ts.length,
           (ts.string as NSString).character(at: replacementRange.location) == unichar((" " as UnicodeScalar).value) {
            super.insertText("  ", replacementRange: replacementRange)
            return
        }

        super.insertText(plain, replacementRange: replacementRange)
    }

    // MARK: - ファーストレスポンダー / アクティベーション

    override var acceptsFirstResponder: Bool { true }

    // 1クリックで即カーソル位置が入るように（2クリック不要）
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    // nonactivatingPanel はクリックしてもアプリがアクティブにならない。
    // macOS 14 以降は activate(ignoringOtherApps:) の挙動が変わったため
    // AppDelegate.activateApp() で版数ごとに適切なAPIを呼ぶ。
    override func mouseDown(with event: NSEvent) {
        if !NSApp.isActive || window?.isKeyWindow == false {
            AppDelegate.activateApp()
            window?.makeKeyAndOrderFront(nil)
        }
        super.mouseDown(with: event)
    }
}
