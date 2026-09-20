import Foundation

/// A single file or directory found by a scanner.
public struct FileItem: Sendable, Hashable {
    public let url: URL
    public let sizeBytes: Int64
    public let created: Date?
    public let lastUsed: Date?
    public let isDirectory: Bool

    public init(url: URL, sizeBytes: Int64, created: Date?, lastUsed: Date?, isDirectory: Bool = false) {
        self.url = url
        self.sizeBytes = sizeBytes
        self.created = created
        self.lastUsed = lastUsed
        self.isDirectory = isDirectory
    }

    public var name: String { url.lastPathComponent }

    /// Days since the file was last touched (opened if known, otherwise created).
    public func daysUntouched(asOf now: Date = .now) -> Int? {
        guard let reference = lastUsed ?? created else { return nil }
        return Calendar.current.dateComponents([.day], from: reference, to: now).day
    }
}

/// Everything one scanner found in a single pass.
public struct ScanResult: Sendable {
    public let scannerName: String
    public let items: [FileItem]
    /// Folders the scanner wanted to read but macOS privacy settings blocked.
    public let inaccessibleFolders: [URL]

    public init(scannerName: String, items: [FileItem], inaccessibleFolders: [URL] = []) {
        self.scannerName = scannerName
        self.items = items.sorted { $0.sizeBytes > $1.sizeBytes }
        self.inaccessibleFolders = inaccessibleFolders
    }

    public var totalBytes: Int64 { items.reduce(0) { $0 + $1.sizeBytes } }
    public var count: Int { items.count }

    /// Keeps only items untouched for at least `days` days.
    /// Items with no known dates are kept out, so nothing recent is ever suggested by accident.
    public func filtered(untouchedForDays days: Int, asOf now: Date = .now) -> ScanResult {
        ScanResult(
            scannerName: scannerName,
            items: items.filter { ($0.daysUntouched(asOf: now) ?? -1) >= days },
            inaccessibleFolders: inaccessibleFolders
        )
    }
}
