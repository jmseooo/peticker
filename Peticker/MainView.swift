import SwiftUI
import PhotosUI

struct MainView: View {
    @Environment(AppRouter.self) var router
    @State private var showComingSoon = false
    @State private var showGuide = false
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var isProcessing = false

    var body: some View {
        ZStack {
            Color.bgBase.ignoresSafeArea()

            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height

                // 딤 아래 요소
                Group {
                    // Peticker 로고 — 상단 중앙
                    Image("PetickerLogo")
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

                // 청록 추가 버튼 — 딤 위
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    Circle()
                        .fill(Color.brandCyan)
                        .frame(width: w * 0.72)
                        .overlay {
                            Image("PlusIcon")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 110, height: 110)
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
        .overlay {
            if let selectedImage {
                PhotoPreviewOverlay(image: selectedImage) {
                    self.selectedImage = nil
                    self.selectedItem = nil
                }
            } else if isProcessing {
                ProcessingOverlay()
            }
        }
        .onChange(of: selectedItem) { _, newItem in
            guard let newItem else { return }
            isProcessing = true
            Task {
                guard let data = try? await newItem.loadTransferable(type: Data.self),
                      let uiImage = UIImage(data: data) else {
                    await MainActor.run { isProcessing = false }
                    return
                }
                // 배경 제거(누끼) 실행. 실패하면 원본을 그대로 보여줌.
                let cutout = await BackgroundRemover.removeBackground(from: uiImage)
                await MainActor.run {
                    selectedImage = cutout ?? uiImage
                    isProcessing = false
                }
            }
        }
        .onAppear {
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

// 누끼 처리 중 로딩 표시
struct ProcessingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .controlSize(.large)
                    .tint(.white)
                Text("배경 지우는 중…")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.white)
            }
        }
        .transition(.opacity)
    }
}

// 2단계 — 누끼(배경 제거) 결과 미리보기
struct PhotoPreviewOverlay: View {
    let image: UIImage
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                // 배경이 투명하게 지워졌으면 어두운 배경 위에 피사체만 떠 보임
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(.horizontal, 24)

                Button {
                    onDismiss()
                } label: {
                    Text("닫기")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.black)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
                }
            }
            .padding(.vertical, 40)
        }
        .transition(.opacity)
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
