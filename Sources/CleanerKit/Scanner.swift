import Foundation

/// A scanner reports what it finds; it never deletes anything itself.
public protocol StorageScanner: Sendable {
    var name: String { get }
    func scan() throws -> ScanResult
}
