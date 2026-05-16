import Cocoa

/// UserDefaults のラッパー。全設定・テキストを永続化する。
final class PreferencesManager {

    static let shared = PreferencesManager()
    private init() {}

    private let defaults = UserDefaults.standard

    // MARK: - 最後に開いたファイルパス

    var lastFilePath: String? {
        get { defaults.string(forKey: "lastFilePath") }
        set {
            if let v = newValue { defaults.set(v, forKey: "lastFilePath") }
            else { defaults.removeObject(forKey: "lastFilePath") }
        }
    }

    // MARK: - ウィンドウ設定

    var alwaysOnTop: Bool {
        get { defaults.bool(forKey: "alwaysOnTop") }
        set { defaults.set(newValue, forKey: "alwaysOnTop") }
    }

    var showsInvisibles: Bool {
        get { defaults.bool(forKey: "showsInvisibles") }
        set { defaults.set(newValue, forKey: "showsInvisibles") }
    }

    /// ウィンドウフレームを [x, y, width, height] の Double 配列として保存
    var windowFrame: NSRect? {
        get {
            guard let arr = defaults.array(forKey: "windowFrame") as? [Double],
                  arr.count == 4 else { return nil }
            return NSRect(x: arr[0], y: arr[1], width: arr[2], height: arr[3])
        }
        set {
            guard let f = newValue else { return }
            defaults.set(
                [Double(f.origin.x), Double(f.origin.y),
                 Double(f.size.width), Double(f.size.height)],
                forKey: "windowFrame"
            )
        }
    }
}
