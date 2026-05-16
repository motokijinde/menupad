# MenuPad — Mac メニューバーメモ帳アプリ 仕様書

バージョン: 1.2.1
対象 OS: macOS 13.0 (Ventura) 以上
言語: Swift / AppKit ベース（SwiftUI 不使用）

---

## 変更履歴

### v1.0 → v1.1

| # | 種別 | 内容 |
|---|------|------|
| 1 | バグ修正 | `@main` → `@NSApplicationMain` に変更 |
| 2 | バグ修正 | WhitespaceLayoutManager の組み込み方法を修正（手動スタック構築へ） |
| 3 | バグ修正 | `drawGlyphs` の座標計算に `textContainerOrigin` を追加 |
| 4 | バグ修正 | 空テキスト時のクラッシュガードを追加 |
| 5 | バグ修正 | `NSFontManager.shared.target`（deprecated）を削除、レスポンダーチェーンに変更 |
| 6 | 追加 | `PadPanel` サブクラスを追加（`canBecomeKey = true`） |
| 7 | 追加 | `panel.hidesOnDeactivate = false` を追加 |
| 8 | 追加 | `isRichText = false` を明示（ペースト時のリッチテキスト混入防止） |
| 9 | 追加 | 右クリックメニュー後に `statusItem.menu = nil` でリセット |

### v1.1 → v1.2

| # | 種別 | 内容 |
|---|------|------|
| 1 | 変更 | テキスト永続化を UserDefaults → ファイルシステム（`~/Documents/MenuPad/*.txt`）に移行 |
| 2 | 変更 | 検索を `usesFindBar` → ツールバーカスタム検索フィールドに変更 |
| 3 | 変更 | 改行記号を `¶`（U+00B6）→ `↓`（U+2193）に変更 |
| 4 | 変更 | 空白記号の描画色を `tertiaryLabelColor` → `secondaryLabelColor` に変更 |
| 5 | 変更 | 改行描画を `enumerateSubstrings` → `enumerateLineFragments` に変更（グリフ位置不安定の解消） |
| 6 | 変更 | フォントを HackGen Console NF 固定（フォント変更機能を削除） |
| 7 | 変更 | ファイル I/O をバックグラウンドキュー（`.utility`）に移動（Hang Risk 解消） |
| 8 | 追加 | タイトルフィールド（ツールバー）でファイル名を変更・新規作成 |
| 9 | 追加 | 手動保存（⌘S） |
| 10 | 追加 | 編集ロック機能（ツールバーボタン。ロック中は選択・コピーのみ可） |
| 11 | 追加 | VS Code で開く（ツールバーボタン。ファイル保存 → VS Code 起動 → ウィンドウを隠す） |
| 12 | 追加 | VS Code 編集後、MenuPad 再表示時にファイルを自動リロード |
| 13 | 追加 | 非アクティブ時にウィンドウを自動非表示（常に前面がOFF のとき） |
| 14 | 追加 | 行番号表示（LineNumberRulerView） |
| 15 | 削除 | フォント変更（NSFontPanel 連携）を削除 |

### v1.2 → v1.2.1

| # | 種別 | 内容 |
|---|------|------|
| 1 | バグ修正 | `NSApp.activate()` を `NSRunningApplication.current.activate(options: .activateIgnoringOtherApps)` に変更（macOS 14+ で LSUIElement アプリのアクティブ化が確実に動作するよう修正） |
| 2 | バグ修正 | `panel.hidesOnDeactivate` を `!alwaysOnTop` に変更（常前面OFF 時にアプリ非アクティブ化で自動非表示される標準挙動を利用） |
| 3 | バグ修正 | アプリ非アクティブ化の検知を `applicationDidResignActive` → `NSWorkspace.didActivateApplicationNotification` 監視に変更 |
| 4 | バグ修正 | `windowDidResignKey` にフォールバック非表示処理を追加 |
| 5 | バグ修正 | `toggleWindow` でウィンドウを手動で閉じたとき `NSApp.deactivate()` を呼び出しアプリを非アクティブ化 |

