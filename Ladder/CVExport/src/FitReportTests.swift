import Foundation
import Testing

@testable import Ladder

/// The fit report's criteria, at the value level: everything arrives
/// verbatim from the reviewed outcome — nothing re-derived from the JD.
@MainActor
struct FitReportTests {
    private var outcome: ReviewedOutcome {
        ReviewedOutcome(
            items: [
                .init(
                    canonicalText: "Cut CI build times across every product target",
                    text: "Drove CI build times down across every product target"
                ),
                .init(
                    canonicalText: "Led incident response for the payments outage",
                    text: "Led incident response for the payments outage"
                ),
            ],
            gaps: [
                "The JD asks for Kubernetes; nothing on file mentions it",
                "No people-management experience on file",
            ],
            rationale: "CI and incident-response work map directly to the JD's platform-reliability focus."
        )
    }

    @Test("[CVEXPORT-15] the fit report lists every flagged gap")
    func fitReportListsEveryGap() {
        let report = FitReport(outcome: outcome)

        #expect(report.gaps == [
            "The JD asks for Kubernetes; nothing on file mentions it",
            "No people-management experience on file",
        ], "verbatim, in the reviewed outcome's order")
    }

    @Test("[CVEXPORT-15] no gaps means an empty gap list, not placeholders")
    func noGapsMeansEmptyList() {
        var noGaps = outcome
        noGaps.gaps = []

        let report = FitReport(outcome: noGaps)

        #expect(report.gaps.isEmpty)
    }

    @Test("[CVEXPORT-16] the fit report lists each selected achievement as a strength")
    func fitReportListsEachSelectionAsAStrength() {
        let report = FitReport(outcome: outcome)

        // One strength per selected achievement, in reviewed text — the
        // accepted rephrasing for the first, canonical for the second.
        #expect(report.strengths == [
            "Drove CI build times down across every product target",
            "Led incident response for the payments outage",
        ])
    }

    @Test("[CVEXPORT-17] the fit report shows the selection rationale verbatim")
    func fitReportShowsRationaleVerbatim() {
        let report = FitReport(outcome: outcome)

        #expect(report.rationale == "CI and incident-response work map directly to the JD's platform-reliability focus.")
    }
}
