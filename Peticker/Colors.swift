import SwiftUI

extension Color {
    static let brandPink   = Color(hex: "FF2DA0")
    static let brandYellow = Color(hex: "F5E63D")
    static let brandCyan   = Color(hex: "3DD6F5")
    static let brandOrange = Color(hex: "FF6B35")
    static let brandLime   = Color(hex: "C6F53D")
    static let bgBase      = Color(hex: "F5F5F5")
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 3:  (r, g, b) = ((int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default: (r, g, b) = (255, 255, 255)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
    }
}
