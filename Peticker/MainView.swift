import SwiftUI

struct MainView: View {
    @Environment(AppRouter.self) var router
    @State private var showComingSoon = false
    @State private var showGuide = false

    var body: some View {
        ZStack {
            Color.bgBase.ignoresSafeArea()

            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height

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

                // 청록 추가 원 — 중앙 우측
                Circle()
                    .fill(Color.brandCyan)
                    .frame(width: w * 0.72)
                    .overlay {
                        Image(systemName: "plus")
                            .font(.system(size: 52, weight: .ultraLight))
                            .foregroundStyle(Color.black)
                    }
                    .position(x: w * 0.540, y: h * 0.524)

                // 라임 잠금 슬롯 — 좌하단
                LockedSlot(size: 105, color: .brandLime)
                    .position(x: w * 0.340, y: h * 0.843)
                    .onTapGesture { showComingSoon = true }
            }
        }
        .overlay {
            if showComingSoon {
                ComingSoonOverlay { showComingSoon = false }
            }
        }
        .overlay {
            if showGuide {
                MainGuideOverlay()
                    .transition(.opacity)
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

struct MainGuideOverlay: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                Color.black.opacity(0.6)
                    .ignoresSafeArea()

                VStack(spacing: 10) {
                    Text("Click to add your widget!")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)

                    Image(systemName: "arrow.down")
                        .font(.system(size: 20, weight: .light))
                        .foregroundStyle(.white)
                }
                .position(x: w * 0.557, y: h * 0.315)
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

#Preview("Main Guide Overlay") {
    ZStack {
        Color.bgBase.ignoresSafeArea()
        MainGuideOverlay()
    }
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
