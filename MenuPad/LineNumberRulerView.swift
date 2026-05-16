import Cocoa

final class LineNumberRulerView: NSRulerView {

    private weak var textView: NSTextView?

    init(textView: NSTextView, scrollView: NSScrollView) {
        self.textView = textView
        super.init(scrollView: scrollView, orientation: .verticalRuler)
        reservedThicknessForMarkers = 0
        reservedThicknessForAccessoryView = 0
        // スクロール通知を受け取るために明示的に有効化
        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            self, selector: #selector(textDidChange),
            name: NSTextStorage.didProcessEditingNotification,
            object: textView.textStorage)
        NotificationCenter.default.addObserver(
            self, selector: #selector(scrolled),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView)
    }

    required init(coder: NSCoder) { fatalError("init(coder:) not used") }

    deinit { NotificationCenter.default.removeObserver(self) }

    // フォント変更時に PadTextView.changeFont から呼ぶ
    func invalidateForFontChange() {
        scrollView?.needsLayout = true
        needsDisplay = true
    }

    // MARK: - NSRulerView

    override var isFlipped: Bool { true }

    // ruler が誤って first responder を奪うのを防ぐ
    override var acceptsFirstResponder: Bool { false }

    override var requiredThickness: CGFloat {
        let lineCount = textView?.string.components(separatedBy: "\n").count ?? 1
        let digits = max(String(lineCount).count, 3)
        let font = textView?.font ?? NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        let charWidth = ("0" as NSString).size(withAttributes: [.font: font]).width
        return ceil(charWidth * CGFloat(digits)) + 16
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let tv = textView,
              let lm = tv.layoutManager,
              let tc = tv.textContainer,
              let sv = scrollView else { return }

        // 塗り潰しは ruler の bounds 内に限定する。
        // drawHashMarksAndLabels(in:) の rect は docs 上「ruler の coordinate system 内」だが、
        // scrollView の tile タイミング次第で bounds より大きい矩形が渡されることがあり、
        // そのまま fill すると textView 領域まで黒で塗り潰されて画面が真っ黒になる。
        NSColor.textBackgroundColor.setFill()
        rect.intersection(bounds).fill()

        // 右端に区切り線
        NSColor.separatorColor.setStroke()
        let sep = NSBezierPath()
        sep.move(to: CGPoint(x: bounds.maxX - 0.5, y: rect.minY))
        sep.line(to: CGPoint(x: bounds.maxX - 0.5, y: rect.maxY))
        sep.lineWidth = 1
        sep.stroke()

        let nsText = tv.string as NSString
        let clipBounds  = sv.contentView.bounds
        let containerOrigin = tv.textContainerOrigin
        let font = tv.font ?? NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.tertiaryLabelColor,
        ]

        // テキストが空のとき → 1行目だけ表示
        if lm.numberOfGlyphs == 0 {
            let y = containerOrigin.y - clipBounds.minY
            drawLineNumber(1, attrs: attrs, y: y, height: font.boundingRectForFont.height)
            return
        }

        // 可視領域をテキストコンテナ座標に変換
        let visibleInContainer = CGRect(
            x: 0,
            y: max(clipBounds.minY - containerOrigin.y, 0),
            width: tc.size.width,
            height: clipBounds.height
        )
        let visibleGlyphs = lm.glyphRange(forBoundingRect: visibleInContainer, in: tc)
        guard visibleGlyphs.length > 0 else { return }

        // 可視範囲より前の改行数 → 開始行番号
        let startCharIdx = lm.characterIndexForGlyph(at: visibleGlyphs.location)
        var lineNumber = nsText.substring(to: startCharIdx)
            .components(separatedBy: "\n").count

        var glyphIdx = visibleGlyphs.location
        let glyphEnd = NSMaxRange(visibleGlyphs)

        while glyphIdx < glyphEnd {
            var fragRange = NSRange()
            let fragRect = lm.lineFragmentRect(forGlyphAt: glyphIdx, effectiveRange: &fragRange)
            let charRange = lm.characterRange(forGlyphRange: fragRange, actualGlyphRange: nil)

            // 論理行の先頭フラグメント（折り返し継続行は番号を描かない）
            let isLineStart = charRange.location == 0 ||
                nsText.character(at: charRange.location - 1) == unichar(10)

            if isLineStart {
                let y = fragRect.minY + containerOrigin.y - clipBounds.minY
                drawLineNumber(lineNumber, attrs: attrs, y: y, height: fragRect.height)
            }

            // \n で終わるフラグメント → 次の論理行へ
            let charEnd = NSMaxRange(charRange)
            if charEnd > 0 && charEnd <= nsText.length,
               nsText.character(at: charEnd - 1) == unichar(10) {
                lineNumber += 1
            }

            let next = NSMaxRange(fragRange)
            guard next > glyphIdx else { break }
            glyphIdx = next
        }
    }

    private func drawLineNumber(_ n: Int,
                                attrs: [NSAttributedString.Key: Any],
                                y: CGFloat, height: CGFloat) {
        let str = "\(n)" as NSString
        let strSize = str.size(withAttributes: attrs)
        let x = bounds.width - strSize.width - 4          // 右揃え・4px マージン
        let centeredY = y + (height - strSize.height) / 2  // 行高さに対して縦中央
        str.draw(at: CGPoint(x: x, y: centeredY), withAttributes: attrs)
    }

    // MARK: - 通知

    @objc private func textDidChange(_: Notification) {
        let newThickness = requiredThickness
        if abs(ruleThickness - newThickness) > 0.5 {
            ruleThickness = newThickness
        }
        needsDisplay = true
    }

    @objc private func scrolled(_: Notification) {
        needsDisplay = true
    }
}