---

## 1. 概要

メニューバーに常駐するシンプルなテキストスクラッチパッドアプリ。
ステータスバーアイコンをクリックしてウィンドウを表示・非表示できる。テキストはファイルとして `~/Documents/MenuPad/` に保存される。

---

## 2. 機能一覧

| # | 機能 | 備考 |
|---|------|------|
| F-01 | メニューバー常駐・アイコンクリックでウィンドウ開閉 | 左クリック: 開閉、右クリック: メニュー |
| F-02 | テキスト編集（プレーンテキスト） | リッチテキスト混入防止済み |
| F-03 | ファイルベースのテキスト永続化 | `~/Documents/MenuPad/*.txt`、自動保存（0.5秒デバウンス）＋手動保存（⌘S） |
| F-04 | ウィンドウサイズのリサイズ（ドラッグ） | 最小サイズ 420×150 |
| F-05 | 常前面表示モード（Always on Top）のON/OFF | 右クリックメニューから切り替え |
| F-06 | 非アクティブ時のウィンドウ自動非表示 | 常前面がOFF のときのみ |
| F-07 | 空白文字の可視化のON/OFF | 改行`↓` / 半角スペース`·` / タブ`⇥` |
| F-08 | テキスト検索（ツールバー） | ⌘F でフォーカス、⌘G / ⌘⇧G で前後移動、ハイライト表示 |
| F-09 | 編集ロック | ツールバーボタン。ロック中は選択・コピーのみ可 |
| F-10 | VS Code で開く | ツールバーボタン。VS Code 終了後に MenuPad を再表示するとファイルを自動リロード |
| F-11 | ファイル名変更 | タイトルフィールドを編集して Enter で確定 |
| F-12 | 行番号表示 | スクロールビューの左ルーラーに表示 |
| F-13 | Dock アイコン非表示 | `LSUIElement = YES` |

---

## 3. アーキテクチャ

### 3.1 技術選定

| 項目 | 選択 | 理由 |
|------|------|------|
| UI フレームワーク | AppKit | NSTextView の低レベル制御が必要なため |
| ウィンドウ型 | PadPanel（NSPanel サブクラス） | `canBecomeKey = true` にオーバーライドする必要があるため |
| テキストビュー | PadTextView（NSTextView サブクラス） | 保存デバウンス・スペース変換ブロック処理のため |
| レイアウトマネージャー | WhitespaceLayoutManager（NSLayoutManager サブクラス） | 空白文字の描画オーバーライドのため |
| フォント | HackGen Console NF（固定） | 半角2文字＝全角1文字の等幅を実現するため |

### 3.2 クラス構成

```
AppDelegate  [@NSApplicationMain]
├── NSStatusItem（メニューバーアイコン）
└── PadWindowController（NSWindowController）
    ├── PadPanel（NSPanel サブクラス）
    │   ├── NSToolbar
    │   │   ├── TitleTextField（タイトル・ファイル名）
    │   │   ├── NSSearchField（検索フィールド）
    │   │   ├── 前へ / 次へ ボタン（chevron.up / chevron.down）
    │   │   ├── VS Code ボタン
    │   │   └── ロックボタン
    │   └── NSScrollView
    │       ├── LineNumberRulerView（行番号）
    │       └── PadTextView（NSTextView サブクラス）
    │           ├── NSTextStorage
    │           └── WhitespaceLayoutManager（NSLayoutManager サブクラス）
    │               └── NSTextContainer
    └── PreferencesManager（UserDefaults ラッパー・シングルトン）
```

---

## 4. 各コンポーネント詳細

### 4.1 AppDelegate

エントリーポイントは `@NSApplicationMain`。
左クリック→ウィンドウ開閉、右クリック→コンテキストメニューを `sendAction(on:)` で振り分ける。

