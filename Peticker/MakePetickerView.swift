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

    // 공유 저장소에 저장된 배경색과 일치하는 팔레트 색. 아직 고른 적 없으면 nil.
    static func savedBackground() -> PaletteColor? {
        guard let c = SharedStore.backgroundColorRGBA() else { return nil }
        return allCases.first { swatch in
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            guard swatch.uiColor.getRed(&r, green: &g, blue: &b, alpha: &a) else { return false }
            let tolerance = 0.01
            return abs(Double(r) - c.red) < tolerance
                && abs(Double(g) - c.green) < tolerance
                && abs(Double(b) - c.blue) < tolerance
        }
    }
}

/// 스티커의 불투명 픽셀 분포. 사각 바운딩박스가 아니라 실제 그림이 차지하는 범위를 잰다.
/// 박스 모서리는 대개 투명하므로, 이 값을 쓰면 원 밖으로 나가지 않으면서 훨씬 크게 채울 수 있다.
struct StickerMetrics {
    let imageSize: CGSize    // 원본 이미지 크기(pt)
    let radius: CGFloat      // 이미지 중심에서 가장 먼 불투명 픽셀까지 거리(pt)
    let topRise: CGFloat     // 이미지 중심에서 가장 위쪽 불투명 픽셀까지 거리(pt)
    let bottomDrop: CGFloat  // 이미지 중심에서 가장 아래쪽 불투명 픽셀까지 거리(pt)

    /// 알파 채널을 축소본으로 훑어 계산한다. 불투명 픽셀이 없으면 nil.
    static func analyze(_ image: UIImage) -> StickerMetrics? {
        guard let cg = image.cgImage, image.size.width > 0, image.size.height > 0 else { return nil }

        let scale = min(1, 128 / CGFloat(max(cg.width, cg.height)))
        let w = max(1, Int((CGFloat(cg.width) * scale).rounded()))
        let h = max(1, Int((CGFloat(cg.height) * scale).rounded()))

        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        guard let ctx = CGContext(
            data: &pixels,
            width: w, height: h,
            bitsPerComponent: 8, bytesPerRow: w * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))

        // 축소본 픽셀 거리를 원본 pt로 되돌리는 배율
        let fx = image.size.width / CGFloat(w)
        let fy = image.size.height / CGFloat(h)
        let centerX = CGFloat(w) / 2, centerY = CGFloat(h) / 2

        var radius: CGFloat = 0
        var topRise: CGFloat = 0
        var bottomDrop: CGFloat = 0
        var found = false

        for y in 0..<h {
            for x in 0..<w where pixels[(y * w + x) * 4 + 3] > 127 {
                found = true
                let dx = (CGFloat(x) + 0.5 - centerX) * fx
                let dy = (CGFloat(y) + 0.5 - centerY) * fy
                radius = max(radius, sqrt(dx * dx + dy * dy))
                topRise = max(topRise, -dy)     // 중심보다 위쪽(dy < 0)인 거리
                bottomDrop = max(bottomDrop, dy) // 중심보다 아래쪽(dy > 0)인 거리
            }
        }
        guard found, radius > 0 else { return nil }
        return StickerMetrics(
            imageSize: image.size,
            radius: radius,
            topRise: topRise,
            bottomDrop: bottomDrop
        )
    }
}

/// 원형 위젯 프리뷰 안에서 스티커가 놓일 자리(크기 + 세로 이동량).
/// 세 조건을 동시에 만족시킨다.
///  1) 상단 배터리 표시 영역을 침범하지 않는다 — 불투명 픽셀은 safeTop 아래에만.
///  2) 스티커가 원 밖으로 나가지 않는다 — 모든 불투명 픽셀이 원 안.
///  3) 배터리 표시 아래부터 원 바닥까지의 구간에 세로 중앙정렬한다.
///     (원 중심에 맞추면 위쪽에 배터리 여백이 있어 스티커가 올라가 보인다)
struct StickerCircleLayout {
    let size: CGSize      // 스티커 프레임 크기
    let offsetY: CGFloat  // 원 중심 기준 세로 이동량

    // 원 상단에서 잰, 배터리 표시가 차지하는 영역 (지름 대비 비율).
    // 이 값이 스티커 크기를 좌우한다 — 위쪽 여유가 곧 배율 상한이 되기 때문.
    private static let safeTopRatio: CGFloat = 0.13

