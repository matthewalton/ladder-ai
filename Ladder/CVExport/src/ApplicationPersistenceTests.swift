import Foundation
import SwiftData
import Testing

@testable import Ladder

@MainActor
struct ApplicationPersistenceTests {
    @Test("[CVEXPORT-11] a fully-populated Application round-trips through a store reopen")
    func fullyPopulatedApplicationRoundTrips() throws {
        let url = temporaryStoreURL()
        defer { removeStore(at: url) }
        let snapshot = Data("not a real PDF, but exact bytes are the point".utf8)
        let createdAt = Date(timeIntervalSince1970: 1_770_000_000)

        do {
            let container = try ProfileStore.container(at: url)
            let context = ModelContext(container)
            context.insert(
                Application(
                    company: "Summit Labs",
                    roleTitle: "Platform Engineer",
                    jobDescription: "Own platform reliability.",
                    status: .applied,
                    cvSnapshot: snapshot,
                    cvSelectionRationale: "CI work maps directly to the JD's platform focus.",
                    createdAt: createdAt
                )
            )
            try context.save()
        }

        let reopened = try ProfileStore.container(at: url)
        let context = ModelContext(reopened)
        let applications = try context.fetch(FetchDescriptor<Application>())
        #expect(applications.count == 1)
        let application = try #require(applications.first)
        #expect(application.company == "Summit Labs")
        #expect(application.roleTitle == "Platform Engineer")
        #expect(application.jobDescription == "Own platform reliability.")
        #expect(application.status == .applied)
        #expect(application.cvSnapshot == snapshot, "snapshot bytes are byte-equal after reopen")
        #expect(application.cvSelectionRationale == "CI work maps directly to the JD's platform focus.")
        #expect(application.createdAt == createdAt)
    }
}
