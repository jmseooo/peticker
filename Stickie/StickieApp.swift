import SwiftUI

@main
struct StickieApp: App {
    @State private var router = AppRouter()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(router)
        }
    }
}

struct RootView: View {
    @Environment(AppRouter.self) var router

    var body: some View {
        ZStack {
            switch router.currentScreen {
            case .splash:
                SplashView().transition(.opacity)
            case .onboarding:
                OnboardingView().transition(.opacity)
            case .main:
                MainView().transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: router.currentScreen)
    }
}
