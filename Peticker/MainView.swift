import SwiftUI

struct MainView: View {
    @Environment(AppRouter.self) var router
    @State private var showComingSoon = false

    var body: some View {
        ZStack {
            Color.bgBase.ignoresSafeArea()

            VStack(spacing: 0) {
                PetickerLogo(size: 30, spacing: 5)
                    .padding(.top, 64)

                Spacer()

                LockedSlot(color: .brandPink)
                    .onTapGesture { showComingSoon = true }

                Spacer()

                Circle()
                    .fill(Color.brandCyan)
                    .frame(width: 220, height: 220)
                    .overlay {
                        Image(systemName: "plus")
                            .font(.system(size: 52, weight: .ultraLight))
                            .foregroundStyle(Color.white)
                    }

                Spacer()

                LockedSlot(color: .brandLime)
                    .onTapGesture { showComingSoon = true }

                Spacer()
            }
        }
        .overlay {
            if showComingSoon {
                ComingSoonOverlay { showComingSoon = false }
            }
        }
    }
}

struct LockedSlot: View {
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(style: StrokeStyle(lineWidth: 2.5, dash: [6, 4]))
                .foregroundStyle(color)
                .frame(width: 80, height: 80)
            Image(systemName: "lock.fill")
                .font(.system(size: 22))
                .foregroundStyle(color)
        }
    }
}

struct ComingSoonOverlay: View {
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            Text("Coming Soon!")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 16)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }
}

#Preview {
    MainView()
        .environment(AppRouter())
}

#Preview("Coming Soon") {
    ComingSoonOverlay {}
}

#Preview("Locked Slot") {
    HStack(spacing: 40) {
        LockedSlot(color: .brandPink)
        LockedSlot(color: .brandLime)
    }
    .padding()
    .background(Color.bgBase)
}
