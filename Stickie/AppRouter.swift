import SwiftUI

enum AppScreen: Equatable {
    case splash, onboarding, main
}

@MainActor
@Observable
final class AppRouter {
    var currentScreen: AppScreen = .splash

    func navigateTo(_ screen: AppScreen) {
        withAnimation(.easeInOut(duration: 0.4)) {
            currentScreen = screen
        }
    }
}
