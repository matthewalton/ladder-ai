import Foundation
import SQLite3
import SwiftData

enum ProfileStoreError: Error, Equatable {
    case profileAlreadyExists
    case noProfile
    case nameRequired
    case aliasAlreadyInUse
    case renameBeyondRecase
}

enum ProfilePresentation: Equatable {
    case createProfile
    case editor
}

@MainActor
@Observable
final class ProfileStore {
    /// Exposed so sibling slices can open their own contexts on the same store.
    let container: ModelContainer
    private let context: ModelContext
    private(set) var profile: Profile?

    init(container: ModelContainer) {
        self.container = container
        self.context = ModelContext(container)
    }

    static func container(at url: URL? = nil, inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema(versionedSchema: LadderSchemaV3.self)
        if inMemory {
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try ModelContainer(
                for: schema, migrationPlan: LadderMigrationPlan.self,
                configurations: [configuration])
        }

        let storeURL = try url ?? defaultStoreURL()
        if storeStillCarriesTech(at: storeURL) {
            // Safety net before the one-way step: the store file set is
            // copied before anything opens it ([PROFILE-25], ADR 0004).
            try backUpStoreFiles(at: storeURL)
            // Staged migration only recognises the plan's checkpoints; a
            // lightweight open against V1 brings a pre-versioning store to
            // that checkpoint (an already-V1 store passes through untouched)
            // before the plan runs its custom stage.
            try bringStoreToV1(at: storeURL)
        }
        let configuration = ModelConfiguration(schema: schema, url: storeURL)
        return try ModelContainer(
            for: schema, migrationPlan: LadderMigrationPlan.self,
            configurations: [configuration])
    }

