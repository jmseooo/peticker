import SwiftUI

struct OnboardingView: View {
    @Environment(AppRouter.self) var router
    @State private var page = 0

    var body: some View {
        ZStack {
            Color.bgBase.ignoresSafeArea()

            VStack(spacing: 0) {
                PetickerLogo(size: 32, spacing: 6)
                    .padding(.top, 64)
                    .padding(.bottom, 36)

                TabView(selection: $page) {
                    onboardingCard(
                        icon: "iphone",
                        title: "Add widgets to\nyour background."
                    )
                    .tag(0)

                    onboardingCard(
                        icon: "lock.rectangle.stack",
                        title: "Create widgets for\nyour lock screen."
                    )
                    .tag(1)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))

                Button {
                    if page == 0 {
                        withAnimation { page = 1 }
                    } else {
                        UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
                        router.navigateTo(.main)
                    }
                } label: {
                    Text(page == 0 ? "Next" : "Get Started")
                        .font(.petickerButton)
                        .foregroundStyle(Color.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color.brandLime, in: RoundedRectangle(cornerRadius: 18))
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 52)
                .animation(.easeInOut, value: page)
            }
        }
    }

    @ViewBuilder
    private func onboardingCard(icon: String, title: String) -> some View {
        RoundedRectangle(cornerRadius: 28)
            .fill(Color.white)
            .frame(width: 260, height: 360)
            .shadow(color: .black.opacity(0.08), radius: 24, x: 0, y: 8)
            .overlay {
                VStack(spacing: 20) {
                    Image(systemName: icon)
                        .font(.system(size: 64))
                        .foregroundStyle(Color.brandCyan)
                    Text(title)
                        .font(.system(size: 18, weight: .semibold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color.black)
                }
                .padding(24)
            }
            .padding(.horizontal, 40)
    }
}

#Preview {
    OnboardingView()
        .environment(AppRouter())
}
