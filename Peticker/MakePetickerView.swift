import SwiftUI
import PhotosUI

// 사진 선택 후 제작 화면으로 넘겨줄 원본 이미지 래퍼
struct PickedPhoto: Identifiable {
    let id = UUID()
    let image: UIImage
}

// 색 팔레트 (Figma 55:1696 하단 6색) — Background·Outline 두 행이 함께 사용
enum PaletteColor: CaseIterable, Identifiable {
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

    // 이 색 위에 얹는 전경색(체크 표시·배터리 텍스트) — 검정 위엔 흰색, 그 외엔 검정
    var contrastColor: Color { self == .black ? .white : .black }
}

// 4단계 — 제작 화면: 누끼·스트로크 처리(Processing) → 완성 후 테두리 색 선택
struct MakePetickerView: View {
    let onClose: () -> Void

    @State private var currentImage: UIImage         // 현재 처리 대상 원본(사진 변경 시 교체)
    @State private var cutout: UIImage?              // 누끼 결과(테두리 없음)
    @State private var sticker: UIImage?             // 현재 색 테두리 적용 결과
    @State private var selectedStroke: PaletteColor = .cyan     // 스티커 테두리 색
    @State private var selectedBackground: PaletteColor = .white // 위젯 배경색
    @State private var isProcessing = true
    @State private var showChangeButton = false      // 원 탭 시 딤 + Change 버튼 표시
    @State private var pickerItem: PhotosPickerItem? // 사진 다시 고르기

