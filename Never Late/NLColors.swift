import SwiftUI

/// Design-system color tokens for Never Late.
/// Never use raw color values in views — always reference these tokens.
enum NLColors {
    // MARK: - Backgrounds
    static let appBackground   = Color(red: 0.051, green: 0.106, blue: 0.165) // #0D1B2A
    static let cardBackground  = Color(red: 0.086, green: 0.133, blue: 0.212) // #162236

    // MARK: - Borders
    /// Use with .opacity(1) — the 8% is baked into the design; apply as-is.
    static let cardBorder      = Color.white.opacity(0.08)

    // MARK: - Brand
    static let primary         = Color(red: 0.961, green: 0.651, blue: 0.137) // #F5A623

    // MARK: - Text
    static let textPrimary     = Color.white
    static let textSecondary   = Color(red: 0.478, green: 0.608, blue: 0.749) // #7A9BBF
    static let textTertiary    = Color(red: 0.290, green: 0.416, blue: 0.541) // #4A6A8A

    // MARK: - Status
    static let connected       = Color(red: 0.298, green: 0.686, blue: 0.314) // #4CAF50
    static let destructive     = Color(red: 1.000, green: 0.322, blue: 0.322) // #FF5252
    static let error           = Color(red: 1.000, green: 0.322, blue: 0.322) // #FF5252
    static let warning         = Color(red: 0.961, green: 0.651, blue: 0.137) // reuses primary gold
}
