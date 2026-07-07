import SwiftUI

// 사진 선택 후 제작 화면으로 넘겨줄 원본 이미지 래퍼
struct PickedPhoto: Identifiable {
    let id = UUID()
    let image: UIImage
}

// 테두리 색 팔레트 (Figma 55:1696 하단 6색)
enum StrokeColor: CaseIterable, Identifiable {
    case pink, lime, cyan, yellow, white, black

    var id: Self { self }

    var color: Color {
        switch self {
        case .pink:   return .brandPink
        case .lime:   return .brandLime
        case .cyan:   return .brandCyan
        case .yellow: return .brandYellow
        case .white:  return .white
        case .black:  return .black
        }
    }

    var uiColor: UIColor { UIColor(color) }

    // 선택 표시(체크) 색 — 검정 위엔 흰색, 그 외엔 검정
    var checkColor: Color { self == .black ? .white : .black }
}

// 4단계 — 제작 화면: 누끼·스트로크 처리(Processing) → 완성 후 테두리 색 선택
struct MakePetickerView: View {
    let originalImage: UIImage
    let onClose: () -> Void

    @State private var cutout: UIImage?              // 누끼 결과(테두리 없음)
    @State private var sticker: UIImage?             // 현재 색 테두리 적용 결과
    @State private var selectedColor: StrokeColor = .cyan
    @State private var isProcessing = true

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                if isProcessing {
                    processingContent
                } else {
                    readyContent(geo.size)
                }

                topBar
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        // 배경은 background로 분리 — 안전영역만 넘어가고 레이아웃(상단 바 위치)엔 영향 없음
        .background(Color.bgBase.ignoresSafeArea())
        .task {
            // 누끼 실행 후 기본 색(cyan) 테두리 적용
            cutout = await BackgroundRemover.removeBackground(from: originalImage)
            await restroke()
            withAnimation(.easeOut(duration: 0.3)) { isProcessing = false }
        }
    }

    // MARK: - 상단 바 (두 화면 공통) — 좌측 뒤로가기 + 중앙 타이틀

    // 디자인(Figma 55:1696) 기준 화면 최상단에서의 위치
    private let topBarY: CGFloat = 99      // 상단바 y (뒤로가기·타이틀 정렬)
    private let backButtonX: CGFloat = 24  // 뒤로가기 좌측 여백

    private var topBar: some View {
        ZStack(alignment: .topLeading) {
            backButton
                .offset(x: backButtonX, y: topBarY)
            if !isProcessing {
                titleLabel
                    .frame(maxWidth: .infinity, alignment: .center)  // 가로 중앙
                    .offset(y: topBarY)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .ignoresSafeArea()   // 화면 최상단 기준 절대 좌표 (디자인과 동일)
    }

    private var backButton: some View {
        Button(action: onClose) {
            Image("BackButton")
                .resizable()
                .scaledToFit()
                .frame(width: 29, height: 29)   // 라임 배경·좌향 화살표가 에셋에 포함
        }
        .buttonStyle(.plain)
    }

    private var titleLabel: some View {
        Text("MAKE PETICKER")
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(.black)
            .padding(.horizontal, 12)
            .frame(height: 29)
            .background(Color.brandLime)
    }

    // MARK: - Processing (Figma 55:1594)

    private var processingContent: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "sparkles")
                .font(.system(size: 30))
                .foregroundStyle(Color.brandCyan)
            Text("Processing…")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.black)
            Spacer()
            Text("Please do not close the app.")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.black)
                .padding(.bottom, 40)
        }
    }

    // MARK: - Ready (Figma 55:1696)

    private func readyContent(_ size: CGSize) -> some View {
        // 폭 기준 지름(디자인 281/375)에 높이 상한을 둬서 짧은 기기에서도 안 잘리게
        let diameter = min(size.width * 0.75, size.height * 0.42)
        return VStack(spacing: 0) {
            Spacer(minLength: 16)
            widgetPreview(diameter: diameter)
            Spacer(minLength: 16)
            palette(width: size.width)
            Spacer().frame(height: min(44, size.height * 0.06))
            Button(action: onClose) {        // TODO: 위젯 저장(M3) 연결 예정
                Text("DONE")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.black)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, size.height * 0.09)   // 상단 바 아래 여백
        .padding(.bottom, 24)
    }

    // 홈 화면 위젯처럼 보이는 흰 원 + 스티커
    private func widgetPreview(diameter d: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(.white)
                .frame(width: d, height: d)

            // 스티커 — 중앙보다 살짝 아래
            stickerImage
                .frame(width: d * 0.76, height: d * 0.76)
                .offset(y: d * 0.04)

            // 배터리 + 100% — 원 상단 근처
            VStack(spacing: 0) {
                HStack(spacing: 5) {
                    Image(systemName: "battery.100")
                        .font(.system(size: 15))
                    Text("100%")
                        .font(.system(size: 15, weight: .bold))
                }
                .foregroundStyle(.black)
                .padding(.top, d * 0.14)
                Spacer()
            }
            .frame(width: d, height: d)
        }
    }

    private var stickerImage: some View {
        Group {
            if let sticker {
                Image(uiImage: sticker).resizable().scaledToFit()
            } else {
                // 누끼 실패 시 원본 표시
                Image(uiImage: originalImage).resizable().scaledToFit()
            }
        }
    }

    private func palette(width: CGFloat) -> some View {
        let inset: CGFloat = 20
        let spacing: CGFloat = 12
        let n = CGFloat(StrokeColor.allCases.count)
        // 사용 가능한 폭에 맞춰 스와치 크기 조정(좁은 기기에서 잘리지 않도록), 최대 44
        let swatchSize = min(44, (width - inset * 2 - spacing * (n - 1)) / n)
        return HStack(spacing: spacing) {
            ForEach(StrokeColor.allCases) { swatch in
                swatchView(swatch, size: swatchSize)
            }
        }
        .padding(.horizontal, inset)
    }

    private func swatchView(_ swatch: StrokeColor, size: CGFloat) -> some View {
        let isSelected = swatch == selectedColor
        return Button {
            selectedColor = swatch
            Task { await restroke() }
        } label: {
            Circle()
                .fill(swatch.color)
                .frame(width: size, height: size)
                .overlay {
                    // 흰색 스와치는 회색 테두리로 구분
                    Circle().strokeBorder(Color.black.opacity(swatch == .white ? 0.15 : 0), lineWidth: 1)
                }
                .overlay {
                    if isSelected {
                        Image("CheckIcon")
                            .renderingMode(.template)   // 스와치 색에 따라 검정/흰색 틴트
                            .resizable()
                            .scaledToFit()
                            .frame(width: size * 0.5, height: size * 0.5)
                            .foregroundStyle(swatch.checkColor)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    // 현재 선택된 색으로 테두리 다시 입힘 (누끼 결과 재사용 — 빠름)
    private func restroke() async {
        guard let cutout else { return }
        sticker = await StickerStyler.addStroke(to: cutout, color: selectedColor.uiColor)
    }
}

// 캔버스 프리뷰용 샘플 이미지 (SF Symbol 렌더)
private func previewImage() -> UIImage {
    let config = UIImage.SymbolConfiguration(pointSize: 200)
    return UIImage(systemName: "cat.fill", withConfiguration: config)?
        .withTintColor(.darkGray, renderingMode: .alwaysOriginal) ?? UIImage()
}

#Preview("제작 화면") {
    MakePetickerView(originalImage: previewImage()) {}
}
