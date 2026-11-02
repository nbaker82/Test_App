import SwiftUI

extension Color {
    /// The warm neutral behind every screen.
    public static let priceScreenBackground = Color("PriceScreenBackground", bundle: .module)

    /// The surface of list rows, one step lighter than the screen in both modes.
    static let priceCardBackground = Color("PriceCardBackground", bundle: .module)

    /// System green and red are too faint for small text on the light screen background,
    /// at about 2:1 and 3:1, so these use darker shades there.
    static let pricePositive = Color("PricePositive", bundle: .module)
    static let priceNegative = Color("PriceNegative", bundle: .module)
}
