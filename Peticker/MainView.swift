import SwiftUI
import PhotosUI

/// 홈 화면 위젯처럼 보이는 원 — 완성 스티커가 있으면 그 모습, 없으면 청록 추가 버튼.
/// 별도 View로 둔다 (MainView의 메서드로 두면 MainActor 격리가 번져 GeometryReader 클로저에서 못 쓴다).
struct WidgetCircle: View {
    let diameter: CGFloat
    let sticker: UIImage?
    let metrics: StickerMetrics?
    let placement: StickerPlacement?   // 사용자가 정한 배치 (없으면 자동)
    let background: Color
    let foreground: Color
    let batteryPercent: Int

    var body: some View {
        Circle()
            .fill(sticker == nil ? Color.brandCyan : background)
            .frame(width: diameter)
            .overlay {
                if let sticker {
                    ZStack {
                        // 스티커 — 사용자 배치가 있으면 그대로, 없으면 자동 배치. 원 밖은 잘린다.
                        stickerLayer(sticker)

                        // 배터리 퍼센트 — 원 상단 근처 (스티커 위)
                        VStack(spacing: 0) {
                            Text("\(batteryPercent)%")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(foreground)
                                .padding(.top, diameter * 0.117)   // 제작 화면과 동일 비율
                            Spacer()
                        }
                    }
                    .frame(width: diameter, height: diameter)
                } else {
                    Image("PlusIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 110, height: 110)
                }
            }
            .clipShape(Circle())
    }

    @ViewBuilder
    private func stickerLayer(_ sticker: UIImage) -> some View {
        let image = Image(uiImage: sticker).resizable().scaledToFit()
        if let p = placement {
            let box = p.boxRatio * diameter
            image
                .frame(width: box, height: box)
                .offset(x: p.offset.width * diameter, y: p.offset.height * diameter)
        } else {
            // 예전 스티커(배치 정보 없음) — 자동 배치
            let layout = StickerCircleLayout(diameter: diameter, metrics: metrics)
            image
                .frame(width: layout.size.width, height: layout.size.height)
                .offset(y: layout.offsetY)
        }
    }
}

struct MainView: View {
    @Environment(AppRouter.self) var router
    @State private var showComingSoon = false
    @State private var showGuide = false
    @State private var selectedItem: PhotosPickerItem?
    @State private var pickedPhoto: PickedPhoto?
    @State private var isLoadingPhoto = false
    @State private var savedSticker: UIImage?   // 완성 후 청록 원에 표시할 스티커(위젯과 동일 결과)
    @State private var savedOriginal: UIImage?  // 다시 편집할 원본 사진 (없으면 편집 불가)
    @State private var stickerMetrics: StickerMetrics?   // 스티커 배치용 불투명 픽셀 분포(캐시)
    @State private var stickerPlacement: StickerPlacement?  // 사용자가 정한 배치
    @State private var widgetBackground: Color = .white   // 제작 화면에서 고른 위젯 배경색
    @State private var widgetForeground: Color = .black   // 그 위에 얹는 배터리 표시 색

    // 저장된 스티커와 배경색을 함께 읽어 미리보기를 위젯과 같은 모습으로 맞춘다
    private func reloadWidgetPreview() {
        savedSticker = SharedStore.loadSticker()
        savedOriginal = SharedStore.loadOriginal()
        stickerMetrics = savedSticker.flatMap(StickerMetrics.analyze)
        stickerPlacement = StickerPlacement.saved()
        let colors = SharedStore.widgetColors()
        widgetBackground = colors.background
        widgetForeground = colors.foreground
    }

