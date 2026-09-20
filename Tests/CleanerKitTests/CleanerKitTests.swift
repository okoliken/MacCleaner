import Foundation
import Testing
@testable import CleanerKit

private func item(name: String, size: Int64, daysOld: Int?, lastUsedDaysAgo: Int? = nil) -> FileItem {
    FileItem(
        url: URL(fileURLWithPath: "/fake/\(name)"),
        sizeBytes: size,
        created: daysOld.map { Calendar.current.date(byAdding: .day, value: -$0, to: .now)! },
        lastUsed: lastUsedDaysAgo.map { Calendar.current.date(byAdding: .day, value: -$0, to: .now)! }
    )
}

@Test func itemsAreSortedBySizeLargestFirst() {
    let result = ScanResult(scannerName: "test", items: [
        item(name: "small.png", size: 10, daysOld: 5),
        item(name: "big.png", size: 1000, daysOld: 5),
    ])
    #expect(result.items.first?.name == "big.png")
    #expect(result.totalBytes == 1010)
}

@Test func filterKeepsOnlyOldUntouchedItems() {
    let result = ScanResult(scannerName: "test", items: [
        item(name: "old.png", size: 1, daysOld: 100),
        item(name: "new.png", size: 1, daysOld: 2),
        item(name: "old-but-recently-opened.png", size: 1, daysOld: 100, lastUsedDaysAgo: 1),
        item(name: "no-dates.png", size: 1, daysOld: nil),
    ])
    let old = result.filtered(untouchedForDays: 30)
    #expect(old.items.map(\.name) == ["old.png"])
}

@Test func trashingAMissingFileReportsFailureNotCrash() {
    let outcome = Cleaner.trash([item(name: "does-not-exist.png", size: 1, daysOld: 1)])
    #expect(outcome.trashed.isEmpty)
    #expect(outcome.failures.count == 1)
}

@Test func trashingARealFileWorks() throws {
    let dir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let file = dir.appending(path: "trash-me.txt")
    try "hello".write(to: file, atomically: true, encoding: .utf8)

    let outcome = Cleaner.trash([FileItem(url: file, sizeBytes: 5, created: .now, lastUsed: nil)])

    #expect(outcome.trashed.count == 1)
    #expect(!FileManager.default.fileExists(atPath: file.path))
    try? FileManager.default.removeItem(at: dir)
}
