import Foundation

/// Renders the whole pack as one markdown file — offline string assembly,
/// no service call ([PREP-19]). Sections with nothing to say are omitted
/// rather than left as empty headings.
enum PrepPackMarkdown {
    @MainActor
    static func render(_ pack: PrepPack, for stage: Stage) -> String {
        var sections: [String] = []

        let company = stage.application?.company ?? ""
        let roleTitle = stage.application?.roleTitle ?? ""
        let subject = [company, roleTitle]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
        sections.append(subject.isEmpty ? "# Prep pack" : "# Prep pack — \(subject)")

        if let brief = pack.companyBrief, !brief.isEmpty {
            sections.append("## Company brief\n\n\(brief)")
        }

        if !pack.likelyQuestions.isEmpty {
            let questions = pack.likelyQuestions.enumerated()
                .map { "\($0.offset + 1). \($0.element)" }
                .joined(separator: "\n")
            sections.append("## Likely questions\n\n\(questions)")
        }

        let points = pack.orderedTalkingPoints
        if !points.isEmpty {
            let rendered = points.map { point in
                let ammo = point.achievements
                    .map { "\n  - Achievement: \($0.text)" }
                    .joined()
                return "- \(point.text)\(ammo)"
            }.joined(separator: "\n")
            sections.append("## Talking points\n\n\(rendered)")
        }

        if !pack.mockTasks.isEmpty {
            let tasks = pack.mockTasks
                .map { "### \($0.title)\n\n\($0.brief)" }
                .joined(separator: "\n\n")
            sections.append("## Mock tasks\n\n\(tasks)")
        }

        return sections.joined(separator: "\n\n") + "\n"
    }
}
