import UIKit
import ImageIO
import SwiftUI
import WidgetKit

// 앱과 위젯 익스텐션이 함께 접근하는 공유 저장소 (App Group)
// - 앱: 완성된 스티커(누끼+스트로크)를 PNG로 저장하고 위젯 갱신을 요청
// - 위젯: 저장된 스티커를 (메모리 안전하게 다운샘플링해) 읽어 홈 화면에 표시
enum SharedStore {
    // 앱·위젯 두 타겟의 Signing & Capabilities에 동일하게 등록된 App Group ID
    static let appGroupID = "group.com.jinminseo.Peticker"

    // StaticConfiguration의 kind — reloadTimelines 대상과 일치해야 함
    static let widgetKind = "PetickerWidget"

    private static let stickerFileName = "sticker.png"

    // 완성 스티커를 다시 편집하려면 원본 사진이 있어야 한다 (누끼를 새로 뜬다).
    // 사진이라 알파가 없으므로 JPEG로 저장해 용량을 아낀다.
    private static let originalFileName = "original.jpg"

    // 다시 편집할 때 이어받을 테두리 색
    private static let outlineColorKey = "stickerOutlineColorRGBA"

    // 위젯 배경색 — sRGB [r, g, b, a] 4요소로 저장.
    // 색상값을 직접 저장해 위젯 타겟이 앱의 Color 확장(Colors.swift)에 의존하지 않게 한다.
    private static let backgroundColorKey = "widgetBackgroundColorRGBA"

