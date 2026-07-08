import WidgetKit
import SwiftUI

// 위젯 한 칸에 담기는 데이터 — 저장된 스티커 PNG (Data는 Sendable이라 동시성 안전)
struct StickerEntry: TimelineEntry {
    let date: Date
    let imageData: Data?
}

// 공유 저장소에서 스티커를 읽어 타임라인을 구성
struct StickerProvider: TimelineProvider {
    func placeholder(in context: Context) -> StickerEntry {
        StickerEntry(date: Date(), imageData: SharedStore.stickerData())
    }

    func getSnapshot(in context: Context, completion: @escaping (StickerEntry) -> Void) {
        completion(StickerEntry(date: Date(), imageData: SharedStore.stickerData()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StickerEntry>) -> Void) {
        // 스티커는 앱에서 저장할 때만 바뀌므로 자동 새로고침(.never) — 갱신은 saveSticker가 요청
        let entry = StickerEntry(date: Date(), imageData: SharedStore.stickerData())
        completion(Timeline(entries: [entry], policy: .never))
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
                    .foregroundStyle(.primary)
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
                            .font(.system(size: 26))
                        Text("앱에서 스티커를\n만들어 주세요")
                            .font(.system(size: 11, weight: .semibold))
                            .multilineTextAlignment(.center)
                    }
                    .foregroundStyle(.secondary)
                    .padding(.top, geo.size.height * 0.12)
                }
            }
        }
        // 투명 배경 — 홈 화면 배경이 그대로 비침
        .containerBackground(.clear, for: .widget)
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
    StickerEntry(date: Date(), imageData: nil)
}