    var body: some View {
        ZStack {
            Color.bgBase.ignoresSafeArea()

            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height

                // 딤 아래 요소
                Group {
                    // Stickie 로고 — 상단 중앙
                    Image("StickieLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 38)
                        .position(x: w / 2, y: 30)

                    // 핑크 잠금 슬롯 — 좌상단
                    LockedSlot(size: 149, color: .brandPink)
                        .position(x: w * 0.242, y: h * 0.228)
                        .onTapGesture { showComingSoon = true }

                    // 라임 잠금 슬롯 — 좌하단
                    LockedSlot(size: 105, color: .brandLime)
                        .position(x: w * 0.340, y: h * 0.843)
                        .onTapGesture { showComingSoon = true }
                }

                // 딤 레이어 — 잠금 슬롯 위, 청록 원 아래 (Figma 55:1376)
                if showGuide {
                    Color.black.opacity(0.6)
                        .ignoresSafeArea()
                        .transition(.opacity)
                }

                // 원 — 딤 위. 완성 스티커를 탭하면 수정 뷰로, 없으면 사진 선택.
                let circle = WidgetCircle(
                    diameter: w * 0.72,
                    sticker: savedSticker,
                    metrics: stickerMetrics,
                    placement: stickerPlacement,
                    background: widgetBackground,
                    foreground: widgetForeground,
                    batteryPercent: BatteryMonitor.shared.percent
                )
                Group {
                    if let savedOriginal {
                        // 완성 스티커를 탭하면 원본을 다시 불러 수정 뷰로 (이전 배치를 이어받는다)
                        Button {
                            pickedPhoto = PickedPhoto(image: savedOriginal, placement: stickerPlacement)
                        } label: { circle }
                    } else {
                        // 원본이 없으면(첫 제작이거나 원본 저장 이전 버전) 사진을 고르게 한다
                        PhotosPicker(selection: $selectedItem, matching: .images) { circle }
                    }
                }
                .buttonStyle(.plain)
                .position(x: w * 0.540, y: h * 0.524)

                // 가이드 텍스트·화살표 — 청록 원 위
                if showGuide {
                    MainGuideOverlay()
                        .transition(.opacity)
                }
            }
        }
        .overlay {
            if showComingSoon {
                ComingSoonOverlay { showComingSoon = false }
            }
        }
        .fullScreenCover(item: $pickedPhoto) { photo in
            MakePetickerView(originalImage: photo.image, initialPlacement: photo.placement) {
                pickedPhoto = nil
                selectedItem = nil
                reloadWidgetPreview()   // 완성 결과(스티커·배경색·배치)를 원에 반영
            }
        }
        .onChange(of: selectedItem) { _, newItem in
            guard let newItem else { return }
            isLoadingPhoto = true
            Task {
                // 원본 사진만 불러오고, 누끼·스트로크는 제작 화면에서 처리
                defer { Task { @MainActor in isLoadingPhoto = false } }
                guard let data = try? await newItem.loadTransferable(type: Data.self),
                      let uiImage = UIImage(data: data) else { return }
                await MainActor.run {
                    pickedPhoto = PickedPhoto(image: uiImage)
                }
            }
        }
        .onAppear {
            reloadWidgetPreview()   // 이전에 만든 스티커가 있으면 저장된 배경색과 함께 표시
            showGuide = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation(.easeOut(duration: 0.4)) {
                    showGuide = false
                }
            }
        }
    }
}


struct LockedSlot: View {
    let size: CGFloat
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(style: StrokeStyle(lineWidth: 2.5, dash: [6, 4]))
                .foregroundStyle(color)
                .frame(width: size, height: size)
            Image(systemName: "lock.fill")
                .font(.system(size: size * 0.2))
                .foregroundStyle(color)
        }
    }
}

struct ComingSoonOverlay: View {
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            Text("Coming Soon!")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 16)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }
}

#Preview {
    MainView()
        .environment(AppRouter())
}


#Preview("Coming Soon") {
    ComingSoonOverlay {}
}

#Preview("Locked Slot") {
    HStack(spacing: 40) {
        LockedSlot(size: 149, color: .brandPink)
        LockedSlot(size: 105, color: .brandLime)
    }
    .padding()
    .background(Color.bgBase)
}
