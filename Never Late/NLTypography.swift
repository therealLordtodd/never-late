import SwiftUI

/// Design-system typography tokens for Never Late.
/// Never use raw .font() modifiers in views — always reference these tokens.
enum NLTypography {
    /// 38pt Bold — app hero title
    static let heroTitle     = Font.system(size: 38, weight: .bold,     design: .default)
    /// 22pt Bold — page/section titles
    static let pageTitle     = Font.system(size: 22, weight: .bold,     design: .default)
    /// 13pt Semibold — card section headers (apply .textCase(.uppercase) + .tracking(0.5) at call site)
    static let sectionHeader = Font.system(size: 13, weight: .semibold, design: .default)
    /// 16pt Regular — body copy
    static let body          = Font.system(size: 16, weight: .regular,  design: .default)
    /// 13pt Regular — captions, helper text
    static let caption       = Font.system(size: 13, weight: .regular,  design: .default)
    /// 13pt Mono — IDs, timestamps, technical values
    static let mono          = Font.system(size: 13, weight: .regular,  design: .monospaced)
}
