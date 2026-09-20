import Foundation

public struct TrashFailure: Sendable {
    public let item: FileItem
    public let reason: String
}

public struct TrashOutcome: Sendable {
    public let trashed: [FileItem]
    public let failures: [TrashFailure]

    public var recoveredBytes: Int64 { trashed.reduce(0) { $0 + $1.sizeBytes } }
}

/// The only type that touches files. Always moves to Trash — never deletes —
/// so every action stays undoable from Finder.
public enum Cleaner {
    @discardableResult
    public static func trash(_ items: [FileItem], fileManager: FileManager = .default) -> TrashOutcome {
        var trashed: [FileItem] = []
        var failures: [TrashFailure] = []

        for item in items {
            do {
                try fileManager.trashItem(at: item.url, resultingItemURL: nil)
                trashed.append(item)
            } catch {
                failures.append(TrashFailure(item: item, reason: error.localizedDescription))
            }
        }
        return TrashOutcome(trashed: trashed, failures: failures)
    }
}
