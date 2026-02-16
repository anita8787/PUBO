import SwiftUI

// MARK: - Pubo Design System

struct PuboColors {
    static let navy = Color(hex: "203B93")
    static let yellow = Color(hex: "FFC849")
    static let red = Color(hex: "C8252B")
    static let blue = Color(hex: "EBF2FF")
    static let background = Color(hex: "F5F5F5") 
    static let green = Color(hex: "34C759") // Apple Green 
    static let cardYellow = Color(hex: "FFC849")
    static let cardOrange = Color.orange 
    static let cardRed = Color(hex: "FF6B6B") 
    static let cardBlue = Color(hex: "4D96FF") 
}

struct PuboStyles {
    static let cornerRadius: CGFloat = 20
    static let borderWidth: CGFloat = 2.5
    static let shadowOffset = CGSize(width: 4, height: 4)
    static let shadowColor = Color.black.opacity(0.1)
}

// MARK: - Shapes
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

// MARK: - Extensions

extension View {
    // 直接用 extension，不透過 struct ViewModifier
    func retroShadow(color: Color = .black, offset: CGFloat = 4) -> some View {
        self.shadow(color: color, radius: 0, x: offset, y: offset)
    }
    
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
