import CoreTransferable
import SwiftData

/// The board's drag payload: just the Application's identity. JSON keeps the
/// generated Info.plist free of custom UTType declarations; if cross-app
/// json drops ever collide, upgrade to a declared type.
struct ApplicationDragItem: Codable, Transferable {
    let id: PersistentIdentifier

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .json)
    }
}
