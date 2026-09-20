import Foundation

/// Finds Xcode's regenerable build products: DerivedData folders and old Archives.
/// Everything here is safe to trash — Xcode rebuilds DerivedData on the next build.
public struct XcodeScanner: StorageScanner {
    public let name = "Xcode"

    private let developerDirectory: URL

    // FileManager isn't Sendable, so we don't store one — each method uses
    // FileManager.default at call time instead.
    public init() {
        self.developerDirectory = FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Library/Developer/Xcode")
    }

    public func scan() throws -> ScanResult {
        var items: [FileItem] = []
        items.append(contentsOf: children(of: developerDirectory.appending(path: "DerivedData")))
        items.append(contentsOf: children(of: developerDirectory.appending(path: "Archives"), recurseOneLevel: true))
        return ScanResult(scannerName: name, items: items)
    }

    /// Each immediate child directory becomes one item, sized by walking its contents.
    /// Archives nest one level deeper (Archives/<date>/<name>.xcarchive), hence `recurseOneLevel`.
    private func children(of directory: URL, recurseOneLevel: Bool = false) -> [FileItem] {
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey, .creationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return entries.flatMap { entry -> [FileItem] in
            guard (try? entry.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true else {
                return []
            }
            if recurseOneLevel {
                return children(of: entry)
            }
            let values = try? entry.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])
            return [FileItem(
                url: entry,
                sizeBytes: directorySize(of: entry),
                created: values?.creationDate,
                lastUsed: values?.contentModificationDate,
                isDirectory: true
            )]
        }
    }

    private func directorySize(of directory: URL) -> Int64 {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey]
        ) else { return 0 }

        var total: Int64 = 0
        for case let file as URL in enumerator {
            let values = try? file.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey])
            total += Int64(values?.totalFileAllocatedSize ?? values?.fileAllocatedSize ?? 0)
        }
        return total
    }
}
