import SwiftUI

/// 설정 아이콘 위에 얹는 안내 텍스트·화살표. MainGuideOverlay와 같은 폰트·화살표 스타일을 쓴다.
/// 설정 아이콘 바로 위에 쌓이도록 MainView의 .overlay(alignment: .bottomTrailing) 안에서 사용한다.
struct BatteryGuideOverlay: View {
    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            Text("설정에서 배터리 표시를\n켜거나 끌 수 있어요")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.trailing)

            // (ArrowUp 에셋은 실제로는 아래를 향하므로 회전 없이 그대로 쓴다)
            Image("ArrowUp")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 29, height: 29)
                .foregroundStyle(.white)
        }
    }
}

#Preview {
    ZStack {
        Color.gray.ignoresSafeArea()
        VStack {
            Spacer()
            HStack {
                Spacer()
                BatteryGuideOverlay()
            }
        }
        .padding(35)
    }
}