    // 제약이 허락하는 최대치를 그대로 쓰면 가장자리에 딱 붙어 답답해 보이므로 살짝 줄인다
    private static let fillRatio: CGFloat = 0.94

    init(diameter d: CGFloat, metrics: StickerMetrics?) {
        let r = d / 2
        guard let metrics else {
            // 알파를 못 읽은 경우: 원에 확실히 들어가는 보수적인 정사각 크기
            self.size = CGSize(width: r, height: r)
            self.offsetY = 0
            return
        }

        // 원 안에 들어가도록 하는 배율
        let byCircle = r / metrics.radius

        // 위로 허용되는 거리 — 그림이 배터리 표시를 침범하지 않도록
        let allowedRise = r - Self.safeTopRatio * d
        let byTop = metrics.topRise > 0 ? allowedRise / metrics.topRise : .greatestFiniteMagnitude

        let scale = max(0, min(byCircle, byTop)) * Self.fillRatio
        self.size = CGSize(
            width: metrics.imageSize.width * scale,
            height: metrics.imageSize.height * scale
        )

        // 배터리 표시 아래(safeTop) ~ 원 바닥 구간의 중앙 (원 중심 기준)
        let bandCenter = (Self.safeTopRatio * d + d) / 2 - r

        // 그림이 위아래로 비대칭일 수 있으므로, 프레임이 아니라 불투명 영역의 중심을 맞춘다
        let contentCenter = scale * (metrics.bottomDrop - metrics.topRise) / 2
        let desired = bandCenter - contentCenter

        // 내려놓다가 원 밖으로 밀려나지 않도록 이동량을 제한한다
        let limit = max(0, r - scale * metrics.radius)
        self.offsetY = min(max(desired, -limit), limit)
    }
}

// 4단계 — 제작 화면: 누끼·스트로크 처리(Processing) → 완성 후 테두리 색 선택
struct MakePetickerView: View {
    let onClose: () -> Void

    @State private var currentImage: UIImage         // 현재 처리 대상 원본(사진 변경 시 교체)
    @State private var cutout: UIImage?              // 누끼 결과(테두리 없음)
    @State private var sticker: UIImage?             // 현재 색 테두리 적용 결과
    @State private var metrics: StickerMetrics?      // 스티커 배치용 불투명 픽셀 분포(캐시)
    @State private var selectedStroke: PaletteColor = .cyan      // 스티커 테두리 색
    @State private var selectedBackground: PaletteColor          // 위젯 배경색
    @State private var isProcessing = true
    @State private var showChangeButton = false      // 원 탭 시 딤 + Change 버튼 표시
    @State private var pickerItem: PhotosPickerItem? // 사진 다시 고르기

    init(originalImage: UIImage, onClose: @escaping () -> Void) {
        _currentImage = State(initialValue: originalImage)
        // 이전에 고른 배경색을 이어받는다 (DONE 시 흰색으로 되돌아가지 않도록)
        _selectedBackground = State(initialValue: PaletteColor.savedBackground() ?? .white)
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
        // 상단 배터리 표시를 피하면서 원 안에 완전히 들어가는, 중앙정렬 최대 크기
        let layout = StickerCircleLayout(diameter: d, metrics: metrics)

        return ZStack {
            Circle()
                .fill(showChangeButton ? Color(white: 0.55) : selectedBackground.color)
                .frame(width: d, height: d)

            // 스티커 — 배터리 표시 아래, 원 안쪽에 내접하도록 배치
            stickerImage
                .frame(width: layout.size.width, height: layout.size.height)
                .offset(y: layout.offsetY)

            // 배터리 퍼센트 — 원 상단 근처 (변경 모드에선 숨김)
            if !showChangeButton {
                VStack(spacing: 0) {
                    Text("\(BatteryMonitor.shared.percent)%")
                        .font(.system(size: 15, weight: .bold))
                        // 검정 배경에서도 보이도록 대비색 사용
                        .foregroundStyle(selectedBackground.contrastColor)
                        .padding(.top, d * 0.06)
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
        let restroked = await StickerStyler.addStroke(to: cutout, color: selectedStroke.uiColor)
        sticker = restroked
        // 테두리가 붙으면 불투명 영역이 넓어지므로 배치를 다시 잰다
        metrics = restroked.flatMap(StickerMetrics.analyze)
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
