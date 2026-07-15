import SwiftUI

private struct StickieLetter {
    let char: String
    let color: Color
    let x: CGFloat        // fraction of available width
    let y: CGFloat        // fraction of available height
    let size: CGFloat     // circle diameter, fraction of available width
    let rotation: Double
}

private let stickieLetters: [StickieLetter] = [
    StickieLetter(char: "S", color: .brandPink,   x: 0.21, y: 0.19, size: 0.34, rotation: -6),
    StickieLetter(char: "t", color: .brandYellow, x: 0.58, y: 0.09, size: 0.31, rotation: 12),
    StickieLetter(char: "i", color: .brandCyan,   x: 0.74, y: 0.24, size: 0.31, rotation: -4),
    StickieLetter(char: "c", color: .brandLime,   x: 0.49, y: 0.48, size: 0.31, rotation: 5),
    StickieLetter(char: "k", color: .brandCyan,   x: 0.21, y: 0.68, size: 0.32, rotation: -10),
    StickieLetter(char: "i", color: .brandYellow, x: 0.50, y: 0.90, size: 0.31, rotation: 8),
    StickieLetter(char: "e", color: .brandPink,   x: 0.77, y: 0.81, size: 0.32, rotation: -5),
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
                    let diameter = geo.size.width * letter.size + 7

                    Text(letter.char)
                        .font(.system(size: diameter * 0.52, weight: .bold))
                        .foregroundStyle(Color.black)
                        .frame(width: diameter, height: diameter)
                        .background(
                            Circle()
                                .fill(letter.color)
                                .shadow(color: .black.opacity(0.18), radius: 6, x: 0, y: 4)
                        )
                        .rotationEffect(.degrees(letter.rotation + (isVisible ? 0 : 24)))
                        .scaleEffect(isVisible ? 1 : 0.2)
                        .opacity(isVisible ? 1 : 0)
                        .position(x: geo.size.width * letter.x, y: geo.size.height * letter.y)
                }
            }
            .padding(.horizontal, 56)
            .padding(.vertical, 40)
            .opacity(showSmallLogo ? 0 : 1)

            VStack {
                Spacer()
                Text("Make your own peticker")
                    .font(.petickerTagline)
                    .foregroundStyle(Color.gray)
                    .opacity(showSmallLogo ? 1 : 0)
                    .padding(.bottom, 52)
            }
        }
        .task {
            #if DEBUG
            UserDefaults.standard.removeObject(forKey: "hasSeenOnboarding")
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
                try? await Task.sleep(for: .milliseconds(110))
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
