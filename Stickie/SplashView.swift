import SwiftUI

private struct StickieLetter {
    let assetName: String
    let x: CGFloat        // fraction of available width
    let y: CGFloat        // fraction of available height
    let size: CGFloat     // asset diameter, fraction of available width
    let rotation: Double
}

private let stickieLetters: [StickieLetter] = [
    StickieLetter(assetName: "SplashS",      x: 0.22, y: 0.31, size: 0.40, rotation: -19.6),
    StickieLetter(assetName: "SplashT",      x: 0.65, y: 0.18, size: 0.37, rotation: 12.7),
    StickieLetter(assetName: "SplashICyan",  x: 0.83, y: 0.28, size: 0.50, rotation: 12.6),
    StickieLetter(assetName: "SplashC",      x: 0.61, y: 0.49, size: 0.40, rotation: 21.4),
    StickieLetter(assetName: "SplashK",      x: 0.26, y: 0.64, size: 0.34, rotation: 5.6),
    StickieLetter(assetName: "SplashIYellow", x: 0.52, y: 0.87, size: 0.41, rotation: -22.7),
    StickieLetter(assetName: "SplashE",      x: 0.81, y: 0.77, size: 0.35, rotation: 8.2),
]

struct SplashView: View {
    @Environment(AppRouter.self) var router
    @State private var showSmallLogo = true
    @State private var visibleLetterCount = 0

    var body: some View {
        ZStack {
            Color.bgBase.ignoresSafeArea()

            // 모인 상태 (시작)
            Image("StickieLogo")
                .resizable()
                .scaledToFit()
                .padding(.horizontal, 32)
                .offset(y: -70)
                .opacity(showSmallLogo ? 1 : 0)

            // 흩어진 상태 (끝) — 글자가 순서대로 하나씩 튀어나온다
            GeometryReader { geo in
                ForEach(Array(stickieLetters.enumerated()), id: \.offset) { index, letter in
                    let isVisible = index < visibleLetterCount
                    let diameter = geo.size.width * letter.size

                    // Figma 익스포트 에셋 — 그림자가 이미지에 포함되어 있어 별도 배경/그림자가 필요 없다.
                    Image(letter.assetName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: diameter, height: diameter)
                        .rotationEffect(.degrees(letter.rotation + (isVisible ? 0 : 24)))
                        .scaleEffect(isVisible ? 1 : 0.2)
                        .opacity(isVisible ? 1 : 0)
                        .position(x: geo.size.width * letter.x, y: geo.size.height * letter.y)
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 32)
            .opacity(showSmallLogo ? 0 : 1)

            VStack {
                Spacer()
                Text("Make your own Stickie!")
                    .font(.stickieTagline)
                    .foregroundStyle(Color.gray)
                    .opacity(showSmallLogo ? 1 : 0)
                    .padding(.bottom, 2)
            }
        }
        .task {
            #if DEBUG
            UserDefaults.standard.removeObject(forKey: "hasSeenOnboarding")
            UserDefaults.standard.removeObject(forKey: "hasSeenBatteryGuide")
            SharedStore.resetForDebug()   // 이전 테스트 스티커 잔재를 지우고 메인 화면을 항상 파란 원으로 시작
            #endif
            // 로고 상태 유지
            try? await Task.sleep(for: .milliseconds(900))
            // 작은 로고 → 흩어진 글자로 전환
            withAnimation(.easeOut(duration: 0.25)) { showSmallLogo = false }
            try? await Task.sleep(for: .milliseconds(200))
            // 알파벳 순서대로 하나씩 발랄하게 튀어나오기
            for i in 0..<stickieLetters.count {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.55)) {
                    visibleLetterCount = i + 1
                }
                try? await Task.sleep(for: .milliseconds(210))
            }
            // 잠시 감상 후 이동
            try? await Task.sleep(for: .milliseconds(600))
            let seen = UserDefaults.standard.bool(forKey: "hasSeenOnboarding")
            router.navigateTo(seen ? .main : .onboarding)
        }
    }
}

#Preview {
    SplashView()
        .environment(AppRouter())
}
