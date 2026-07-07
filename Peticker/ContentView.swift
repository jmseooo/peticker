import SwiftUI

#Preview {
    RootView()
        .environment({
            let r = AppRouter()
            r.currentScreen = .onboarding
            return r
        }())
}
