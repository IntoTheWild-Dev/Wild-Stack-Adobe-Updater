import SwiftUI

// ITW Design Tech brand tokens — sourced from WildStack CI sheet.
enum WDS {

    // MARK: - Colours
    static let bg       = Color(hex: "020618")  // window background
    static let footerBG = Color(hex: "050b0f")
    static let card     = Color(hex: "0f172b")  // card surface
    static let input    = Color(hex: "1d293d")  // input bg / borders
    static let slate    = Color(hex: "49657a")  // slate primary
    static let coral    = Color(hex: "df6f6d")  // coral accent
    static let amber    = Color(hex: "fabf71")  // amber / price
    static let heading  = Color(hex: "cad5e2")  // light headings
    static let body     = Color(hex: "c0ced8")  // body text
    static let muted    = Color(hex: "8a9fae")  // muted / labels
    static let success  = Color(hex: "4ade80")  // green status

    // MARK: - Gradient
    static let ctaGradient = LinearGradient(
        colors: [slate, coral],
        startPoint: .leading,
        endPoint: .trailing
    )

    // MARK: - Typography helpers
    static func inter(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom("Inter", size: size).weight(weight)
    }
}

// MARK: - Hex colour initialiser
extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch h.count {
        case 3:  (a,r,g,b) = (255,(int>>8)*17,(int>>4 & 0xF)*17,(int & 0xF)*17)
        case 6:  (a,r,g,b) = (255,int>>16,int>>8 & 0xFF,int & 0xFF)
        case 8:  (a,r,g,b) = (int>>24,int>>16 & 0xFF,int>>8 & 0xFF,int & 0xFF)
        default: (a,r,g,b) = (255,255,255,255)
        }
        self.init(.sRGB,
                  red:     Double(r)/255,
                  green:   Double(g)/255,
                  blue:    Double(b)/255,
                  opacity: Double(a)/255)
    }
}
