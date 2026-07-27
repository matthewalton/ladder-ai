import Foundation

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

/// Pure derivation — statics only, an explicit `asOf` where the clock
/// matters, no writes.
enum TimelineModel {
    static func entries(for application: Application) -> [TimelineEntry] {
        var entries: [TimelineEntry] = []

        if let appliedAt = application.appliedAt {
            entries.append(
                TimelineEntry(
                    kind: .applied, label: "Applied", date: appliedAt,
                    isFilled: true, blaze: .circle))
        }

        // Heard-back is derived, never stored: the earliest date any Stage carries.
        let stageDates = application.stages.flatMap { [$0.scheduledAt, $0.heardBackAt] }
        if let heardBackAt = stageDates.compactMap({ $0 }).min() {
            entries.append(
                TimelineEntry(
                    kind: .heardBack, label: "Heard back", date: heardBackAt,
                    isFilled: true, blaze: .circle))
        }

        for stage in application.orderedStages {
            entries.append(
                TimelineEntry(
                    kind: .stage(stage.kind), label: stage.kind.label,
                    date: stage.scheduledAt ?? stage.heardBackAt,
                    isFilled: stage.outcome != .pending,
                    blaze: blaze(for: stage.kind)))
        }

        // Statuses carry no timestamp, so the outcome entry is undated.
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

    static func segmentLabel(from: TimelineEntry, to: TimelineEntry) -> String? {
        guard let fromDate = from.date, let toDate = to.date else { return nil }
        let days = wholeDays(from: fromDate, to: toDate)
        guard days > 0 else { return "same day" }
        let count = days == 1 ? "1 day" : "\(days) days"
        return to.kind == .heardBack ? "\(count) to hear back" : count
    }

    static func inStageLabel(for application: Application, asOf: Date) -> String? {
        guard !isTerminal(application.status) else { return nil }
        guard let latest = entries(for: application).compactMap(\.date).max() else { return nil }
        let days = wholeDays(from: latest, to: asOf)
        guard days > 0 else { return "In stage today" }
        return days == 1 ? "In stage 1 day" : "In stage \(days) days"
    }

    /// Completed 86 400-second days — deliberately not calendar-day arithmetic.
    private static func wholeDays(from: Date, to: Date) -> Int {
        max(0, Int(to.timeIntervalSince(from) / 86_400))
    }
}
