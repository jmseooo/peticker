import SwiftUI

/// 가이드 텍스트·화살표 레이어. 딤은 MainView에서 청록 원 아래에 별도로 깔린다
/// (Figma: 딤 위에 청록 원이 하이라이트되고, 그 위에 텍스트·화살표가 올라감).
struct MainGuideOverlay: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            // 가이드 텍스트 — Figma y=242.5/812
            Text("Click to add your widget!")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .position(x: w * 0.557, y: h * 0.299)

            // 화살표 — Figma 아래 방향, 중심 (208.5/375, 278.5/812), size=29
            // (ArrowUp 에셋은 실제로는 아래를 향하므로 회전하지 않음)
            Image("ArrowUp")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 29, height: 29)
                .foregroundStyle(.white)
                .position(x: w * 0.556, y: h * 0.343)
        }
    }
}

#Preview {
    ZStack {
        Color.gray.ignoresSafeArea()
        MainGuideOverlay()
    }
}