    // 앱이 마지막으로 관찰한 배터리 퍼센트 — 위젯이 직접 못 읽을 때의 대비책
    private static let batteryPercentKey = "lastKnownBatteryPercent"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    // App Group 공유 컨테이너 루트
    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }

    // 공유 컨테이너 내 스티커 파일 경로
    private static var stickerURL: URL? {
        containerURL?.appendingPathComponent(stickerFileName)
    }

    // 공유 컨테이너 내 원본 사진 경로
    private static var originalURL: URL? {
        containerURL?.appendingPathComponent(originalFileName)
    }

    /// 완성된 스티커를 저장. 위젯 메모리 한도(약 30MB)를 넘지 않도록 저장 시 축소한다.
    /// 저장 후 위젯 타임라인 갱신을 요청. 성공 여부 반환.
    @discardableResult
    static func saveSticker(_ image: UIImage) -> Bool {
        guard let url = stickerURL else { return false }
        // 원본 해상도 그대로 두면 위젯이 디코딩하다 강제종료되므로 최대 1000px로 축소
        let resized = downscaled(image, maxPixel: 1000)
        guard let data = resized.pngData() else { return false }
        do {
            try data.write(to: url, options: .atomic)
            WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
            return true
        } catch {
            return false
        }
    }

    /// 위젯 배경색을 저장하고 위젯 갱신을 요청.
    static func saveBackgroundColor(_ color: UIColor) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard color.getRed(&r, green: &g, blue: &b, alpha: &a) else { return }
        defaults?.set([Double(r), Double(g), Double(b), Double(a)], forKey: backgroundColorKey)
        WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
    }

    /// 저장된 위젯 배경색(sRGB). 아직 고른 적 없으면 nil.
    static func backgroundColorRGBA() -> (red: Double, green: Double, blue: Double, alpha: Double)? {
        guard let v = defaults?.array(forKey: backgroundColorKey) as? [Double], v.count == 4 else {
            return nil
        }
        return (v[0], v[1], v[2], v[3])
    }

    /// 다시 편집할 수 있도록 원본 사진을 저장. 누끼를 새로 뜨기에 충분한 해상도로 줄인다.
    @discardableResult
    static func saveOriginal(_ image: UIImage) -> Bool {
        guard let url = originalURL else { return false }
        let resized = downscaled(image, maxPixel: 1600)
        guard let data = resized.jpegData(compressionQuality: 0.9) else { return false }
        return (try? data.write(to: url, options: .atomic)) != nil
    }

    /// 저장된 원본 사진. 아직 스티커를 만든 적 없으면 nil.
    static func loadOriginal() -> UIImage? {
        guard let url = originalURL, let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    /// 다시 편집할 때 이어받을 테두리 색을 저장. 위젯과 무관하므로 갱신은 요청하지 않는다.
    static func saveOutlineColor(_ color: UIColor) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard color.getRed(&r, green: &g, blue: &b, alpha: &a) else { return }
        defaults?.set([Double(r), Double(g), Double(b), Double(a)], forKey: outlineColorKey)
    }

    /// 저장된 테두리 색(sRGB). 아직 고른 적 없으면 nil.
    static func outlineColorRGBA() -> (red: Double, green: Double, blue: Double, alpha: Double)? {
        guard let v = defaults?.array(forKey: outlineColorKey) as? [Double], v.count == 4 else {
            return nil
        }
        return (v[0], v[1], v[2], v[3])
    }

    /// 앱이 관찰한 배터리 퍼센트를 저장 (위젯 대비책). 위젯 갱신은 요청하지 않는다 —
    /// 1%마다 reloadTimelines를 부르면 위젯 새로고침 예산을 금방 소진하기 때문.
    static func saveBatteryPercent(_ percent: Int) {
        defaults?.set(percent, forKey: batteryPercentKey)
    }

    /// 앱이 마지막으로 남긴 배터리 퍼센트. 한 번도 저장된 적 없으면 nil.
    static func lastKnownBatteryPercent() -> Int? {
        guard let defaults, defaults.object(forKey: batteryPercentKey) != nil else { return nil }
        return defaults.integer(forKey: batteryPercentKey)
    }

    /// 위젯·메인 화면 미리보기가 함께 쓰는 배경색과 그 위에 얹을 전경색(100% 표시).
    /// 아직 배경색을 고른 적 없으면 흰 배경 + 검정 전경.
    static func widgetColors() -> (background: Color, foreground: Color) {
        guard let c = backgroundColorRGBA() else { return (.white, .black) }
        let background = Color(.sRGB, red: c.red, green: c.green, blue: c.blue, opacity: c.alpha)
        // sRGB 상대 휘도(근사) — 어두운 배경에선 전경을 흰색으로 뒤집어 100% 표시가 묻히지 않게 한다
        let luminance = 0.299 * c.red + 0.587 * c.green + 0.114 * c.blue
        return (background, luminance < 0.5 ? .white : .black)
    }

    /// 위젯에서 사용 — 저장된 스티커를 ImageIO로 다운샘플링해 작은 PNG 데이터로 반환.
    /// 원본이 크더라도 전체 비트맵을 메모리에 올리지 않아 위젯 한도 안에서 안전하다.
    static func widgetImageData(maxPixel: CGFloat = 600) -> Data? {
        guard let url = stickerURL,
              let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: cg).pngData()
    }

    /// 저장된 스티커를 UIImage로 읽어 반환 (앱 메인 화면에서 사용). 없으면 nil.
    static func loadSticker() -> UIImage? {
        guard let url = stickerURL, let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    // 긴 변을 maxPixel 이하로 맞춰 축소 (투명 배경 유지). 이미 작으면 원본 반환.
    private static func downscaled(_ image: UIImage, maxPixel: CGFloat) -> UIImage {
        let longest = max(image.size.width, image.size.height)
        guard longest > maxPixel else { return image }
        let scale = maxPixel / longest
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1          // 픽셀 = 포인트 (파일 크기 최소화)
        format.opaque = false     // 누끼 투명 영역 유지
        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

// 기기 배터리 읽기 — 앱과 위젯 익스텐션이 함께 사용
enum Battery {
    // 못 읽을 때 보여줄 값 (시뮬레이터 등)
    static let fallbackPercent = 100

    /// 현재 기기 배터리 퍼센트(0~100). 읽을 수 없으면 nil.
    /// 위젯 익스텐션에서는 값이 갱신되지 않거나 -1이 나올 수 있어, 호출부에서 대비책을 둔다.
    static func currentPercent() -> Int? {
        let device = UIDevice.current
        if !device.isBatteryMonitoringEnabled {
            device.isBatteryMonitoringEnabled = true
        }
        let level = device.batteryLevel   // 0.0~1.0, 알 수 없으면 -1
        guard level >= 0 else { return nil }
        return Int((level * 100).rounded())
    }
}

/// 앱에서 배터리 변화를 관찰해 화면에 반영하고, 위젯이 읽을 수 있도록 공유 저장소에 남긴다.
@MainActor
@Observable
final class BatteryMonitor {
    static let shared = BatteryMonitor()

    private(set) var percent: Int

    private init() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        percent = Battery.currentPercent()
            ?? SharedStore.lastKnownBatteryPercent()
            ?? Battery.fallbackPercent
        SharedStore.saveBatteryPercent(percent)

        NotificationCenter.default.addObserver(
            forName: UIDevice.batteryLevelDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    private func refresh() {
        guard let current = Battery.currentPercent(), current != percent else { return }
        percent = current
        SharedStore.saveBatteryPercent(current)
    }
}
