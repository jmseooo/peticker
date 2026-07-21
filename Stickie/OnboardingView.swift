import SwiftUI
import Photos

struct OnboardingView: View {
    @Environment(AppRouter.self) var router
    @State private var showHomeMockup = false
    @State private var showLockMockup = false

    var body: some View {
        ZStack {
            Color.bgBase.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Image("StickieLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 153, height: 24)
                        .padding(.top, 35)
                        .padding(.bottom, 16)

                    onboardingCard(color: Color(hex: "C6F3FF")) {
                        HomeScreenMockup()
                            .offset(y: showHomeMockup ? 0 : 18)
                            .opacity(showHomeMockup ? 1 : 0)
                    }
                    .padding(.horizontal, 22)

                    onboardingCard(color: Color(hex: "E1FF91")) {
                        LockScreenMockup()
                            .offset(y: showLockMockup ? 0 : 18)
                            .opacity(showLockMockup ? 1 : 0)
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 26)
                }
                .padding(.bottom, 8)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
                showHomeMockup = true
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.25)) {
                showLockMockup = true
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button {
                PHPhotoLibrary.requestAuthorization(for: .readWrite) { _ in
                    Task { @MainActor in
                        UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
                        router.navigateTo(.main)
                    }
                }
            } label: {
                Text("Get Started")
                    .font(.stickieButton)
                    .foregroundStyle(Color.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.brandLime, in: RoundedRectangle(cornerRadius: 18))
            }
            .padding(.horizontal, 28)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .background(Color.bgBase)
        }
    }

    // 카드 색 둥근 배경 위에 목업 이미지(비율 644x576)를 얹고 둥근 모서리로 클리핑.
    private func onboardingCard<M: View>(
        color: Color,
        @ViewBuilder content: () -> M
    ) -> some View {
        let inner = content()
        return RoundedRectangle(cornerRadius: 30)
            .fill(color)
            .aspectRatio(644.0 / 576.0, contentMode: .fit)
            .overlay { inner }
            .clipShape(RoundedRectangle(cornerRadius: 30))
    }
}

private struct HomeScreenMockup: View {
    var body: some View {
        Image("OnboardingHome")
            .resizable()
            .scaledToFit()
    }
}

private struct LockScreenMockup: View {
    var body: some View {
        Image("OnboardingLockCard")
            .resizable()
            .scaledToFit()
    }
}

#Preview {
    OnboardingView()
        .environment(AppRouter())
}
