import Foundation

/// One node on the timeline: the applied entry, the derived heard-back entry
/// (decisions/0001), a Stage entry, or the outcome entry.
struct TimelineEntry: Equatable {
    enum Kind: Equatable {
        case applied
        case heardBack
        case stage(StageKind)
        case outcome(ApplicationStatus)
    }

    var kind: Kind
    var label: String
    var date: Date?
    var isFilled: Bool
    var blaze: Blaze
}

/// The slice's derivation seam: statics only, an explicit `asOf` where the
/// clock matters (the [PIPEBOARD-16] pattern), no writes anywhere.
enum TimelineModel {
    /// The entries for one Application, in line order ([TIMELINE-1]):
    /// applied → heard back → each Stage → outcome. The applied, heard-back,
    /// and outcome entries are always filled — they only exist because their
    /// moment happened ([TIMELINE-10]).
    static func entries(for application: Application) -> [TimelineEntry] {
        var entries: [TimelineEntry] = []

        if let appliedAt = application.appliedAt {
            entries.append(
                TimelineEntry(
                    kind: .applied, label: "Applied", date: appliedAt,
                    isFilled: true, blaze: .circle))
        }

        // Derived, never stored (decisions/0001): the minimum over every
        // Stage's scheduledAt and heardBackAt ([TIMELINE-2]); absent when
        // nothing is dated ([TIMELINE-3]).
        let stageDates = application.stages.flatMap { [$0.scheduledAt, $0.heardBackAt] }
        if let heardBackAt = stageDates.compactMap({ $0 }).min() {
            entries.append(
                TimelineEntry(
                    kind: .heardBack, label: "Heard back", date: heardBackAt,
                    isFilled: true, blaze: .circle))
        }

        // sortIndex order, not date order ([TIMELINE-4]); filled exactly
        // when resolved ([TIMELINE-10]).
        for stage in application.orderedStages {
            entries.append(
                TimelineEntry(
                    kind: .stage(stage.kind), label: stage.kind.label,
                    date: stage.scheduledAt ?? stage.heardBackAt,
                    isFilled: stage.outcome != .pending,
                    blaze: blaze(for: stage.kind)))
        }

        // The outcome entry closes a terminal trail ([TIMELINE-5]) and only
        // a terminal one ([TIMELINE-6]). Statuses carry no timestamp, so the
        // entry is undated.
        if isTerminal(application.status) {
            entries.append(
                TimelineEntry(
                    kind: .outcome(application.status),
                    label: application.status.columnTitle, date: nil,
                    isFilled: true,
                    blaze: application.status == .offer ? .flag : .circle))
        }

        return entries
    }

    private static func isTerminal(_ status: ApplicationStatus) -> Bool {
        switch status {
        case .offer, .rejected, .withdrawn: true
        case .draft, .applied, .active: false
        }
    }

    /// The DESIGN.md §5 assignments, extended over the full kind set by
    /// family ([TIMELINE-11]): a total function on `StageKind`.
    static func blaze(for kind: StageKind) -> Blaze {
        switch kind {
        case .screen, .recruiter: .circle
        case .technical, .systemDesign, .takeHome: .diamond
        case .behavioral: .square
        case .final: .doubleChevron
        case .offer: .flag
        case .other: .circle
        }
    }

    /// The elapsed label for the segment between two adjacent entries:
    /// spelled-out whole days (decisions/0003) when both ends are dated
    /// ([TIMELINE-7]), nothing otherwise ([TIMELINE-8]).
    static func segmentLabel(from: TimelineEntry, to: TimelineEntry) -> String? {
        guard let fromDate = from.date, let toDate = to.date else { return nil }
        let days = wholeDays(from: fromDate, to: toDate)
        guard days > 0 else { return "same day" }
        let count = days == 1 ? "1 day" : "\(days) days"
        return to.kind == .heardBack ? "\(count) to hear back" : count
    }

    /// The trailing in-stage label ([TIMELINE-9]): whole days from the
    /// latest dated entry to `asOf`. Absent on a terminal Application — the
    /// outcome entry ends its line — and when nothing is dated.
    static func inStageLabel(for application: Application, asOf: Date) -> String? {
        guard !isTerminal(application.status) else { return nil }
        guard let latest = entries(for: application).compactMap(\.date).max() else { return nil }
        let days = wholeDays(from: latest, to: asOf)
        guard days > 0 else { return "In stage today" }
        return days == 1 ? "In stage 1 day" : "In stage \(days) days"
    }

    /// The [PIPEBOARD-16] floor: completed 86 400-second days, clamped so a
    /// backwards pair never reads negative.
    private static func wholeDays(from: Date, to: Date) -> Int {
        max(0, Int(to.timeIntervalSince(from) / 86_400))
    }
}
