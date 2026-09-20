import CleanerKit
import Foundation

/// The app's single source of truth. Views read from it; it talks to CleanerKit.
/// @MainActor keeps all UI-visible state on the main thread; the slow disk work
/// happens in detached tasks so the popover never freezes.
@MainActor
@Observable
final class CleanerModel {
    enum Phase: Equatable {
        case idle
        case scanning
        case cleaning(category: String)
    }

    private(set) var phase: Phase = .idle
    private(set) var results: [ScanResult] = []
    private(set) var statusMessage: String?

    private let scanners: [any StorageScanner] = [
        ScreenshotScanner(),
        ScreenRecordingScanner(),
        XcodeScanner(),
    ]

    var totalBytes: Int64 { results.reduce(0) { $0 + $1.totalBytes } }

    /// Folder names macOS privacy settings are blocking, e.g. ["Desktop"]. Deduplicated
    /// because both screen-capture scanners read the same folders.
    var blockedFolderNames: [String] {
        let names = results.flatMap(\.inaccessibleFolders).map(\.lastPathComponent)
        return names.reduce(into: []) { unique, name in
            if !unique.contains(name) { unique.append(name) }
        }
    }

    func refresh() async {
        guard phase == .idle else { return }
        phase = .scanning
        let scanners = self.scanners
        // Task.detached moves the disk-walking off the main thread.
        results = await Task.detached(priority: .userInitiated) {
            scanners.compactMap { try? $0.scan() }
        }.value
        phase = .idle
    }

    func clean(_ result: ScanResult) async {
        guard phase == .idle, !result.items.isEmpty else { return }
        phase = .cleaning(category: result.scannerName)
        let items = result.items
        let outcome = await Task.detached(priority: .userInitiated) {
            Cleaner.trash(items)
        }.value

        var message = "Moved \(outcome.trashed.count) items (\(Self.humanSize(outcome.recoveredBytes))) to Trash"
        if !outcome.failures.isEmpty {
            message += " — \(outcome.failures.count) failed"
        }
        statusMessage = message

        phase = .idle
        await refresh()
    }

    static func humanSize(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
