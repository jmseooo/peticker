import SwiftUI
import PhotosUI
import WidgetKit

// 사진 선택 후 제작 화면으로 넘겨줄 원본 이미지 래퍼
struct PickedPhoto: Identifiable {
    let id = UUID()
    let image: UIImage
    var placement: StickerPlacement? = nil   // 다시 편집이면 이전 배치를 이어받는다
}

// 스와치 한 칸이 갖춰야 할 것 — Background·Outline 두 행이 같은 UI를 공유한다
protocol SwatchColor: CaseIterable, Identifiable, Equatable where AllCases: RandomAccessCollection {
    var hex: String { get }
    var isNone: Bool { get }   // '선 없음' 스와치 (색 대신 대각선 아이콘)
}

extension SwatchColor {
    var isNone: Bool { false }

    var id: String { hex }

    var color: Color { Color(hex: hex) }

    var uiColor: UIColor { UIColor(color) }

    // sRGB 상대 휘도(근사). SharedStore.widgetColors와 같은 기준.
    var luminance: CGFloat {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard uiColor.getRed(&r, green: &g, blue: &b, alpha: &a) else { return 1 }
        return 0.299 * r + 0.587 * g + 0.114 * b
    }

    // 이 색 위에 얹는 전경색(체크 표시·배터리 텍스트) — 어두운 색에선 흰색으로 뒤집는다
    var contrastColor: Color { luminance < 0.5 ? .white : .black }

    // 화면 배경(F5F5F5)과 잘 구분되지 않는 밝은 스와치는 테두리를 그린다
    var needsBorder: Bool { luminance > 0.92 }

