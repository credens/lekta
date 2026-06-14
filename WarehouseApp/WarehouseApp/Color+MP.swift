import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int & 0xFF0000) >> 16) / 255
        let g = Double((int & 0x00FF00) >> 8) / 255
        let b = Double(int & 0x0000FF) / 255
        self.init(red: r, green: g, blue: b)
    }

    static let mpBrown  = Color(red: 0.24, green: 0.12, blue: 0.04)
    static let mpAmber  = Color(hex: "FF9A00")
    static let mpOrange = Color(hex: "FF6B35")
    static let mpYellow = Color(hex: "FFD700")
    static let mpGreen  = Color(hex: "00A650")
    static let mpDanger = Color(hex: "E53E3E")
    static let mpCream  = Color(hex: "FFF8F0")
    static let mpSand   = Color(hex: "F5E6C8")
}

// Allows dot-syntax (e.g. .mpBrown) in ShapeStyle contexts like foregroundStyle
extension ShapeStyle where Self == Color {
    static var mpBrown:  Color { .mpBrown }
    static var mpAmber:  Color { .mpAmber }
    static var mpOrange: Color { .mpOrange }
    static var mpYellow: Color { .mpYellow }
    static var mpGreen:  Color { .mpGreen }
    static var mpDanger: Color { .mpDanger }
    static var mpCream:  Color { .mpCream }
    static var mpSand:   Color { .mpSand }
}