    init(originalImage: UIImage, onClose: @escaping () -> Void) {
        _currentImage = State(initialValue: originalImage)
        self.onClose = onClose
    }

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
            await processImage()
        }
        .onChange(of: pickerItem) { _, newItem in
            guard let newItem else { return }
            Task {
                guard let data = try? await newItem.loadTransferable(type: Data.self),
                      let uiImage = UIImage(data: data) else { return }
                await MainActor.run {
                    currentImage = uiImage
                    showChangeButton = false
                    withAnimation(.easeOut(duration: 0.2)) { isProcessing = true }
                }
                await processImage()
            }
        }
    }

    // 현재 원본으로 누끼 → 선택 색 테두리 적용 (첫 진입·사진 변경 시 공통)
    private func processImage() async {
        cutout = await BackgroundRemover.removeBackground(from: currentImage)
        await restroke()
        await MainActor.run {
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
            Spacer().frame(height: min(42, size.height * 0.06))   // 디자인: Outline 행 ↔ DONE 42
            doneButton
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, size.height * 0.09)   // 상단 바 아래 여백
        .padding(.bottom, 24)
    }

    // 홈 화면 위젯처럼 보이는 원(배경색은 Background 팔레트) + 스티커
    private func widgetPreview(diameter d: CGFloat) -> some View {
        // 사진 배치 안전 영역: 상단 배터리 영역을 침범하지 않도록
        // 세로로 긴 사진도 이 상단선(safeTop) 아래에서만 시작하도록 고정한다.
        let safeTop: CGFloat = d * 0.24      // 배터리 아래 여백 확보
        let safeBottom: CGFloat = d * 0.90
        let photoHeight = safeBottom - safeTop
        let photoOffsetY = (safeTop + safeBottom) / 2 - d / 2   // 안전 영역 중앙으로 이동

        return ZStack {
            Circle()
                .fill(showChangeButton ? Color(white: 0.55) : selectedBackground.color)
                .frame(width: d, height: d)

            // 스티커 — 배터리 아래 안전 영역에 배치
            stickerImage
                .frame(width: d * 0.76, height: photoHeight)
                .offset(y: photoOffsetY)

            // 배터리 + 100% — 원 상단 근처 (변경 모드에선 숨김)
            if !showChangeButton {
                VStack(spacing: 0) {
                    HStack(spacing: 5) {
                        Image(systemName: "battery.100")
                            .font(.system(size: 15))
                        Text("100%")
                            .font(.system(size: 15, weight: .bold))
                    }
                    // 검정 배경에서도 배터리·100%가 보이도록 대비색 사용
                    .foregroundStyle(selectedBackground.contrastColor)
                    .padding(.top, d * 0.14)
                    Spacer()
                }
                .frame(width: d, height: d)
            }

            // 딤 + Change 버튼 — 원을 탭하면 표시
            if showChangeButton {
                changeOverlay(diameter: d)
            }
        }
        .frame(width: d, height: d)
        .contentShape(Circle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) { showChangeButton.toggle() }
        }
    }

    // 원 위 딤 처리 + 사진 다시 고르기 버튼
    private func changeOverlay(diameter d: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.15))
                .frame(width: d, height: d)

            PhotosPicker(selection: $pickerItem, matching: .images) {
                VStack(spacing: 8) {
                    Text("Change")
                        .font(.system(size: 20, weight: .bold))
                    Image("ChangeIcon")
                        .renderingMode(.template)   // 흰색 픽셀 아이콘 틴트
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                }
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
    }

    private var stickerImage: some View {
        Group {
            if let sticker {
                Image(uiImage: sticker).resizable().scaledToFit()
            } else {
                // 누끼 실패 시 원본 표시
                Image(uiImage: currentImage).resizable().scaledToFit()
            }
        }
    }

    // MARK: - 팔레트 (Figma 55:1696 — Background / Outline 두 행)

    private let paletteInset: CGFloat = 24      // 좌우 여백
    private let swatchSpacing: CGFloat = 12.6   // (327 - 44*6) / 5
    private let maxSwatchSize: CGFloat = 44

    private func palette(width: CGFloat) -> some View {
        let n = CGFloat(PaletteColor.allCases.count)
        // 사용 가능한 폭에 맞춰 스와치 크기 조정(좁은 기기에서 잘리지 않도록), 최대 44
        let size = min(maxSwatchSize, (width - paletteInset * 2 - swatchSpacing * (n - 1)) / n)
        return VStack(alignment: .leading, spacing: 0) {
            paletteLabel("Background")
            Spacer().frame(height: 7)
            swatchRow(size: size, selection: selectedBackground) { picked in
                selectedBackground = picked   // 위젯 배경색 — 재합성 불필요
            }
            Spacer().frame(height: 17)
            paletteLabel("Outline")
            Spacer().frame(height: 7)
            swatchRow(size: size, selection: selectedStroke) { picked in
                selectedStroke = picked
                Task { await restroke() }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, paletteInset)
    }

    private func paletteLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .tracking(-0.5)
            .foregroundStyle(.black)
    }

    private func swatchRow(
        size: CGFloat,
        selection: PaletteColor,
        onPick: @escaping (PaletteColor) -> Void
    ) -> some View {
        HStack(spacing: swatchSpacing) {
            ForEach(PaletteColor.allCases) { swatch in
                swatchView(swatch, size: size, isSelected: swatch == selection) {
                    onPick(swatch)
                }
            }
        }
    }

    private func swatchView(
        _ swatch: PaletteColor,
        size: CGFloat,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
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
                            .foregroundStyle(swatch.contrastColor)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    // DONE — 140x48 캡슐, 1pt 검정 테두리 (Figma 119:1802)
    private var doneButton: some View {
        Button(action: saveAndClose) {
            Text("DONE")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.black)
                .frame(width: 140, height: 48)
                .overlay { Capsule().stroke(Color.black, lineWidth: 1) }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // 현재 선택된 색으로 테두리 다시 입힘 (누끼 결과 재사용 — 빠름)
    private func restroke() async {
        guard let cutout else { return }
        sticker = await StickerStyler.addStroke(to: cutout, color: selectedStroke.uiColor)
    }

    // DONE — 배경색과 완성 스티커를 공유 저장소에 저장(위젯이 읽어 표시)한 뒤 화면 닫기
    private func saveAndClose() {
        SharedStore.saveBackgroundColor(selectedBackground.uiColor)
        if let sticker {
            SharedStore.saveSticker(sticker)
        }
        onClose()
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
