import CoreText
import SwiftUI

/// Deliberately outside `Palette.swift`/`Typography.swift` — the print
/// document is exempt from the app-UI convention (decisions/0007), so raw
/// hex and custom fonts are legal here and only here.
enum CVTheme {
    // MARK: - Print palette (the reference CV's colours)

    static let heading = Color(printHex: 0x1A4D68)
    static let ink = Color(printHex: 0x1F2833)
    static let meta = Color(printHex: 0x5D6B76)
    static let hairline = Color(printHex: 0xC7D6DD)

    // MARK: - Bundled typefaces (SIL OFL, licenses beside the files)

    static let bodyFontName = "Inter-Regular"
    static let mediumFontName = "Inter-Medium"
    static let semiboldFontName = "Inter-SemiBold"
    static let boldFontName = "Inter-Bold"
    static let nameFontName = "SourceSerif4-Bold"

    @discardableResult
    static func registerFonts() -> Bool { fontsRegistered }

    private static let fontsRegistered: Bool = {
        let files = [("Inter", "ttc"), ("SourceSerif4-Bold", "ttf")]
        for (name, ext) in files {
            guard
                let url = Bundle.main.url(
                    forResource: name, withExtension: ext, subdirectory: "Fonts")
            else { return false }
            // Already-registered errors are fine — the face is available
            // either way.
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
        return true
    }()

    // MARK: - Type scale (points)

    static let nameSize: CGFloat = 24
    static let headlineSize: CGFloat = 10.5
    static let sectionHeaderSize: CGFloat = 9.5
    static let bodySize: CGFloat = 9.5
    static let roleTitleSize: CGFloat = 10.5
    static let metaSize: CGFloat = 8.5

    static func name(_ size: CGFloat = nameSize) -> Font { font(named: nameFontName, size: size) }
    static func body(_ size: CGFloat = bodySize) -> Font { font(named: bodyFontName, size: size) }
    static func medium(_ size: CGFloat = bodySize) -> Font { font(named: mediumFontName, size: size) }
    static func semibold(_ size: CGFloat = bodySize) -> Font { font(named: semiboldFontName, size: size) }
    static func bold(_ size: CGFloat = bodySize) -> Font { font(named: boldFontName, size: size) }

    /// Contextual alternates are disabled everywhere: Inter substitutes the
    /// hyphen between digits with an alternate glyph that PDF text extraction
    /// returns as a private-use codepoint, breaking the ATS-parseable guarantee.
    private static func font(named name: String, size: CGFloat) -> Font {
        registerFonts()
        let settings: [[CFString: Any]] = [[
            kCTFontFeatureTypeIdentifierKey: kContextualAlternatesType,
            kCTFontFeatureSelectorIdentifierKey: kContextualAlternatesOffSelector,
        ]]
        let attributes: [CFString: Any] = [
            kCTFontNameAttribute: name,
            kCTFontFeatureSettingsAttribute: settings,
        ]
        let descriptor = CTFontDescriptorCreateWithAttributes(attributes as CFDictionary)
        return Font(CTFontCreateWithFontDescriptor(descriptor, size, nil))
    }

    /// NSFont twins for headless measurement — the same faces the view sets.
    static func measuringFont(named name: String, size: CGFloat) -> NSFont {
        registerFonts()
        return NSFont(name: name, size: size) ?? NSFont.systemFont(ofSize: size)
    }
}

struct CVMetrics: Equatable {
    /// A4 in PostScript points.
    static let pageSize = CGSize(width: 595.2, height: 841.8)
    static let margin: CGFloat = 44

    static let compactionSteps: [CGFloat] = [1.0, 0.88, 0.76]
    static let stretchCap: CGFloat = 1.25
    static let underflowThreshold: CGFloat = 1.5

    var scale: CGFloat

    init(compaction: CGFloat = 1.0, stretch: CGFloat = 1.0) {
        scale = compaction * stretch
    }

    var contentWidth: CGFloat { Self.pageSize.width - 2 * Self.margin }
    var contentHeight: CGFloat { Self.pageSize.height - 2 * Self.margin }

    var sectionGap: CGFloat { 14 * scale }
    var blockGap: CGFloat { 7 * scale }
    var lineGap: CGFloat { 3 * scale }
}

private extension Color {
    init(printHex hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