    /// 공유 저장소에 저장된 색(sRGB)과 일치하는 스와치. 없거나 팔레트가 바뀌었으면 nil.
    static func matching(_ rgba: (red: Double, green: Double, blue: Double, alpha: Double)?) -> Self? {
        guard let c = rgba else { return nil }
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

// 위젯 배경 — 단색 6종 + 패턴 이미지 8종
enum BackgroundStyle: String, CaseIterable, Identifiable {
    // 단색 (rawValue = hex)
    case plum   = "5B1445"
    case olive  = "7E8714"
    case sky    = "2AC8F2"
    case butter = "F8F396"
    case paper  = "F6F6F6"
    case ink    = "343333"
    // 패턴 (rawValue = 이름)
    case dotsPlum     = "dots-plum"
    case dotsInk      = "dots-ink"
    case stripeBrown  = "stripe-brown"
    case stripeCream  = "stripe-cream"
    case paws         = "paws"
    case heartsCorner = "hearts-corner"
    case heartBig     = "heart-big"
    case gridOlive    = "grid-olive"

    var id: String { rawValue }

    // 패턴이면 에셋 이름, 단색이면 nil
    var patternAsset: String? {
        switch self {
        case .dotsPlum:     return "BgDotsPlum"
        case .dotsInk:      return "BgDotsInk"
        case .stripeBrown:  return "BgStripeBrown"
        case .stripeCream:  return "BgStripeCream"
        case .paws:         return "BgPaws"
        case .heartsCorner: return "BgHeartsCorner"
        case .heartBig:     return "BgHeartBig"
        case .gridOlive:    return "BgGridOlive"
        default:            return nil
        }
    }

    // 대표 바탕색 — 단색은 그 색, 패턴은 배경 바탕색(전경 대비 계산·폴백용)
    var baseHex: String {
        switch self {
        case .dotsPlum:     return "5B1445"
        case .dotsInk:      return "1A1A1A"
        case .stripeBrown:  return "5A3D34"
        case .stripeCream:  return "FFFFFF"
        case .paws:         return "AEE0F5"
        case .heartsCorner: return "F8D9EC"
        case .heartBig:     return "F55CB8"
        case .gridOlive:    return "7B8B0F"
        default:            return rawValue
        }
    }

    var baseColor: Color { Color(hex: baseHex) }
    var uiColor: UIColor { UIColor(baseColor) }

    private var luminance: CGFloat {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard uiColor.getRed(&r, green: &g, blue: &b, alpha: &a) else { return 1 }
        return 0.299 * r + 0.587 * g + 0.114 * b
    }

    // 배경 위에 얹는 전경색(배터리 표시·체크) — 어두운 바탕에선 흰색
    var foreground: Color { luminance < 0.5 ? .white : .black }

    // 화면 배경(F5F5F5)과 잘 구분되지 않는 밝은 바탕은 스와치에 테두리를 그린다
    var needsBorder: Bool { luminance > 0.90 }

    static func saved() -> BackgroundStyle? {
        SharedStore.backgroundName().flatMap(BackgroundStyle.init(rawValue:))
    }
}

/// 배경 채움 — 패턴이면 이미지를 꽉 채우고, 단색이면 색을 칠한다. 호출부에서 원/사각으로 클리핑한다.
struct BackgroundFill: View {
    let patternAsset: String?
    let color: Color

    var body: some View {
        if let patternAsset {
            Image(patternAsset)
                .resizable()
                .scaledToFill()
        } else {
            color
        }
    }
}

// 스티커 테두리 색 팔레트. none은 테두리 없음.
enum OutlineColor: String, SwatchColor {
    case pink   = "FF2DA0"
    case lime   = "CAFF39"
    case cyan   = "3DD6F5"
    case yellow = "F5E63D"
    case white  = "FFFFFF"
    case black  = "000000"
    case none   = "none"

    var hex: String { rawValue }             // none은 "none" → 흰색으로 폴백(대각선 아이콘이 덮음)
    var isNone: Bool { self == .none }

    // 색 이름(rawValue)으로 저장·복원. none도 그대로 저장된다.
    static func saved() -> OutlineColor? {
        SharedStore.outlineName().flatMap(OutlineColor.init(rawValue:))
    }
}

/// 스티커의 불투명 픽셀 분포. 사각 바운딩박스가 아니라 실제 그림이 차지하는 범위를 잰다.
/// 박스 모서리는 대개 투명하므로, 이 값을 쓰면 원 밖으로 나가지 않으면서 훨씬 크게 채울 수 있다.
struct StickerMetrics {
    /// 세로 열 하나의 불투명 구간 (이미지 중심 기준, pt)
    struct Column {
        let x: CGFloat
        let minY: CGFloat   // 위쪽 끝 (음수가 위)
        let maxY: CGFloat   // 아래쪽 끝
    }

    let imageSize: CGSize    // 원본 이미지 크기(pt)
    let topRise: CGFloat     // 이미지 중심에서 가장 위쪽 불투명 픽셀까지 거리(pt)
    let bottomDrop: CGFloat  // 이미지 중심에서 가장 아래쪽 불투명 픽셀까지 거리(pt)
    let columns: [Column]    // 원 안에 들어가는지 정확히 판정하기 위한 윤곽

    /// 알파 채널을 축소본으로 훑어 계산한다. 불투명 픽셀이 없으면 nil.
    /// 열마다 위·아래 끝만 남긴다 — 원 포함 판정은 각 열의 양 끝만 보면 충분하다.
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

        var columns: [Column] = []
        var topRise: CGFloat = 0
        var bottomDrop: CGFloat = 0

        for x in 0..<w {
            var minRow = h, maxRow = -1
            for y in 0..<h where pixels[(y * w + x) * 4 + 3] > 127 {
                minRow = min(minRow, y)
                maxRow = max(maxRow, y)
            }
            guard maxRow >= minRow else { continue }
            let dx = (CGFloat(x) + 0.5 - centerX) * fx
            let minY = (CGFloat(minRow) + 0.5 - centerY) * fy
            let maxY = (CGFloat(maxRow) + 0.5 - centerY) * fy
            columns.append(Column(x: dx, minY: minY, maxY: maxY))
            topRise = max(topRise, -minY)
            bottomDrop = max(bottomDrop, maxY)
        }
        guard !columns.isEmpty, topRise + bottomDrop > 0 else { return nil }
        return StickerMetrics(
            imageSize: image.size,
            topRise: topRise,
            bottomDrop: bottomDrop,
            columns: columns
        )
    }
}

/// 원형 위젯 프리뷰 안에서 스티커가 놓일 자리(크기 + 세로 이동량).
/// 두 조건을 동시에 만족시킨다.
///  1) 상단 배터리 표시 영역을 침범하지 않는다 — 불투명 픽셀은 safeTop 아래에만.
///  2) 스티커가 원 밖으로 나가지 않는다 — 모든 불투명 픽셀이 원 안.
///  3) 배터리 표시 아래(safeTop)부터 원 바닥까지의 구간에 세로 중앙정렬한다.
///     (원 중심에 맞추면 위쪽 배터리 여백 탓에 어떤 스티커든 올라가 보인다)
struct StickerCircleLayout {
    let size: CGSize      // 스티커 프레임 크기
    let offsetY: CGFloat  // 원 중심 기준 세로 이동량