**コンテキストメニュー:**
```
[✓] 常に前面に表示
[ ] 空白文字を表示
─────────────────
    終了
```

**非アクティブ時の自動非表示:**

`NSWorkspace.didActivateApplicationNotification` で通常アプリ（`activationPolicy == .regular`）がアクティブになったことを検知し、常前面がOFF のときだけ `orderOut` する。加えて `PadPanel.hidesOnDeactivate = true`（常前面OFF 時）を設定することで、macOS 標準のパネル自動非表示機能も併用している。

`NSApp.activate()` は macOS 14+ の LSUIElement アプリで動作が不安定なため、`NSRunningApplication.current.activate(options: .activateIgnoringOtherApps)` を使用する。

---

### 4.2 PadWindowController と PadPanel

#### PadPanel（NSPanel サブクラス）

`.nonactivatingPanel` スタイルを持つ NSPanel はデフォルトで `canBecomeKey = false` になり、キーボード操作が届かない。`PadPanel` でオーバーライドして解決する。

```swift
class PadPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}
```

`hidesOnDeactivate` は `!alwaysOnTop` に設定する。常前面OFF 時は macOS 標準のパネル自動非表示と、`NSWorkspace` 通知・`windowDidResignKey` のフォールバックを組み合わせて非表示を制御する。

#### テキストスタックの構築順序（重要）

NSTextView 生成後に layout manager を差し替えると内部不整合が起きる。Storage → LayoutManager → Container → View の順に手動構築する。

```swift
let textStorage = NSTextStorage()
let layoutManager = WhitespaceLayoutManager()
textStorage.addLayoutManager(layoutManager)
let textContainer = NSTextContainer(size: ...)
layoutManager.addTextContainer(textContainer)
let textView = PadTextView(frame: ..., textContainer: textContainer)
```

#### ファイル永続化

テキストは `~/Documents/MenuPad/` 以下に `.txt` ファイルとして保存する。タイトルフィールドの値がファイル名になる。同名ファイルが存在する場合は「名前 2.txt」「名前 3.txt」と連番で回避する。

ファイル I/O はメインスレッドをブロックしないよう `.utility` キューで非同期実行する。

```swift
// 書き込み
DispatchQueue.global(qos: .utility).async {
    try? text.write(to: url, atomically: true, encoding: .utf8)
}

// 読み込み（UI更新はメインスレッドに戻す）
DispatchQueue.global(qos: .utility).async { [weak self] in
    guard let text = try? String(contentsOf: url, encoding: .utf8) else { return }
    DispatchQueue.main.async { self?.padTextView?.string = text }
}
```

#### VS Code 連携

1. 現在のテキストをファイルに保存
2. `open -a "Visual Studio Code"` でファイルを開く
3. ウィンドウを `orderOut`（非表示）し、`needsReloadFromDisk = true` フラグを立てる
4. MenuPad 再表示時（`reloadIfNeeded()`）にファイルを再読み込みする

---

### 4.3 PadTextView（NSTextView サブクラス）

#### 保存デバウンス

テキスト変更のたびに0.5秒のタイマーをリセットし、入力が止まったタイミングで保存コールバックを呼ぶ。

```swift
override func didChangeText() {
    super.didChangeText()
    saveTimer?.invalidate()
    saveTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
        guard let self else { return }
        self.onTextDidChange?(self.string)
    }
}
```

#### スペース2回→ピリオド変換のブロック

macOS はスペース2回入力で `. ` に変換する機能を持つが、`enabledTextCheckingTypes` では防げないケースがある。`insertText` をオーバーライドして直接インターセプトする。

#### プレーンテキスト専用

```swift
textView.isRichText = false
```

---

### 4.4 WhitespaceLayoutManager（NSLayoutManager サブクラス）

`drawGlyphs(forGlyphRange:at:)` をオーバーライドして空白文字の位置に記号を重ね描きする。

