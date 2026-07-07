import SwiftUI

let petickerLetters: [(String, Color)] = [
    ("P", .brandPink), ("e", .brandYellow), ("t", .brandCyan), ("i", .brandOrange),
    ("c", .brandLime),  ("k", .brandPink),  ("e", .brandYellow), ("r", .brandCyan)
]

struct PetickerLogo: View {
    var size: CGFloat = 28
    var spacing: CGFloat = 4

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(Array(petickerLetters.enumerated()), id: \.offset) { _, item in
                LetterBadge(letter: item.0, color: item.1, size: size)
            }
        }
    }
}

struct LetterBadge: View {
    let letter: String
    let color: Color
    var size: CGFloat = 28

    var body: some View {
        Text(letter)
            .font(.system(size: size * 0.62, weight: .bold, design: .default))
            .foregroundStyle(Color.black)
            .frame(width: size, height: size)
            .background(color, in: Circle())
    }
}

#Preview("Logo") {
    PetickerLogo(size: 36, spacing: 6)
        .padding()
        .background(Color.bgBase)
}

#Preview("Letter Badge") {
    HStack(spacing: 8) {
        LetterBadge(letter: "p", color: .brandPink, size: 40)
        LetterBadge(letter: "e", color: .brandCyan, size: 40)
        LetterBadge(letter: "t", color: .brandYellow, size: 40)
        LetterBadge(letter: "i", color: .brandLime, size: 40)
    }
    .padding()
    .background(Color.bgBase)
}
