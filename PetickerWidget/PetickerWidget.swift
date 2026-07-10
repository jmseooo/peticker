import WidgetKit
import SwiftUI

// 위젯 한 칸에 담기는 데이터 — 다운샘플링된 작은 스티커 PNG (Data는 Sendable) + 배경/전경색
struct StickerEntry: TimelineEntry {
    let date: Date
    let imageData: Data?
    let background: Color
    let foreground: Color   // 배경 위 배터리 표시 색 (어두운 배경에선 흰색)

    // 앱에서 아직 배경색을 고르지 않았으면 흰 배경 + 검정 전경
    static func background() -> (fill: Color, foreground: Color) {
        guard let c = SharedStore.backgroundColorRGBA() else { return (.white, .black) }
        let fill = Color(.sRGB, red: c.red, green: c.green, blue: c.blue, opacity: c.alpha)
        // sRGB 상대 휘도(근사) — 어두우면 전경을 흰색으로 뒤집어 배터리 표시가 묻히지 않게 한다
        let luminance = 0.299 * c.red + 0.587 * c.green + 0.114 * c.blue
        return (fill, luminance < 0.5 ? .white : .black)
    }

    static func current(imageData: Data?) -> StickerEntry {
        let bg = background()
        return StickerEntry(date: Date(), imageData: imageData, background: bg.fill, foreground: bg.foreground)
    }
}

// 공유 저장소에서 스티커를 (메모리 안전하게) 읽어 타임라인을 구성
struct StickerProvider: TimelineProvider {
    func placeholder(in context: Context) -> StickerEntry {
        StickerEntry(date: Date(), imageData: nil, background: .white, foreground: .black)
    }

    func getSnapshot(in context: Context, completion: @escaping (StickerEntry) -> Void) {
        completion(.current(imageData: SharedStore.widgetImageData()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StickerEntry>) -> Void) {
        // 스티커·배경색은 앱에서 저장할 때만 바뀌므로 자동 새로고침 없음(.never) — 갱신은 앱이 요청
        completion(Timeline(entries: [.current(imageData: SharedStore.widgetImageData())], policy: .never))
    }
}

struct PetickerWidgetEntryView: View {
    var entry: StickerEntry

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // 배터리 100% — 위젯 상단 (앱 미리보기와 동일한 구성)
                VStack {
                    HStack(spacing: 4) {
                        Image(systemName: "battery.100")
                            .font(.system(size: 14))
                        Text("100%")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundStyle(entry.foreground)
                    .padding(.top, 4)
                    Spacer()
                }

                if let data = entry.imageData, let image = UIImage(data: data) {
                    // 스티커 — 상단 배터리 영역을 침범하지 않도록 위쪽 여백 확보
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .padding(.top, geo.size.height * 0.24)
                        .padding([.horizontal, .bottom], 6)
                } else {
                    // 아직 스티커를 만들지 않은 경우 안내
                    VStack(spacing: 6) {
                        Image(systemName: "pawprint.fill")
                            .font(.system(size: 24))
                        Text("앱에서 스티커를\n만들어 주세요")
                            .font(.system(size: 11, weight: .semibold))
                            .multilineTextAlignment(.center)
                    }
                    .foregroundStyle(.secondary)
                    .padding(.top, geo.size.height * 0.12)
                }
            }
            // GeometryReader는 자식을 좌상단에 두므로, 위젯 전체를 채워 중앙 정렬되게 함
            .frame(width: geo.size.width, height: geo.size.height)
        }
        // 앱의 Background 팔레트에서 고른 색 (iOS는 서드파티 위젯의 '진짜 투명'을 허용하지 않아
        // 벽지를 비출 수는 없지만, 배경색 지정은 정식 지원된다).
        // 시스템이 위젯 모서리에 맞춰 자동으로 클리핑한다.
        .containerBackground(entry.background, for: .widget)
    }
}

struct PetickerWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: SharedStore.widgetKind, provider: StickerProvider()) { entry in
            PetickerWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Peticker")
        .description("반려동물 스티커를 홈 화면에 표시합니다.")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()   // 투명 배경 위에 스티커가 꽉 차게
    }
}

#Preview(as: .systemSmall) {
    PetickerWidget()
} timeline: {
    StickerEntry(date: Date(), imageData: nil, background: .white, foreground: .black)
}
