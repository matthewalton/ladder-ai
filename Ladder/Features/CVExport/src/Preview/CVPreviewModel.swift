import Foundation
import SwiftData

/// Every edit re-lays-out and re-renders deterministically — compaction and
/// stretch only, never a service call.
@MainActor
@Observable
final class CVPreviewModel {
    let profile: Profile
    let review: TailorReview
    let applicationID: PersistentIdentifier

    private(set) var edits: CVEditSet
    private(set) var composition: CVComposition
    private(set) var coverage: CVCoverage
    private(set) var relevance: [PersistentIdentifier: RelevanceStats]
    private(set) var rescoreFailure: String?
    private(set) var isRescoring = false
    private(set) var isConfirmingDiscard = false
    private(set) var isClosed = false

    private let profileStore: ProfileStore
    private let rescorePass: RelevanceRescorePass?
    private let jobDescription: String
    private let composed: CVFitLoop.Outcome
    private let pristine: CVEditSet

    init(
        profileStore: ProfileStore,
        profile: Profile,
        review: TailorReview,
        applicationID: PersistentIdentifier,
        jobDescription: String,
        composition: CVComposition,
        rescorePass: RelevanceRescorePass? = nil
    ) {
        self.profileStore = profileStore
        self.profile = profile
        self.review = review
        self.applicationID = applicationID
        self.jobDescription = jobDescription
        self.composition = composition
        self.rescorePass = rescorePass
        composed = composition.fit
        let edits = CVEditSet(review: review)
        self.edits = edits
        pristine = edits
        coverage = edits.coverage(profile: profile, matchedTagNames: review.matchedTagNames)
        var relevance: [PersistentIdentifier: RelevanceStats] = [:]
        for item in review.items where item.relevance != nil {
            relevance[item.achievement.persistentModelID] = item.relevance
        }
        for project in review.selectedProjects {
            relevance[project.persistentModelID] = review.relevanceStats(for: project)
        }
        self.relevance = relevance.compactMapValues { $0 }
    }

    var pageCount: Int { composition.pageCount }
    var pdfData: Data { composition.pdfData }
    var fitReport: FitReport { composition.fitReport }
    var summary: String { edits.summary }
    var canExport: Bool { composition.fitsTwoPages }
    var pagesOverCap: Int { max(0, pageCount - CVFitLoop.pageCap) }
    var hasPendingEdits: Bool { edits != pristine }

    // MARK: - Selecting

    func isSelected(_ achievement: Achievement) -> Bool {
        edits.selectedAchievements.contains(achievement.persistentModelID)
    }

    func isSelected(_ project: Project) -> Bool {
        edits.selectedProjects.contains(project.persistentModelID)
    }

    func setSelected(_ achievement: Achievement, _ selected: Bool) {
        apply {
            if selected {
                $0.selectedAchievements.insert(achievement.persistentModelID)
            } else {
                $0.selectedAchievements.remove(achievement.persistentModelID)
            }
        }
    }

    func setSelected(_ project: Project, _ selected: Bool) {
        apply {
            if selected {
                $0.selectedProjects.insert(project.persistentModelID)
            } else {
                $0.selectedProjects.remove(project.persistentModelID)
            }
        }
    }

    // MARK: - Removing

    func isRemoved(_ role: Role) -> Bool {
        edits.removedRoles.contains(role.persistentModelID)
    }

    func setRemoved(_ role: Role, _ removed: Bool) {
        apply {
            if removed {
                $0.removedRoles.insert(role.persistentModelID)
            } else {
                $0.removedRoles.remove(role.persistentModelID)
            }
        }
    }

    func isRemoved(_ entry: Education) -> Bool {
        edits.removedEducation.contains(entry.persistentModelID)
    }

    func setRemoved(_ entry: Education, _ removed: Bool) {
        apply {
            if removed {
                $0.removedEducation.insert(entry.persistentModelID)
            } else {
                $0.removedEducation.remove(entry.persistentModelID)
            }
        }
    }

    func isRemoved(interest: String) -> Bool { edits.removedInterests.contains(interest) }

    func setRemoved(interest: String, _ removed: Bool) {
        apply {
            if removed { $0.removedInterests.insert(interest) }
            else { $0.removedInterests.remove(interest) }
        }
    }

    func isRemoved(contactLine: String) -> Bool { edits.removedContactLines.contains(contactLine) }

    func setRemoved(contactLine: String, _ removed: Bool) {
        apply {
            if removed { $0.removedContactLines.insert(contactLine) }
            else { $0.removedContactLines.remove(contactLine) }
        }
    }