    // 원 상단에서 잰, 배터리 표시가 차지하는 영역 (지름 대비 비율).
    // 디자인의 100% 텍스트 하단(0.178d) 아래로 여유를 둔 값.
    // 이 값이 스티커 크기를 좌우한다 — 원 중심 정렬이라 위쪽 여유가 곧 배율 상한이 되기 때문.
    private static let safeTopRatio: CGFloat = 0.20

    // 제약이 허락하는 최대치를 그대로 쓰면 가장자리에 딱 붙어 답답해 보이므로 줄인다
    private static let fillRatio: CGFloat = 0.88

    init(diameter d: CGFloat, metrics: StickerMetrics?) {
        let r = d / 2
        guard let metrics else {
            // 알파를 못 읽은 경우: 원에 확실히 들어가는 보수적인 정사각 크기
            self.size = CGSize(width: r, height: r)
            self.offsetY = 0
            return
        }

        let safeTop = Self.safeTopRatio * d
        // 배터리 표시 아래(safeTop) ~ 원 바닥 구간의 중앙 (원 중심 기준)
        let bandCenter = (safeTop + d) / 2 - r

        // 배율이 정해지면 위치도 정해진다 — 항상 구간 중앙에 놓는다.
        // 그림이 위아래로 비대칭일 수 있으므로 프레임이 아니라 불투명 영역의 중심을 맞춘다.
        func offset(for scale: CGFloat) -> CGFloat {
            bandCenter - scale * (metrics.bottomDrop - metrics.topRise) / 2
        }

        // 그 위치에서 그림이 원 안에 들어가고 배터리 표시도 안 가리는가.
        // 열마다 위·아래 끝만 보면 충분하다 (같은 열에서 가장 먼 점은 양 끝 중 하나).
        func fits(_ scale: CGFloat) -> Bool {
            let c = offset(for: scale)
            guard -scale * metrics.topRise + c >= safeTop - r else { return false }
            let limit = r * r
            for column in metrics.columns {
                let x = column.x * scale
                let top = column.minY * scale + c
                let bottom = column.maxY * scale + c
                if x * x + top * top > limit || x * x + bottom * bottom > limit { return false }
            }
            return true
        }

        // 구간 높이를 넘지 않는 선에서 최대 배율을 이분 탐색.
        // 배율을 줄이면 그림이 작아지고 중앙에 가까워지므로 fits는 단조롭다.
        var low: CGFloat = 0
        var high = (d - safeTop) / (metrics.topRise + metrics.bottomDrop)
        if !fits(high) {
            for _ in 0..<30 {
                let mid = (low + high) / 2
                if fits(mid) { low = mid } else { high = mid }
            }
        } else {
            low = high
        }

        let scale = low * Self.fillRatio
        self.size = CGSize(
            width: metrics.imageSize.width * scale,
            height: metrics.imageSize.height * scale
        )
        self.offsetY = offset(for: scale)
    }
}

/// 사용자가 핀치·드래그로 정한 스티커 배치. 지름 대비 비율이라 원/위젯 크기와 무관하다.
/// 스티커는 한 변이 `boxRatio × 지름`인 정사각 프레임에 scaledToFit으로 들어가고,
/// 원 중심에서 (offset × 지름)만큼 이동한다.
struct StickerPlacement: Equatable {
    var boxRatio: CGFloat        // 정사각 프레임 한 변 / 지름
    var offset: CGSize           // 원 중심 기준 이동량 / 지름

    static let scaleRange: ClosedRange<CGFloat> = 0.15...3.0
    static let offsetLimit: CGFloat = 1.0   // 각 축으로 지름의 ±1배까지 (원 밖은 크롭)

