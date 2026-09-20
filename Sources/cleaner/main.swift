import CleanerKit
import Foundation

// Test harness for CleanerKit. Usage:
//   cleaner scan [--older-than N]
//   cleaner clean <screenshots|recordings|xcode> [--older-than N] [--yes]

let scanners: [String: any StorageScanner] = [
    "screenshots": ScreenshotScanner(),
    "recordings": ScreenRecordingScanner(),
    "xcode": XcodeScanner(),
]

func humanSize(_ bytes: Int64) -> String {
    ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
}

func printUsageAndExit() -> Never {
    print("""
    usage: cleaner scan [--older-than N]
           cleaner clean <screenshots|recordings|xcode> [--older-than N] [--yes]
    """)
    exit(1)
}

var arguments = Array(CommandLine.arguments.dropFirst())

var olderThanDays: Int?
if let flagIndex = arguments.firstIndex(of: "--older-than") {
    guard flagIndex + 1 < arguments.count, let days = Int(arguments[flagIndex + 1]) else {
        printUsageAndExit()
    }
    olderThanDays = days
    arguments.removeSubrange(flagIndex...flagIndex + 1)
}

let skipConfirmation = arguments.contains("--yes")
arguments.removeAll { $0 == "--yes" }

@MainActor
func run(_ scanner: any StorageScanner) -> ScanResult {
    do {
        var result = try scanner.scan()
        for folder in result.inaccessibleFolders {
            print("🔒 \(scanner.name): no permission to read \(folder.path)")
        }
        if let days = olderThanDays {
            result = result.filtered(untouchedForDays: days)
        }
        return result
    } catch {
        print("⚠️  \(scanner.name) failed: \(error.localizedDescription)")
        return ScanResult(scannerName: scanner.name, items: [])
    }
}

switch arguments.first {
    case "scan", nil:
        print("🧹 Mac Cleaner — scanning…\n")
        var grandTotal: Int64 = 0
        for (icon, key) in [("📸", "screenshots"), ("🎥", "recordings"), ("🛠", "xcode")] {
            let result = run(scanners[key]!)
            print("\(icon) \(result.scannerName)")
            print("   \(result.count) items, \(humanSize(result.totalBytes))\n")
            grandTotal += result.totalBytes
        }
        print("──────────────────")
        print("Recoverable: \(humanSize(grandTotal))")
        if let days = olderThanDays {
            print("(only items untouched for \(days)+ days)")
        }
        
    case "clean":
        guard arguments.count >= 2, let scanner = scanners[arguments[1]] else {
            printUsageAndExit()
        }
        let result = run(scanner)
        guard result.count > 0 else {
            print("Nothing to clean for \(scanner.name).")
            exit(0)
        }
        
        print("\(scanner.name): \(result.count) items, \(humanSize(result.totalBytes))\n")
        for item in result.items.prefix(15) {
            let age = item.daysUntouched().map { "untouched \($0)d" } ?? "age unknown"
            print("  \(humanSize(item.sizeBytes).padding(toLength: 10, withPad: " ", startingAt: 0)) \(age.padding(toLength: 16, withPad: " ", startingAt: 0)) \(item.name)")
        }
        if result.count > 15 {
            print("  … and \(result.count - 15) more")
        }
        
        if !skipConfirmation {
            print("\nMove all \(result.count) items to Trash? [y/N] ", terminator: "")
            guard readLine()?.lowercased() == "y" else {
                print("Cancelled — nothing was touched.")
                exit(0)
            }
        }
    
    let outcome = Cleaner.trash(result.items)
    print("🗑  Moved \(outcome.trashed.count) items to Trash — recovered \(humanSize(outcome.recoveredBytes))")
    for failure in outcome.failures {
        print("⚠️  Could not trash \(failure.item.name): \(failure.reason)")
    }
    
default:
    printUsageAndExit()
}
