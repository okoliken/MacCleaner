import Foundation
import UniformTypeIdentifiers

/// Where macOS saves new captures: the user's custom location if one is set
/// (`defaults write com.apple.screencapture location …`), otherwise Desktop.
func screenCaptureSaveLocation() -> URL {
    if let path = CFPreferencesCopyAppValue("location" as CFString, "com.apple.screencapture" as CFString) as? String {
        return URL(fileURLWithPath: (path as NSString).expandingTildeInPath).standardizedFileURL
    }
    return FileManager.default.homeDirectoryForCurrentUser.appending(path: "Desktop").standardizedFileURL
}

/// Folders where captures pile up: the save location, plus Downloads (AirDropped or
/// downloaded recordings land there).
///
/// Only the top level of each folder is read. Captures the user deliberately filed into
/// a subfolder (e.g. a website's image assets) are never offered for cleaning.
func screenCaptureFolders() -> [URL] {
    let downloads = FileManager.default.homeDirectoryForCurrentUser.appending(path: "Downloads").standardizedFileURL
    let folders = [screenCaptureSaveLocation(), downloads]
    return folders.reduce(into: []) { unique, folder in
        if !unique.contains(folder) { unique.append(folder) }
    }
}

/// Filenames macOS (and the iOS Simulator) give captures, for files that lost their
/// capture tag — e.g. a recording AirDropped from another Mac.
private let captureNamePrefixes = ["Screenshot", "Screen Shot", "Screen Recording", "Simulator Screen"]

private func isScreenCapture(_ url: URL) -> Bool {
    ExtendedAttributes.has(ExtendedAttributes.isScreenCapture, at: url)
        || ExtendedAttributes.has(ExtendedAttributes.isScreenRecording, at: url)
        || captureNamePrefixes.contains { url.lastPathComponent.hasPrefix($0) }
}

private func isMovie(_ url: URL) -> Bool {
    guard let type = UTType(filenameExtension: url.pathExtension) else { return false }
    return type.conforms(to: .movie)
}

/// Lists every capture in `screenCaptureFolders()` by reading the folders directly.
///
/// Why not Spotlight: Desktop, Documents and Downloads are privacy-protected. Spotlight
/// silently hides their files from an app that hasn't been granted access — and never
/// shows the "allow access?" prompt, so the user can't fix it. Reading the folder
/// ourselves is what makes macOS ask.
private func listScreenCaptures() -> (captures: [URL], inaccessible: [URL]) {
    var captures: [URL] = []
    var inaccessible: [URL] = []

    for folder in screenCaptureFolders() {
        do {
            let entries = try FileManager.default.contentsOfDirectory(
                at: folder,
                includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .creationDateKey],
                options: [.skipsHiddenFiles]
            )
            captures += entries.filter { url in
                (try? url.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true
                    && isScreenCapture(url)
            }
        } catch CocoaError.fileReadNoPermission {
            // The user said no (or hasn't been asked yet). Report it so the UI can explain.
            inaccessible.append(folder)
        } catch {
            // Folder doesn't exist (e.g. no Downloads) — nothing to find there.
        }
    }
    return (captures, inaccessible)
}

private func fileItem(for url: URL) -> FileItem {
    let values = try? url.resourceValues(forKeys: [.fileSizeKey, .creationDateKey])
    return FileItem(
        url: url,
        sizeBytes: Int64(values?.fileSize ?? 0),
        created: values?.creationDate,
        lastUsed: ExtendedAttributes.lastUsed(at: url)
    )
}

public struct ScreenshotScanner: StorageScanner {
    public let name = "Screenshots"
    public init() {}

    public func scan() throws -> ScanResult {
        let listing = listScreenCaptures()
        return ScanResult(
            scannerName: name,
            items: listing.captures.filter { !isMovie($0) }.map(fileItem),
            inaccessibleFolders: listing.inaccessible
        )
    }
}

public struct ScreenRecordingScanner: StorageScanner {
    public let name = "Screen Recordings"
    public init() {}

    public func scan() throws -> ScanResult {
        let listing = listScreenCaptures()
        return ScanResult(
            scannerName: name,
            items: listing.captures.filter(isMovie).map(fileItem),
            inaccessibleFolders: listing.inaccessible
        )
    }
}