    /// 자동 배치(StickerCircleLayout)와 같은 초기 위치·크기. 비율이라 지름은 임의값이면 된다.
    static func fitted(_ metrics: StickerMetrics?) -> StickerPlacement {
        let d: CGFloat = 1000
        let layout = StickerCircleLayout(diameter: d, metrics: metrics)
        // scaledToFit 정사각 프레임이라 한 변 = 그림의 긴 변 (StickerCircleLayout.size의 큰 쪽)
        let box = max(layout.size.width, layout.size.height) / d
        return StickerPlacement(boxRatio: box, offset: CGSize(width: 0, height: layout.offsetY / d))
    }

    var clamped: StickerPlacement {
        StickerPlacement(
            boxRatio: min(max(boxRatio, Self.scaleRange.lowerBound), Self.scaleRange.upperBound),
            offset: CGSize(
                width: min(max(offset.width, -Self.offsetLimit), Self.offsetLimit),
                height: min(max(offset.height, -Self.offsetLimit), Self.offsetLimit)
            )
        )
    }

    /// 공유 저장소에서 읽어온 변환. 없으면 nil.
    static func saved() -> StickerPlacement? {
        guard let t = SharedStore.stickerTransform() else { return nil }
        return StickerPlacement(boxRatio: t.boxRatio, offset: CGSize(width: t.offsetX, height: t.offsetY))
    }
}

/// 화면(window)의 안전영역 인셋.
/// 이 화면은 fullScreenCover로 표시되는데 그 컨텍스트에선 GeometryProxy의 safeAreaInsets가
/// 0으로 내려와 상단 바가 상태바를 덮는다. 표시 방식에 흔들리지 않도록 창에서 직접 읽는다.
@MainActor
enum ScreenSafeArea {
    static var insets: UIEdgeInsets {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .safeAreaInsets ?? .zero
    }
}

// 4단계 — 제작 화면: 누끼·스트로크 처리(Processing) → 완성 후 테두리 색 선택
struct MakePetickerView: View {
    let onClose: () -> Void

    @State private var currentImage: UIImage         // 현재 처리 대상 원본(사진 변경 시 교체)
    @State private var cutout: UIImage?              // 누끼 결과(테두리 없음)
    @State private var sticker: UIImage?             // 현재 색 테두리 적용 결과
    @State private var metrics: StickerMetrics?      // 스티커 배치용 불투명 픽셀 분포(캐시)
    @State private var selectedStroke: OutlineColor               // 스티커 테두리 색
    @State private var selectedBackground: BackgroundStyle        // 위젯 배경(단색/패턴)
    @State private var isProcessing = true
    @State private var showChangeButton = false      // 원 탭 시 딤 + Change 버튼 표시
    @State private var showPhotoPicker = false       // Change 버튼 → 사진 선택기
    @State private var pickerItem: PhotosPickerItem?

    // 스티커 배치 — 핀치(크기)·드래그(위치). 원 밖은 클리핑된다.
    @State private var placement: StickerPlacement?  // nil이면 아직 자동 배치 미확정
    @GestureState private var pinch: CGFloat = 1     // 진행 중 핀치 배율
    @GestureState private var pan: CGSize = .zero    // 진행 중 드래그(지름 대비 비율)
    private let initialPlacement: StickerPlacement?  // 다시 편집 시 이어받을 배치

