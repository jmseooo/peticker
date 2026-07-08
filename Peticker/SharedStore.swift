import UIKit
import WidgetKit

// 앱과 위젯 익스텐션이 함께 접근하는 공유 저장소 (App Group)
// - 앱: 완성된 스티커(누끼+스트로크)를 PNG로 저장하고 위젯 갱신을 요청
// - 위젯: 저장된 스티커를 읽어 홈 화면에 표시
enum SharedStore {
    // 앱·위젯 두 타겟의 Signing & Capabilities에 동일하게 등록된 App Group ID
    static let appGroupID = "group.com.jinminseo.Peticker"

    // StaticConfiguration의 kind — reloadTimelines 대상과 일치해야 함
    static let widgetKind = "PetickerWidget"

    private static let stickerFileName = "sticker.png"

    // 공유 컨테이너 내 스티커 파일 경로
    private static var stickerURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent(stickerFileName)
    }

    /// 완성된 스티커를 공유 폴더에 PNG로 저장하고 위젯 타임라인 갱신을 요청. 성공 여부 반환.
    @discardableResult
    static func saveSticker(_ image: UIImage) -> Bool {
        guard let url = stickerURL, let data = image.pngData() else { return false }
        do {
            try data.write(to: url, options: .atomic)
            WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
            return true
        } catch {
            return false
        }
    }

    /// 저장된 스티커 PNG 데이터를 읽어 반환 (위젯에서 사용). 없으면 nil.
    static func stickerData() -> Data? {
        guard let url = stickerURL else { return nil }
        return try? Data(contentsOf: url)
    }
}
