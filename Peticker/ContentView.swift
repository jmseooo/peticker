import SwiftUI

#Preview("전체 플로우") {
    RootView()
        .environment(AppRouter())
}

#Preview("스플래시") {
    SplashView()
        .environment(AppRouter())
}

#Preview("온보딩") {
    OnboardingView()
        .environment(AppRouter())
}

#Preview("메인") {
    MainView()
        .environment(AppRouter())
}
