import Cocoa

class WhitespaceLayoutManager: NSLayoutManager {

    var showsInvisibles: Bool = false

    private let spaceSymbol   = "·"   // U+00B7  中点（半角スペース）
    private let tabSymbol     = "⇥"   // U+21E5  タブ（右向き矢印＋縦棒）
    private let newlineSymbol = "↓"   // U+2193  下矢印（改行）

    override func drawGlyphs(forGlyphRange glyphsToShow: NSRange, at origin: CGPoint) {
        super.drawGlyphs(forGlyphRange: glyphsToShow, at: origin)

        guard showsInvisibles,
              let textStorage,
              let textContainer = textContainers.first,
              let textView = textContainer.textView else { return }

        guard textStorage.length > 0 else { return }

        let baseFont = textView.font
                    ?? NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        let symbolAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.secondaryLabelColor,
            .font: baseFont
        ]

        let charRange = self.characterRange(forGlyphRange: glyphsToShow, actualGlyphRange: nil)
        let str = textStorage.string as NSString

        // スペース・タブ：グリフ位置が安定しているので enumerateSubstrings で描画
        str.enumerateSubstrings(in: charRange,
                                options: .byComposedCharacterSequences) { [weak self] sub, range, _, _ in
            guard let self, let ch = sub else { return }
            let symbol: String
            switch ch {
            case " ":  symbol = self.spaceSymbol
            case "\t": symbol = self.tabSymbol
            default:   return
            }
            let gRange = self.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            guard gRange.length > 0 else { return }
            var drawRect = self.boundingRect(forGlyphRange: gRange, in: textContainer)
            drawRect.origin.x += origin.x
            drawRect.origin.y += origin.y
            symbol.draw(in: drawRect, withAttributes: symbolAttrs)
        }

        // 改行：\n グリフは次行頭に置かれることがあり位置不安定。
        // enumerateLineFragments で行を直接たどって安定した位置に描画する。
        self.enumerateLineFragments(forGlyphRange: glyphsToShow) { [weak self] (_, usedRect, container, glyphRange, _) in
            guard let self else { return }
            let lineCharRange = self.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
            guard lineCharRange.length > 0 else { return }

            let lastChar = str.character(at: lineCharRange.upperBound - 1)
            guard lastChar == 0x0a || lastChar == 0x0d else { return }

            // \n を除いたコンテンツの右端を x 座標に使う（usedRect は \n 余白を含むため）
            let contentLength = lineCharRange.length - 1
            let x: CGFloat
            if contentLength == 0 {
                // 空行は行頭
                x = usedRect.minX
            } else {
                let contentGlyphRange = self.glyphRange(
                    forCharacterRange: NSRange(location: lineCharRange.location, length: contentLength),
                    actualCharacterRange: nil
                )
                x = contentGlyphRange.length > 0
                    ? self.boundingRect(forGlyphRange: contentGlyphRange, in: container).maxX
                    : usedRect.minX
            }

            let drawRect = CGRect(
                x: x + origin.x,
                y: usedRect.minY + origin.y,
                width: usedRect.height,
                height: usedRect.height
            )
            self.newlineSymbol.draw(in: drawRect, withAttributes: symbolAttrs)
        }
    }
}
