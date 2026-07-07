import SwiftUI

struct SplashView: View {
    @Environment(AppRouter.self) var router
    @State private var assembled = false

    var body: some View {
        ZStack {
            Color.bgBase.ignoresSafeArea()

            // 모인 상태 (시작)
            Image("PetickerLogo")
                .resizable()
                .scaledToFit()
                .padding(.horizontal, 32)
                .opacity(assembled ? 0 : 1)

            // 흩어진 상태 (끝)
            Image("PetickerScattered")
                .resizable()
                .scaledToFit()
                .scaleEffect(assembled ? 1 : 0.88)
                .opacity(assembled ? 1 : 0)

            VStack {
                Spacer()
                Text("Make your own peticker")
                    .font(.petickerTagline)
                    .foregroundStyle(Color.gray)
                    .opacity(assembled ? 0 : 1)
                    .padding(.bottom, 52)
            }
        }
        .task {
            // 로고 상태 1초 유지
            try? await Task.sleep(for: .milliseconds(1000))
            // 흩어짐
            withAnimation(.spring(duration: 0.8, bounce: 0.2)) { assembled = true }
            // 남은 시간 대기 후 이동 (총 ~3초)
            try? await Task.sleep(for: .milliseconds(2000))
            let seen = UserDefaults.standard.bool(forKey: "hasSeenOnboarding")
            router.navigateTo(seen ? .main : .onboarding)
        }
    }
}

#Preview {
    SplashView()
        .environment(AppRouter())
}
