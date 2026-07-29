import AppKit
import SwiftData
import SwiftUI
import Testing

@testable import Ladder

/// Renders components to PNGs under `.snapshots/` so a change to one can be
/// looked at without launching anything. Off by default — run it through
/// `scripts/snapshots.sh views`.
///
/// Components only: `ImageRenderer` draws what SwiftUI draws itself, but
/// leaves AppKit-backed pieces blank — `TextField`, `List`/`Form` rows and
/// scrolling containers — and renders `TabView` as the unavailable glyph. A
/// component that comes out empty has hit that wall; whole screens come from
/// `LadderUITests/ScreenTour.swift`.
@MainActor
@Suite(.enabled(if: ProcessInfo.processInfo.environment["LADDER_SNAPSHOTS"] == "1"))
struct SnapshotGallery {
    @Test func renderGallery() throws {
        let gallery = try Gallery()

        let applications = try seededApplications()
        try gallery.write(
            VStack(alignment: .leading, spacing: 12) {
                ForEach(applications) { ApplicationCardView(application: $0) }
            },
            named: "application-cards", width: 320
        )

        try gallery.write(
            TagChipsView(names: ["Swift", "SwiftUI", "AI Engineering", "Distributed Systems"]),
            named: "tag-chips", width: 320
        )

        try gallery.write(
            VStack(spacing: 8) {
                IndicatorRow(
                    label: "Job description", detail: "2,400 words",
                    icon: "doc.text", onOpen: {}, onRemove: {}
                ) { EmptyView() }
                IndicatorRow(
                    label: "Debrief", icon: "sparkles", openAffordance: "Read",
                    onOpen: {}, onRemove: {}
                ) { EmptyView() }
            },
            named: "indicator-rows", width: 420
        )

        print("Gallery written to \(gallery.directory.path)")
    }

    private func seededApplications() throws -> [Application] {
        let store = PipelineStore(container: try ProfileStore.container(inMemory: true))
        let applied = Date(timeIntervalSince1970: 1_750_000_000)
        let active = try store.createApplication(
            company: "Northwind", roleTitle: "Principal Engineer",
            source: "Referral", notes: "", appliedAt: applied
        )
        try store.addStage(
            to: active, kind: .technical, scheduledAt: applied.addingTimeInterval(86_400 * 6)
        )
        try store.createApplication(
            company: "Basecamp Robotics", roleTitle: "Staff iOS Engineer",
            source: "LinkedIn", notes: "", appliedAt: applied.addingTimeInterval(-86_400 * 3)
        )
        let closed = try store.createApplication(
            company: "Summit Analytics", roleTitle: "Engineering Manager",
            source: nil, notes: "", appliedAt: applied
        )
        try store.move(closed, to: .rejected)
        try store.load()
        return store.applications
    }
}

@MainActor
private struct Gallery {
    let directory: URL

    init() throws {
        // #filePath is <repo>/LadderTests/SnapshotGallery.swift — the gallery
        // lands beside the sources it renders, not in the build products.
        let repo = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        directory = repo.appending(path: ".snapshots")
        try? FileManager.default.removeItem(at: directory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func write(_ view: some View, named name: String, width: CGFloat) throws {
        try write(view, named: name, width: width, scheme: .light)
        try write(view, named: "\(name)-dark", width: width, scheme: .dark)
    }

    private func write(
        _ view: some View, named name: String, width: CGFloat, scheme: ColorScheme
    ) throws {
        // Asset-catalogue colours resolve through the app's NSAppearance, which
        // the SwiftUI environment alone does not move — Palette comes out light
        // in both passes without this.
        let previous = NSApp?.appearance
        NSApp?.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
        defer { NSApp?.appearance = previous }

        let renderer = ImageRenderer(
            content:
                view
                .frame(width: width)
                .padding(20)
                .background(Color.paper)
                .environment(\.colorScheme, scheme)
        )
        renderer.scale = 2

        guard let image = renderer.nsImage,
            let tiff = image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiff),
            let png = bitmap.representation(using: .png, properties: [:])
        else {
            throw GalleryError.renderFailed(name)
        }
        try png.write(to: directory.appending(path: "\(name).png"))
    }
}

private enum GalleryError: Error {
    case renderFailed(String)
}
