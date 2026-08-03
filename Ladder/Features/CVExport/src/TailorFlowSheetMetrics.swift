import CoreGraphics

/// A sheet keeps the presentation size it opens at, so this floor is also the
/// tailor flow sheet's width — nothing the user does widens it.
enum TailorFlowSheetMetrics {
    static let minWidth: CGFloat = 1100
    static let minHeight: CGFloat = 640

    static let pagePaneMinWidth: CGFloat = 620
    static let editorMinWidth: CGFloat = 340

    static let readingMeasure: CGFloat = 720

    /// `HSplitView` opens the leading pane at exactly its minimum and hands the
    /// trailing pane every remaining point; an `idealWidth` on either is
    /// ignored. So the page pane's floor is also the width it opens at, and the
    /// only way to widen the editor is to leave slack for it here.
    static var openingPagePaneWidth: CGFloat { pagePaneMinWidth }
}
