import Darwin
import Foundation

/// Reads extended attributes ("xattrs"): small named tags macOS stores on a file
/// alongside its contents. `xattr -l <file>` in Terminal shows them.
///
/// macOS tags every screenshot and screen recording it makes, and these tags travel
/// with the file itself — so we can read them without asking Spotlight.
enum ExtendedAttributes {
    static let isScreenCapture = "com.apple.metadata:kMDItemIsScreenCapture"
    static let isScreenRecording = "com.apple.metadata:kMDItemIsScreenRecording"
    private static let lastUsedDate = "com.apple.lastuseddate#PS"

    /// `getxattr` with a nil buffer just asks "how big is it?"; -1 means it isn't there.
    static func has(_ name: String, at url: URL) -> Bool {
        getxattr(url.path, name, nil, 0, 0, XATTR_NOFOLLOW) >= 0
    }

    /// When the file was last opened — the same value as Finder's "Last opened" column.
    /// macOS stores it as a raw `timespec` (seconds + nanoseconds).
    static func lastUsed(at url: URL) -> Date? {
        var time = timespec()
        let expected = MemoryLayout<timespec>.size
        guard getxattr(url.path, lastUsedDate, &time, expected, 0, XATTR_NOFOLLOW) == expected else {
            return nil
        }
        return Date(timeIntervalSince1970: TimeInterval(time.tv_sec) + TimeInterval(time.tv_nsec) / 1_000_000_000)
    }
}
