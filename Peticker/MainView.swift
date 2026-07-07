import SwiftUI
import PhotosUI

struct MainView: View {
    @Environment(AppRouter.self) var router
    @State private var showComingSoon = false
    @State private var showGuide = false
    @State private var selectedItem: PhotosPickerItem?

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
