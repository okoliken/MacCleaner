import CoreServices
import Foundation

/// Thin synchronous wrapper around the Spotlight MDQuery C API.
/// Used instead of NSMetadataQuery so scanners work without a run loop (CLI, tests, background tasks).
enum Spotlight {
    static func find(_ queryString: String) -> [FileItem] {
        guard let query = MDQueryCreate(kCFAllocatorDefault, queryString as CFString, nil, nil) else {
            return []
        }
        MDQuerySetSearchScope(query, [kMDQueryScopeHome] as CFArray, 0)
        guard MDQueryExecute(query, CFOptionFlags(kMDQuerySynchronous.rawValue)) else {
            return []
        }

        var items: [FileItem] = []
        for index in 0..<MDQueryGetResultCount(query) {
            guard let pointer = MDQueryGetResultAtIndex(query, index) else { continue }
            let mdItem = Unmanaged<MDItem>.fromOpaque(pointer).takeUnretainedValue()
            guard let path = MDItemCopyAttribute(mdItem, kMDItemPath) as? String else { continue }

            let size = (MDItemCopyAttribute(mdItem, kMDItemFSSize) as? NSNumber)?.int64Value ?? 0
            let created = MDItemCopyAttribute(mdItem, kMDItemContentCreationDate) as? Date
            let lastUsed = MDItemCopyAttribute(mdItem, kMDItemLastUsedDate) as? Date

            items.append(FileItem(
                url: URL(fileURLWithPath: path),
                sizeBytes: size,
                created: created,
                lastUsed: lastUsed
            ))
        }
        return items
    }
}
