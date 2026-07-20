import Foundation

/// The set/collapsed decision for this slice's long-text fields — the job
/// description, the notes, the prep context (docs/adr/0003). Decided once,
/// when the form appears: a field non-empty after trimming collapses to an
/// indicator row ([PIPEBOARD-29]); an empty one keeps its inline editor and
/// never collapses mid-typing ([PIPEBOARD-30]).
enum LongTextField {
    static func collapsesAtAppearance(_ text: String) -> Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