    /// The migration-gate discriminator, read with raw SQLite so the check
    /// itself never opens (and migrates) the store: an Achievement table
    /// still carrying the `tech` column (`ZTECH`) has not been through the
    /// fold.
    private static func storeStillCarriesTech(at url: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: url.path) else { return false }
        var db: OpaquePointer?
        guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            return false
        }
        defer { sqlite3_close(db) }
        var statement: OpaquePointer?
        let query = "SELECT sql FROM sqlite_master WHERE type = 'table' AND name = 'ZACHIEVEMENT'"
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else { return false }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW,
              let sql = sqlite3_column_text(statement, 0)
        else { return false }
        return String(cString: sql).contains("ZTECH")
    }

    private static func backUpStoreFiles(at url: URL) throws {
        for suffix in ["", "-wal", "-shm"] {
            let source = URL(fileURLWithPath: url.path + suffix)
            guard FileManager.default.fileExists(atPath: source.path) else { continue }
            let destination = URL(fileURLWithPath: url.path + suffix + ".pre-migration-backup")
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.copyItem(at: source, to: destination)
        }
    }

    /// Lightweight-only open/close against the frozen V1 schema — the same
    /// implicit migration every pre-versioning launch performed, ending
    /// exactly at the plan's first checkpoint.
    private static func bringStoreToV1(at url: URL) throws {
        let v1 = Schema(versionedSchema: LadderSchemaV1.self)
        let configuration = ModelConfiguration(schema: v1, url: url)
        _ = try ModelContainer(for: v1, configurations: [configuration])
    }

    /// The app's own store file, never SwiftData's default: `default.store`
    /// is shared by every unsandboxed SwiftData process on the machine, and
    /// whichever opens it last migrates it to its own schema, dropping the
    /// others' tables (ADR 0004; this destroyed the store on 2026-07-22).
    private static func defaultStoreURL() throws -> URL {
        let directory = URL.applicationSupportDirectory
            .appending(path: "Ladder", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true)
        return directory.appending(path: "Ladder.store")
    }

    func load() throws {
        profile = try context.fetch(FetchDescriptor<Profile>()).first
    }

    var presentation: ProfilePresentation {
        profile == nil ? .createProfile : .editor
    }

    // MARK: - Profile

    @discardableResult
    func createProfile(name: String, headline: String) throws -> Profile {
        guard try context.fetchCount(FetchDescriptor<Profile>()) == 0 else {
            throw ProfileStoreError.profileAlreadyExists
        }
        let created = Profile(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            headline: headline
        )
        context.insert(created)
        try context.save()
        profile = created
        return created
    }

    func updateIdentity(name: String, headline: String) throws {
        let profile = try requireProfile()
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ProfileStoreError.nameRequired }
        profile.name = trimmed
        profile.headline = headline
        touch(profile)
        try context.save()
    }

    /// Whole-struct assignment — mutating a nested field would not reliably
    /// mark the model changed.
    func updateContact(_ contact: ContactInfo) throws {
        let profile = try requireProfile()
        profile.contact = contact
        touch(profile)
        try context.save()
    }

    // MARK: - Replace

    func replaceProfile(with replacement: ProfileReplacement) throws {
        let name = replacement.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw ProfileStoreError.nameRequired }

        let target: Profile
        if let existing = try context.fetch(FetchDescriptor<Profile>()).first {
            for role in existing.roles { context.delete(role) }
            for education in existing.education { context.delete(education) }
            for project in existing.projects { context.delete(project) }
            for tag in existing.skills { context.delete(tag) }
            // An achievement with no surviving role (e.g. an ex-project point
            // left by the decisions/0009 migration) has no cascade to catch it.
            for orphan in try context.fetch(FetchDescriptor<Achievement>()) where orphan.role == nil {
                context.delete(orphan)
            }
            existing.interests = []
            existing.name = name
            existing.headline = replacement.headline
            existing.contact = replacement.contact
            target = existing
        } else {
            target = Profile(name: name, headline: replacement.headline, contact: replacement.contact)
            context.insert(target)
        }

        var tagPool: [SkillTag] = []
        func resolveTag(named rawName: String) -> SkillTag? {
            let tagName = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !tagName.isEmpty else { return nil }
            if let existing = tagPool.first(where: {
                $0.name.caseInsensitiveCompare(tagName) == .orderedSame
            }) {
                return existing
            }
            let tag = SkillTag(name: tagName)
            tagPool.append(tag)
            target.skills.append(tag)
            return tag
        }
        func makePoint(_ point: ReplacementPoint, sortIndex: Int) -> Achievement {
            let achievement = Achievement(
                text: point.text,
                title: Self.normalizedPrintField(point.title),
                impactMetric: point.impactMetric,
                sortIndex: sortIndex
            )
            for skillName in point.skills {
                guard let tag = resolveTag(named: skillName),
                      !achievement.skills.contains(where: { $0 === tag })
                else { continue }
                achievement.skills.append(tag)
            }
            return achievement
        }

        for role in replacement.roles {
            let created = Role(
                company: role.company, title: role.title, start: role.start, end: role.end,
                location: Self.normalizedPrintField(role.location),
                industry: Self.normalizedPrintField(role.industry)
            )
            target.roles.append(created)
            for (index, point) in role.achievements.enumerated() {
                created.achievements.append(makePoint(point, sortIndex: index))
            }
        }
        for education in replacement.education {
            target.education.append(Education(
                institution: education.institution,
                qualification: education.qualification,
                start: education.start,
                end: education.end,
                detail: education.detail
            ))
        }
        for (index, project) in replacement.projects.enumerated() {
            let created = Project(
                name: project.name, link: project.link, summary: project.summary,
                details: project.details, sortIndex: index
            )
            target.projects.append(created)
            for skillName in project.skills {
                guard let tag = resolveTag(named: skillName),
                      !created.skills.contains(where: { $0 === tag })
                else { continue }
                created.skills.append(tag)
            }
        }
        for rawInterest in replacement.interests {
            let interest = rawInterest.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !interest.isEmpty,
                  !target.interests.contains(where: {
                      $0.caseInsensitiveCompare(interest) == .orderedSame
                  })
            else { continue }
            target.interests.append(interest)
        }

        touch(target)
        try context.save()
        profile = target
    }

    // MARK: - Roles

    @discardableResult
    func addRole(company: String, title: String, start: Date, end: Date?) throws -> Role {
        let profile = try requireProfile()
        let role = Role(company: company, title: title, start: start, end: end)
        profile.roles.append(role)
        touch(profile)
        try context.save()
        return role
    }

    func updateRole(
        _ role: Role, company: String, title: String, start: Date, end: Date?,
        location: String?, industry: String?
    ) throws {
        let profile = try requireProfile()
        role.company = company
        role.title = title
        role.start = start
        role.end = end
        role.location = Self.normalizedPrintField(location)
        role.industry = Self.normalizedPrintField(industry)
        touch(profile)
        try context.save()
    }

    static func normalizedPrintField(_ raw: String?) -> String? {
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty
        else { return nil }
        return trimmed
    }

    func deleteRole(_ role: Role) throws {
        let profile = try requireProfile()
        context.delete(role)
        touch(profile)
        try context.save()
    }

    // MARK: - Achievements

    @discardableResult
    func addAchievement(to role: Role, text: String) throws -> Achievement {
        let profile = try requireProfile()
        let nextIndex = (role.achievements.map(\.sortIndex).max() ?? -1) + 1
        let achievement = Achievement(text: text, sortIndex: nextIndex)
        role.achievements.append(achievement)
        touch(profile)
        try context.save()
        return achievement
    }

    func moveAchievements(in role: Role, from source: IndexSet, to destination: Int) throws {
        let profile = try requireProfile()
        var ordered = role.orderedAchievements
        ordered.move(fromOffsets: source, toOffset: destination)
        for (index, achievement) in ordered.enumerated() {
            achievement.sortIndex = index
        }
        touch(profile)
        try context.save()
    }

    func updateAchievementDetails(
        _ achievement: Achievement,
        impactMetric: String?,
        strengthNotes: String?
    ) throws {
        let profile = try requireProfile()
        achievement.impactMetric = impactMetric
        achievement.strengthNotes = strengthNotes
        touch(profile)
        try context.save()
    }

    func updateAchievementText(_ achievement: Achievement, to text: String) throws {
        let profile = try requireProfile()
        achievement.text = text
        touch(profile)
        try context.save()
    }

    func updateAchievementTitle(_ achievement: Achievement, to rawTitle: String?) throws {
        let profile = try requireProfile()
        achievement.title = Self.normalizedPrintField(rawTitle)
        touch(profile)
        try context.save()
    }

    func deleteAchievement(_ achievement: Achievement) throws {
        let profile = try requireProfile()
        let siblings = achievement.role?.orderedAchievements ?? []
        context.delete(achievement)
        for (index, sibling) in siblings.filter({ $0 !== achievement }).enumerated() {
            sibling.sortIndex = index
        }
        touch(profile)
        try context.save()
    }

    // MARK: - Skills

    @discardableResult
    func tag(_ achievement: Achievement, skillNamed rawName: String) throws -> SkillTag {
        let profile = try requireProfile()
        let tag = resolvePoolTag(named: rawName, in: profile)
        if !achievement.skills.contains(where: { $0 === tag }) {
            achievement.skills.append(tag)
        }
        touch(profile)
        try context.save()
        return tag
    }

    private func resolvePoolTag(named rawName: String, in profile: Profile) -> SkillTag {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        if let existing = profile.skills.first(where: {
            $0.name.caseInsensitiveCompare(name) == .orderedSame
                || $0.aliases.contains(name.lowercased())
        }) {
            return existing
        }
        let tag = SkillTag(name: name)
        profile.skills.append(tag)
        return tag
    }

    func recordAlias(_ rawAlias: String, on tag: SkillTag) throws {
        let profile = try requireProfile()
        let alias = rawAlias.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !alias.isEmpty else { return }
        let collides = profile.skills.contains { poolTag in
            poolTag.name.caseInsensitiveCompare(alias) == .orderedSame
                || poolTag.aliases.contains(alias)
        }
        if collides { throw ProfileStoreError.aliasAlreadyInUse }
        tag.aliases.append(alias)
        touch(profile)
        try context.save()
    }

    /// A rename beyond a recase is a merge question the deferred pool
    /// manager owns ([PROFILE-30]).
    func recaseTag(_ tag: SkillTag, to rawName: String) throws {
        let profile = try requireProfile()
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard tag.name.caseInsensitiveCompare(name) == .orderedSame else {
            throw ProfileStoreError.renameBeyondRecase
        }
        tag.name = name
        touch(profile)
        try context.save()
    }

    func removeAlias(_ rawAlias: String, from tag: SkillTag) throws {
        let profile = try requireProfile()
        let alias = rawAlias.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        tag.aliases.removeAll { $0 == alias }
        touch(profile)
        try context.save()
    }

    func untag(_ achievement: Achievement, tag: SkillTag) throws {
        let profile = try requireProfile()
        achievement.skills.removeAll { $0 === tag }
        touch(profile)
        try context.save()
    }

    // MARK: - Education

    @discardableResult
    func addEducation(
        institution: String, qualification: String, start: Date, end: Date?, detail: String = ""
    ) throws -> Education {
        let profile = try requireProfile()
        let education = Education(
            institution: institution, qualification: qualification,
            start: start, end: end, detail: detail
        )
        profile.education.append(education)
        touch(profile)
        try context.save()
        return education
    }

    func updateEducation(
        _ education: Education,
        institution: String, qualification: String, start: Date, end: Date?, detail: String
    ) throws {
        let profile = try requireProfile()
        education.institution = institution
        education.qualification = qualification
        education.start = start
        education.end = end
        education.detail = detail
        touch(profile)
        try context.save()
    }

    func deleteEducation(_ education: Education) throws {
        let profile = try requireProfile()
        context.delete(education)
        touch(profile)
        try context.save()
    }

    // MARK: - Projects

    @discardableResult
    func addProject(
        name: String, link: String = "", summary: String = "", details: String = ""
    ) throws -> Project {
        let profile = try requireProfile()
        let nextIndex = (profile.projects.map(\.sortIndex).max() ?? -1) + 1
        let project = Project(
            name: name, link: link, summary: summary, details: details, sortIndex: nextIndex
        )
        profile.projects.append(project)
        touch(profile)
        try context.save()
        return project
    }

    func updateProject(
        _ project: Project, name: String, link: String, summary: String, details: String
    ) throws {
        let profile = try requireProfile()
        project.name = name
        project.link = link
        project.summary = summary
        project.details = details
        touch(profile)
        try context.save()
    }

    func deleteProject(_ project: Project) throws {
        let profile = try requireProfile()
        context.delete(project)
        for (index, remaining) in profile.orderedProjects.filter({ $0 !== project }).enumerated() {
            remaining.sortIndex = index
        }
        touch(profile)
        try context.save()
    }

    func moveProjects(from source: IndexSet, to destination: Int) throws {
        let profile = try requireProfile()
        var ordered = profile.orderedProjects
        ordered.move(fromOffsets: source, toOffset: destination)
        for (index, project) in ordered.enumerated() {
            project.sortIndex = index
        }
        touch(profile)
        try context.save()
    }

    @discardableResult
    func tag(_ project: Project, skillNamed rawName: String) throws -> SkillTag {
        let profile = try requireProfile()
        let tag = resolvePoolTag(named: rawName, in: profile)
        if !project.skills.contains(where: { $0 === tag }) {
            project.skills.append(tag)
        }
        touch(profile)
        try context.save()
        return tag
    }

    func untag(_ project: Project, tag: SkillTag) throws {
        let profile = try requireProfile()
        project.skills.removeAll { $0 === tag }
        touch(profile)
        try context.save()
    }

    // MARK: - Interests

    func addInterest(_ rawName: String) throws {
        let profile = try requireProfile()
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        guard !profile.interests.contains(where: {
            $0.caseInsensitiveCompare(name) == .orderedSame
        }) else { return }
        profile.interests.append(name)
        touch(profile)
        try context.save()
    }

    func removeInterest(at index: Int) throws {
        let profile = try requireProfile()
        guard profile.interests.indices.contains(index) else { return }
        profile.interests.remove(at: index)
        touch(profile)
        try context.save()
    }

    func moveInterests(from source: IndexSet, to destination: Int) throws {
        let profile = try requireProfile()
        profile.interests.move(fromOffsets: source, toOffset: destination)
        touch(profile)
        try context.save()
    }

    private func requireProfile() throws -> Profile {
        guard let profile else { throw ProfileStoreError.noProfile }
        return profile
    }

    private func touch(_ profile: Profile) {
        profile.updatedAt = .now
    }
}
