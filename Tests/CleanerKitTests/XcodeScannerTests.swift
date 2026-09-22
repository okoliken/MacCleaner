import Foundation
import Testing
@testable import CleanerKit

/// Builds a throwaway `~/Library/Developer/Xcode`-shaped directory:
/// `DerivedData/<project>` plus `Archives/<date>/<name>.xcarchive`.
private func makeXcodeDirectory(
    derivedData: [String] = [],
    archives: [(name: String, untouchedDays: Int)] = []
) throws -> URL {
    let fileManager = FileManager.default
    let root = fileManager.temporaryDirectory.appending(path: UUID().uuidString)

    for project in derivedData {
        try fileManager.createDirectory(
            at: root.appending(path: "DerivedData/\(project)"),
            withIntermediateDirectories: true
        )
    }
    for archive in archives {
        let bundle = root.appending(path: "Archives/2020-01-01/\(archive.name).xcarchive")
        try fileManager.createDirectory(at: bundle, withIntermediateDirectories: true)
        let date = Date(timeIntervalSinceNow: -Double(archive.untouchedDays) * 86_400)
        try fileManager.setAttributes(
            [.creationDate: date, .modificationDate: date],
            ofItemAtPath: bundle.path
        )
    }
    return root
}

@Test func recentArchivesAreNotOffered() throws {
    let root = try makeXcodeDirectory(archives: [(name: "Fresh", untouchedDays: 5)])
    defer { try? FileManager.default.removeItem(at: root) }

    let result = try XcodeScanner(developerDirectory: root).scan()

    #expect(result.items.isEmpty, "an archive untouched for 5 days holds a live dSYM and must not be offered")
}

@Test func oldArchivesAndDerivedDataAreOffered() throws {
    let root = try makeXcodeDirectory(
        derivedData: ["MyApp-abcdef"],
        archives: [(name: "Shipped", untouchedDays: 60)]
    )
    defer { try? FileManager.default.removeItem(at: root) }

    let result = try XcodeScanner(developerDirectory: root).scan()

    #expect(Set(result.items.map(\.name)) == ["Shipped.xcarchive", "MyApp-abcdef"])
    #expect(result.inaccessibleFolders.isEmpty)
}
