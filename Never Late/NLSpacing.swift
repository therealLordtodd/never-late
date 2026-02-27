import CoreFoundation

/// Design-system spacing tokens for Never Late.
/// Never use raw numeric spacing values in views — always reference these tokens.
enum NLSpacing {
    static let microGap:    CGFloat = 2
    static let tinyGap:     CGFloat = 4
    static let compactGap:  CGFloat = 8
    static let innerGap:    CGFloat = 12
    static let sectionGap:  CGFloat = 20
    static let pagePadding: CGFloat = 24
    static let cardRadius:  CGFloat = 20
    static let buttonRadius: CGFloat = 12
    static let scrollBottomPadding: CGFloat = 48
}
