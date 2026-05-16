# MenuPad

macOS のメニューバーに常駐するシンプルなテキストスクラッチパッドアプリ。

## 特徴

- メニューバーアイコンをクリックしてすぐに開閉
- プレーンテキスト編集・自動保存（⌘S でも保存可）
- 常に前面に表示モード（Always on Top）
- 非アクティブ時にウィンドウを自動的に隠す
- 空白文字の可視化（改行 `↓` / 半角スペース `·` / タブ `⇥`）
- 編集ロック（選択・コピーは可、編集不可）
- テキスト検索（⌘F / ⌘G / ⌘⇧G）
- VS Code で開く
- 行番号表示

## 動作環境

- macOS 13.0 (Ventura) 以上
- [HackGen Console NF](https://github.com/yuru7/HackGen) フォント（推奨）

## ビルド

Xcode でプロジェクトを開いてビルドするだけ。

```
open MenuPad.xcodeproj
```

## 技術スタック

- Swift / AppKit（SwiftUI 不使用）
- NSTextView サブクラスによる低レベルテキスト制御
- NSLayoutManager サブクラスによる空白文字描画