    init(
        originalImage: UIImage,
        initialPlacement: StickerPlacement? = nil,
        onClose: @escaping () -> Void
    ) {
        _currentImage = State(initialValue: originalImage)
        // 이전에 고른 색을 이어받는다 (다시 편집할 때 초기화되지 않도록)
        _selectedBackground = State(initialValue: BackgroundStyle.saved() ?? .paper)
        _selectedStroke = State(initialValue: OutlineColor.saved() ?? .cyan)
        self.initialPlacement = initialPlacement
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
        // 화면 전체를 좌표계로 삼고, 안전영역은 ScreenSafeArea로 직접 더한다.
        // (fullScreenCover에선 GeometryProxy의 safeAreaInsets를 신뢰할 수 없다)
        .ignoresSafeArea()
        .background(Color.bgBase.ignoresSafeArea())
        .task {
            await processImage()
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $pickerItem, matching: .images)
        .onChange(of: pickerItem) { _, newItem in
            guard let newItem else { return }
            Task {
                guard let data = try? await newItem.loadTransferable(type: Data.self),
                      let uiImage = UIImage(data: data) else { return }
                await MainActor.run {
                    currentImage = uiImage
                    showChangeButton = false
                    placement = nil   // 새 피사체이므로 자동 배치로 다시 정한다
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

    // 디자인(Figma 139:1602)은 상태바(47) 아래 22 지점에 상단 바를 둔다.
    // 상단 바와 본문 모두 안전영역 기준으로 배치한다 — 좌표계를 섞으면 기기마다 간격이 어긋난다.
    private let titleTopGap: CGFloat = 22   // 안전영역 상단 ↔ 상단 바
    private let topBarHeight: CGFloat = 29  // 타이틀·뒤로가기 높이
    private let backButtonX: CGFloat = 24   // 뒤로가기 좌측 여백

    // 화면 최상단에서 잰 상단 바의 y (상태바를 덮지 않도록 인셋만큼 내린다)
    private var topBarY: CGFloat { ScreenSafeArea.insets.top + titleTopGap }

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
        // 디자인(Figma 139:1602) 기준 세로 간격
        let gapToCircle: CGFloat = 77    // 상단 바 하단 ↔ 원
        let gapBelowCircle: CGFloat = 46 // 원 ↔ Background 라벨
        let gapToDone: CGFloat = 54      // Outline 행 ↔ DONE
        let bottomInset: CGFloat = 16

        // 상단 바와 같은 절대 좌표계(화면 최상단 기준)이므로 그 아래로 그대로 쌓는다
        let leading = topBarY + topBarHeight + gapToCircle

        // 하단 홈 인디케이터 위로 DONE이 들어오도록 남는 높이에 맞춰 원을 줄인다
        let paletteHeight = paletteHeight(width: size.width)
        let bottomLimit = size.height - ScreenSafeArea.insets.bottom - bottomInset
        let available = bottomLimit - leading - gapBelowCircle - paletteHeight - gapToDone - doneHeight
        let diameter = max(0, min(size.width * 0.75, available))

        // 간격을 고정해 위에서부터 쌓고, 남는 공간은 맨 아래 Spacer가 흡수한다
        return VStack(spacing: 0) {
            Spacer().frame(height: leading)
            widgetPreview(diameter: diameter)
            Spacer().frame(height: gapBelowCircle)
            palette(width: size.width)
            Spacer().frame(height: gapToDone)
            doneButton
            Spacer(minLength: 0)   // 남는 높이는 아래로
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // 지금 화면에 반영할 배치 (진행 중인 핀치·드래그를 얹는다)
    private var livePlacement: StickerPlacement {
        let base = placement ?? .fitted(metrics)
        return StickerPlacement(
            boxRatio: base.boxRatio * pinch,
            offset: CGSize(width: base.offset.width + pan.width, height: base.offset.height + pan.height)
        )
    }

    // 홈 화면 위젯처럼 보이는 원(배경색은 Background 팔레트) + 스티커.
    // 스티커는 핀치로 크기, 드래그로 위치를 조절한다. 원 밖은 클리핑된다.
    private func widgetPreview(diameter d: CGFloat) -> some View {
        let p = livePlacement
        let box = p.boxRatio * d

        return ZStack {
            // 배경 + 스티커를 원으로 클리핑 — 스티커가 원을 벗어나면 잘린다.
            // 배경은 지름에 고정한다 (안 그러면 스티커를 확대할 때 배경도 같이 커진다).
            ZStack {
                BackgroundFill(patternAsset: selectedBackground.patternAsset, color: selectedBackground.baseColor)
                    .frame(width: d, height: d)

                stickerImage
                    .frame(width: box, height: box)
                    .offset(x: p.offset.width * d, y: p.offset.height * d)
            }
            .frame(width: d, height: d)
            .clipShape(Circle())
            .contentShape(Circle())
            .gesture(manipulationGesture(diameter: d), isEnabled: sticker != nil && !showChangeButton)
            // 원을 탭하면 딤 + Change 버튼 (핀치·드래그와 구분되는 단일 탭)
            .onTapGesture {
                guard sticker != nil else { return }
                withAnimation(.easeInOut(duration: 0.2)) { showChangeButton.toggle() }
            }

            // 배터리 퍼센트 — 원 상단 근처 (변경 모드에선 숨김)
            if !showChangeButton {
                VStack(spacing: 0) {
                    Text("\(BatteryMonitor.shared.percent)%")
                        .font(.system(size: 15, weight: .bold))
                        // 어두운 배경에서도 보이도록 대비색 사용
                        .foregroundStyle(selectedBackground.foreground)
                        .padding(.top, d * 0.117)   // 디자인: 원 상단에서 33 (33/281)
                    Spacer()
                }
                .frame(width: d, height: d)
                .allowsHitTesting(false)   // 배터리 위에서도 스티커를 잡을 수 있게
            }

            // 딤 + Change 버튼 — 원을 탭하면 표시
            if showChangeButton {
                changeOverlay(diameter: d)
            }
        }
        .frame(width: d, height: d)
    }

    // 핀치(크기) + 드래그(위치). 두 제스처를 동시에 인식한다.
    private func manipulationGesture(diameter d: CGFloat) -> some Gesture {
        let magnify = MagnifyGesture()
            .updating($pinch) { value, state, _ in state = value.magnification }
            .onEnded { value in
                var base = placement ?? .fitted(metrics)
                base.boxRatio *= value.magnification
                placement = base.clamped
            }
        let drag = DragGesture()
            .updating($pan) { value, state, _ in
                state = CGSize(width: value.translation.width / d, height: value.translation.height / d)
            }
            .onEnded { value in
                var base = placement ?? .fitted(metrics)
                base.offset.width += value.translation.width / d
                base.offset.height += value.translation.height / d
                placement = base.clamped
            }
        return magnify.simultaneously(with: drag)
    }

    // 원 위 딤 + 사진 다시 고르기 버튼. 바깥(딤)을 탭하면 닫힌다.
    private func changeOverlay(diameter d: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.35))
                .frame(width: d, height: d)
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) { showChangeButton = false }
                }

            Button {
                showChangeButton = false
                showPhotoPicker = true
            } label: {
                VStack(spacing: 8) {
                    Text("Change")
                        .font(.system(size: 20, weight: .bold))
                    Image("ChangeIcon")
                        .renderingMode(.template)   // 흰색 픽셀 화살표 틴트
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

    // 스와치 크기 — 6개가 폭에 딱 맞는 크기(최대 44). 개수와 무관하게 고정이라
    // 7개 이상인 행은 가로 스크롤된다.
    private func swatchSize(width: CGFloat) -> CGFloat {
        let n: CGFloat = 6
        return min(maxSwatchSize, (width - paletteInset * 2 - swatchSpacing * (n - 1)) / n)
    }

    // 라벨 17 + 7 + 스와치 행 + 17 + 라벨 17 + 7 + 스와치 행
    private func paletteHeight(width: CGFloat) -> CGFloat {
        let size = swatchSize(width: width)
        return 17 + 7 + size + 17 + 17 + 7 + size
    }

    private func palette(width: CGFloat) -> some View {
        let size = swatchSize(width: width)
        return VStack(alignment: .leading, spacing: 0) {
            paletteLabel("Background")
                .padding(.horizontal, paletteInset)
            Spacer().frame(height: 7)
            backgroundSwatchRow(size: size)
            Spacer().frame(height: 17)
            paletteLabel("Outline")
                .padding(.horizontal, paletteInset)
            Spacer().frame(height: 7)
            swatchRow(size: size, selection: selectedStroke) { picked in
                selectedStroke = picked
                Task { await restroke() }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func paletteLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .tracking(-0.5)
            .foregroundStyle(.black)
    }

    // 배경 스와치 행 — 단색 + 패턴. 넘치면 가로 스크롤.
    private func backgroundSwatchRow(size: CGFloat) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: swatchSpacing) {
                ForEach(BackgroundStyle.allCases) { style in
                    backgroundSwatch(style, size: size, isSelected: style == selectedBackground) {
                        selectedBackground = style   // 배경만 바뀌므로 재합성 불필요
                    }
                }
            }
            .padding(.horizontal, paletteInset)
        }
        .scrollIndicators(.hidden)
    }

    private func backgroundSwatch(
        _ style: BackgroundStyle,
        size: CGFloat,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            BackgroundFill(patternAsset: style.patternAsset, color: style.baseColor)
                .frame(width: size, height: size)
                .clipShape(Circle())
                .overlay {
                    // 밝은 바탕은 화면 배경과 구분되도록 회색 테두리
                    Circle().strokeBorder(Color.black.opacity(style.needsBorder ? 0.15 : 0), lineWidth: 1)
                }
                .overlay {
                    if isSelected {
                        Image("CheckIcon")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: size * 0.5, height: size * 0.5)
                            .foregroundStyle(style.foreground)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    // 스와치를 원래 크기로 유지하고, 넘치면 가로 스크롤 (스크롤 표시줄 숨김).
    private func swatchRow<T: SwatchColor>(
        size: CGFloat,
        selection: T,
        onPick: @escaping (T) -> Void
    ) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: swatchSpacing) {
                ForEach(T.allCases) { swatch in
                    swatchView(swatch, size: size, isSelected: swatch == selection) {
                        onPick(swatch)
                    }
                }
            }
            .padding(.horizontal, paletteInset)
        }
        .scrollIndicators(.hidden)
    }

    private func swatchView<T: SwatchColor>(
        _ swatch: T,
        size: CGFloat,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Circle()
                .fill(swatch.color)
                .frame(width: size, height: size)
                .overlay {
                    if swatch.isNone {
                        // '선 없음' — 점선 원 테두리
                        Circle().strokeBorder(
                            Color.black,
                            style: StrokeStyle(lineWidth: 1.1, dash: [3, 3])
                        )
                    } else if swatch.needsBorder {
                        // 화면 배경과 구분이 안 되는 밝은 스와치(흰색)는 회색 테두리로 구분
                        Circle().strokeBorder(Color.black.opacity(0.15), lineWidth: 1)
                    }
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
    private let doneHeight: CGFloat = 48

    private var doneButton: some View {
        Button(action: saveAndClose) {
            Text("DONE")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.black)
                .frame(width: 140, height: doneHeight)
                .overlay { Capsule().stroke(Color.black, lineWidth: 1) }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // 현재 선택된 색으로 테두리 다시 입힘 (누끼 결과 재사용 — 빠름). none이면 테두리 없이 누끼만.
    private func restroke() async {
        guard let cutout else { return }
        let restroked: UIImage?
        if selectedStroke.isNone {
            restroked = cutout
        } else {
            restroked = await StickerStyler.addStroke(to: cutout, color: selectedStroke.uiColor)
        }
        let newMetrics = restroked.flatMap(StickerMetrics.analyze)
        sticker = restroked
        metrics = newMetrics
        // 첫 배치가 아직 없으면 정한다 — 다시 편집이면 이전 배치, 아니면 자동 배치.
        // 이미 사용자가 핀치·드래그로 옮겼다면(placement != nil) 색만 바뀐 것이므로 유지한다.
        if placement == nil {
            placement = initialPlacement ?? .fitted(newMetrics)
        }
    }

    // DONE — 완성 스티커·배경색·배치를 공유 저장소에 저장(위젯이 읽어 표시)한 뒤 화면 닫기.
    // 원본 사진과 테두리 색도 함께 남겨, 메인 화면에서 스티커를 탭하면 다시 편집할 수 있게 한다.
    private func saveAndClose() {
        SharedStore.saveOriginal(currentImage)
        SharedStore.saveOutlineName(selectedStroke.rawValue)
        SharedStore.saveBackground(
            name: selectedBackground.rawValue,
            patternAsset: selectedBackground.patternAsset,
            color: selectedBackground.uiColor,
            foreground: UIColor(selectedBackground.foreground)
        )
        if let placement {
            SharedStore.saveStickerTransform(
                boxRatio: placement.boxRatio,
                offsetX: placement.offset.width,
                offsetY: placement.offset.height
            )
        }
        if let sticker {
            SharedStore.saveSticker(sticker)
        }
        // 모든 저장이 끝난 뒤 홈·잠금화면 위젯을 한 번 더 확실히 갱신
        WidgetCenter.shared.reloadAllTimelines()
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