    var isHeadlineRemoved: Bool { edits.isHeadlineRemoved }

    func setHeadlineRemoved(_ removed: Bool) {
        apply { $0.isHeadlineRemoved = removed }
    }

    func isDropped(skill: String) -> Bool { edits.droppedSkills.contains(skill.lowercased()) }

    func setDropped(skill: String, _ dropped: Bool) {
        apply {
            if dropped { $0.droppedSkills.insert(skill.lowercased()) }
            else { $0.droppedSkills.remove(skill.lowercased()) }
        }
    }

    func isDropped(category: String) -> Bool {
        edits.droppedCategories.contains(category.lowercased())
    }

    func setDropped(category: String, _ dropped: Bool) {
        apply {
            if dropped { $0.droppedCategories.insert(category.lowercased()) }
            else { $0.droppedCategories.remove(category.lowercased()) }
        }
    }

    // MARK: - Rewording

    func wording(of achievement: Achievement) -> String {
        let id = achievement.persistentModelID
        if let reworded = edits.rewordings[id] { return reworded }
        if let item = review.items.first(where: { $0.achievement.persistentModelID == id }) {
            return item.accepted ? item.bullet : item.achievement.text
        }
        return achievement.text
    }

    func reword(_ achievement: Achievement, to text: String) {
        apply { $0.rewordings[achievement.persistentModelID] = text }
    }

    func rewordSummary(to text: String) {
        apply { $0.summary = text }
    }

    // MARK: - Tagging

    /// A user action, so it lands on the Profile immediately rather than
    /// waiting for the export — and survives discarding the preview.
    @discardableResult
    func applyTag(named name: String, to achievement: Achievement) throws -> SkillTag {
        let tag = try profileStore.tag(achievement, skillNamed: name)
        recompute()
        return tag
    }

    @discardableResult
    func applyTag(named name: String, to project: Project) throws -> SkillTag {
        let tag = try profileStore.tag(project, skillNamed: name)
        recompute()
        return tag
    }

    // MARK: - Re-scoring

    func relevanceStats(for achievement: Achievement) -> RelevanceStats? {
        relevance[achievement.persistentModelID]
    }

    func relevanceStats(for project: Project) -> RelevanceStats? {
        relevance[project.persistentModelID]
    }

    func rescore() async {
        guard let rescorePass else { return }
        let points = scoredPoints()
        guard !points.isEmpty else { return }
        isRescoring = true
        defer { isRescoring = false }
        do {
            let stats = try await rescorePass.rescore(
                points.map { RescoreItem(id: $0.id, text: $0.text) },
                jobDescription: jobDescription
            )
            var refreshed: [PersistentIdentifier: RelevanceStats] = [:]
            for point in points {
                if let judged = stats[point.id] { refreshed[point.model] = judged }
            }
            relevance = refreshed
            rescoreFailure = nil
        } catch {
            rescoreFailure =
                "The relevance scores couldn't be refreshed. Nothing on the CV changed — try again."
        }
    }

    private struct ScoredPoint {
        var id: String
        var model: PersistentIdentifier
        var text: String
    }

    private func scoredPoints() -> [ScoredPoint] {
        var points: [ScoredPoint] = []
        for role in edits.orderedRoles(of: profile) {
            for achievement in edits.selectedAchievements(of: role) {
                points.append(
                    ScoredPoint(
                        id: "s\(points.count)", model: achievement.persistentModelID,
                        text: wording(of: achievement)))
            }
        }
        for project in edits.selectedProjects(of: profile) {
            points.append(
                ScoredPoint(
                    id: "s\(points.count)", model: project.persistentModelID,
                    text: "\(project.name): \(project.details)"))
        }
        return points
    }

    // MARK: - Closing

    func requestClose() {
        if hasPendingEdits {
            isConfirmingDiscard = true
        } else {
            isClosed = true
        }
    }

    func confirmDiscard() {
        isConfirmingDiscard = false
        edits = pristine
        isClosed = true
    }

    func cancelDiscard() {
        isConfirmingDiscard = false
    }

    // MARK: - Re-layout

    private func apply(_ edit: (inout CVEditSet) -> Void) {
        edit(&edits)
        recompute()
    }

    private func recompute() {
        let document = edits.document(profile: profile, review: review)
        composition = CVComposition(
            fit: CVFitLoop.relayout(document, carrying: composed), outcome: review.outcome)
        coverage = edits.coverage(profile: profile, matchedTagNames: review.matchedTagNames)
    }
}
