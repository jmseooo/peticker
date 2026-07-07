import SwiftUI

struct SplashView: View {
    @Environment(AppRouter.self) var router
    @State private var offsets: [CGSize] = Array(repeating: .zero, count: 8)
    @State private var showLogo = false
    @State private var showTagline = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.bgBase.ignoresSafeArea()

                VStack(spacing: 14) {
                    HStack(spacing: 6) {
                        ForEach(0..<petickerLetters.count, id: \.self) { i in
                            LetterBadge(
                                letter: petickerLetters[i].0,
                                color: petickerLetters[i].1,
                                size: 36
                            )
                            .offset(offsets[i])
                        }
                    }
                    .opacity(showLogo ? 1 : 0)

                    Text("Make your own peticker")
                        .font(.petickerTagline)
                        .foregroundStyle(Color.gray)
                        .opacity(showTagline ? 1 : 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .task {
                try? await Task.sleep(for: .milliseconds(200))
                withAnimation(.easeIn(duration: 0.5)) { showLogo = true }
                try? await Task.sleep(for: .milliseconds(400))
                withAnimation(.easeIn(duration: 0.5)) { showTagline = true }
                try? await Task.sleep(for: .milliseconds(1400))
                scatter(in: geo.size)
                try? await Task.sleep(for: .milliseconds(1100))
                let seen = UserDefaults.standard.bool(forKey: "hasSeenOnboarding")
                router.navigateTo(seen ? .main : .onboarding)
            }
        }
    }

    private func scatter(in size: CGSize) {
        let w = size.width
        let h = size.height
        let targets: [CGSize] = [
            CGSize(width: -w * 0.38, height: -h * 0.32),
            CGSize(width: -w * 0.13, height: -h * 0.36),
            CGSize(width:  w * 0.09, height: -h * 0.28),
            CGSize(width:  w * 0.33, height: -h * 0.21),
            CGSize(width: -w * 0.33, height:  h * 0.27),
            CGSize(width: -w * 0.07, height:  h * 0.31),
            CGSize(width:  w * 0.17, height:  h * 0.35),
            CGSize(width:  w * 0.38, height:  h * 0.29),
        ]
        for i in 0..<8 {
            withAnimation(.spring(duration: 0.9, bounce: 0.25).delay(Double(i) * 0.04)) {
                offsets[i] = targets[i]
            }
        }
    }
}

#Preview {
    SplashView()
        .environment(AppRouter())
}
