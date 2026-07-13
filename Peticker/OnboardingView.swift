import SwiftUI
import Photos

struct OnboardingView: View {
    @Environment(AppRouter.self) var router

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

                    onboardingCard(
                        title: "Add widgets to your background.",
                        color: Color(hex: "C6F3FF")
                    ) {
                        HomeScreenMockup()
                    }
                    .padding(.horizontal, 22)

                    onboardingCard(
                        title: "Create widgets for your lock screen.",
                        color: Color(hex: "E1FF91")
                    ) {
                        LockScreenMockup()
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 26)
                }
                .padding(.bottom, 8)
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
                    .font(.petickerButton)
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

    @ViewBuilder
    private func onboardingCard<M: View>(
        title: String,
        color: Color,
        @ViewBuilder content: () -> M
    ) -> some View {
        VStack(spacing: 0) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.black)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 74)

            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(color)
        }
        .padding(.horizontal, 24)
        .frame(height: 288)
        .background(Color.white)
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
        Image("OnboardingLock")
            .resizable()
            .scaledToFit()
    }
}

#Preview {
    OnboardingView()
        .environment(AppRouter())
}
