import SwiftData
import SwiftUI

/// View-layer labels for the board's chrome; the models stay label-free.
extension ApplicationStatus {
    var columnTitle: String {
        switch self {
        case .draft: "Draft"
        case .applied: "Applied"
        case .active: "Active"
        case .offer: "Offer"
        case .rejected: "Rejected"
        case .withdrawn: "Withdrawn"
        }
    }
}

extension StageKind {
    var label: String {
        switch self {
        case .screen: "Screen"
        case .recruiter: "Recruiter"
        case .technical: "Technical"
        case .systemDesign: "System design"
        case .takeHome: "Take-home"
        case .behavioral: "Behavioral"
        case .final: "Final"
        case .offer: "Offer"
        case .other(let label): label
        }
    }
}

extension StageOutcome {
    var label: String {
        switch self {
        case .pending: "Pending"
        case .passed: "Passed"
        case .failed: "Failed"
        case .noResponse: "No response"
        }
    }
}

/// One application on the board (DESIGN.md §6): company + role in SF Pro,
/// next waypoint chip, quiet elapsed-time footer. No progress bars, no
/// percentages. A closed trail (rejected/withdrawn) desaturates to
/// mist/inkSoft.
struct ApplicationCardView: View {
    var application: Application

    private var isClosed: Bool {
        application.status == .rejected || application.status == .withdrawn
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(application.company)
                .font(.headline)
                .foregroundStyle(isClosed ? Color.inkSoft : Color.ink)
            Text(application.roleTitle)
                .font(.subheadline)
                .foregroundStyle(Color.inkSoft)

            if let waypoint = PipelineStore.nextWaypoint(for: application), !isClosed {
                Text(waypoint.label)
                    .font(.caption)
                    .foregroundStyle(Color.pine)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.pineTint, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            }

            Text("\(PipelineStore.daysOnTrail(for: application, asOf: .now)) days on trail")
                .trailMetadata()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            isClosed ? Color.mist.opacity(0.4) : Color.paperRaised,
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.mist, lineWidth: 1)
        )
    }
}

#Preview {
    let application = Application(
        company: "Summit Labs", roleTitle: "Platform Engineer",
        jobDescription: "Own platform reliability.", status: .active,
        appliedAt: .now.addingTimeInterval(-12 * 86_400)
    )
    return ApplicationCardView(application: application)
        .frame(width: 240)
        .padding()
        .background(Color.paper)
}
