import WidgetKit
import SwiftUI

// 위젯 익스텐션 진입점 — 이 번들이 제공하는 위젯 목록
@main
struct StickieWidgetBundle: WidgetBundle {
    var body: some Widget {
        StickieWidget()
    }
}