#### 空白記号

| 文字 | 記号 | Unicode |
|------|------|---------|
| 半角スペース | `·` | U+00B7 |
| タブ | `⇥` | U+21E5 |
| 改行 | `↓` | U+2193 |

描画色は `NSColor.secondaryLabelColor`。

#### スペース・タブ と 改行で実装を分ける理由

`\n` グリフは遅延レイアウトの影響で次行頭に配置されることがあり、グリフ位置が不安定。そのためスペース・タブは `enumerateSubstrings` でグリフ位置から描画するが、改行は `enumerateLineFragments` で行フラグメントを直接たどって描画する。

```
空行:          usedRect.minX（行頭）に ↓ を描画
テキストあり行: \n を除いたコンテンツグリフの boundingRect.maxX に ↓ を描画
```

---

### 4.5 PreferencesManager

`UserDefaults` のラッパー。シングルトンパターン。

| キー | 型 | 内容 |
|------|----|------|
| `lastFilePath` | String? | 最後に開いたファイルの絶対パス |
| `alwaysOnTop` | Bool | 常前面モード |
| `showsInvisibles` | Bool | 空白文字表示 |
| `windowFrame` | [Double] | [x, y, width, height] |

テキスト本文・フォント設定は UserDefaults に保存しない。

---

## 5. Info.plist 設定

```xml
<!-- Dock に表示しない（メニューバー専用アプリ） -->
<key>LSUIElement</key>
<true/>
```

---

## 6. プロジェクト構成

```
MenuPad/
├── MenuPad.xcodeproj
├── README.md
└── MenuPad/
    ├── main.swift                      ← エントリーポイント
    ├── AppDelegate.swift               ← StatusItem・メニュー・ウィンドウ開閉
    ├── PadWindowController.swift       ← ウィンドウ・ツールバー・ファイル操作・検索
    ├── PadTextView.swift               ← NSTextView サブクラス・保存デバウンス
    ├── WhitespaceLayoutManager.swift   ← 空白文字可視化
    ├── LineNumberRulerView.swift       ← 行番号ルーラー
    ├── PreferencesManager.swift        ← UserDefaults ラッパー
    ├── Assets.xcassets
    └── Info.plist
```

---

## 7. キーボードショートカット

| ショートカット | 動作 |
|--------------|------|
| `⌘S` | 手動保存 |
| `⌘F` | 検索フィールドにフォーカス |
| `⌘G` | 次の検索結果へ |
| `⌘⇧G` | 前の検索結果へ |
| `⌘Z` / `⌘⇧Z` | Undo / Redo |
| `⌘X` / `⌘C` / `⌘V` | Cut / Copy / Paste |

---

## 8. 注意事項・ハマりポイント

| ポイント | 対処 |
|---------|------|
| NSTextView の layout manager 差し替え | textView 生成後の差し替えは NG。Storage→LM→Container→View の順に手動構築 |
| `nonactivatingPanel` で FindBar が動かない | `PadPanel` で `canBecomeKey = true` にオーバーライド |
| `\n` グリフの位置不安定 | 改行描画は `enumerateLineFragments` を使う |
| ファイル I/O によるメインスレッドのブロック | 読み書きは `.utility` キューで非同期実行 |
| ペースト時にリッチテキストが混入 | `isRichText = false` を設定 |
| 右クリックメニュー後に左クリックが効かない | メニュー表示後 `statusItem.menu = nil` でリセット |
| `LSUIElement = YES` でウィンドウが前面に出ない | `NSRunningApplication.current.activate(options: .activateIgnoringOtherApps)` を使う（`NSApp.activate()` は macOS 14+ の LSUIElement アプリで不安定） |
| スペース2回→ピリオド変換 | `insertText` をオーバーライドしてインターセプト |
| VS Code 編集後に変更が反映されない | `needsReloadFromDisk` フラグでウィンドウ再表示時にリロード |

---

*以上*
