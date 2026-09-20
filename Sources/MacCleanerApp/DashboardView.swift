import CleanerKit
import SwiftUI

struct DashboardView: View {
    let model: CleanerModel
    @State private var pendingConfirmation: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("🧹 Mac Cleaner")
                    .font(.headline)
                Spacer()
                if model.phase == .scanning {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            Divider()

            if model.results.isEmpty {
                Text(model.phase == .scanning ? "Scanning…" : "Nothing found yet.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                ForEach(model.results, id: \.scannerName) { result in
                    CategoryRow(
                        result: result,
                        isBusy: model.phase == .cleaning(category: result.scannerName),
                        isConfirming: pendingConfirmation == result.scannerName,
                        onCleanTapped: { pendingConfirmation = result.scannerName },
                        onConfirm: {
                            pendingConfirmation = nil
                            Task { await model.clean(result) }
                        },
                        onCancel: { pendingConfirmation = nil }
                    )
                }
            }

            if !model.blockedFolderNames.isEmpty {
                PermissionBanner(folderNames: model.blockedFolderNames)
            }

            Divider()

            HStack {
                Text("Recoverable: \(CleanerModel.humanSize(model.totalBytes))")
                    .font(.callout.weight(.semibold))
                Spacer()
                Button("Rescan") {
                    Task { await model.refresh() }
                }
                .disabled(model.phase != .idle)
            }

            if let message = model.statusMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Spacer()
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .font(.caption)
            }
        }
        .padding(12)
        .task { await model.refresh() }
    }
}

/// Shown when macOS privacy settings block a folder we need. Once the user has
/// clicked "Don't Allow", macOS won't ask again — only System Settings can fix it.
private struct PermissionBanner: View {
    let folderNames: [String]

    private static let filesAndFoldersSettings =
        URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_FilesAndFolders")!

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "lock.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 4) {
                Text("No access to \(folderNames.formatted(.list(type: .and)))")
                    .font(.callout.weight(.semibold))
                Text("Turn on Mac Cleaner in System Settings › Privacy & Security › Files & Folders, then Rescan.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Open Settings") {
                    NSWorkspace.shared.open(Self.filesAndFoldersSettings)
                }
                .controlSize(.small)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.12), in: .rect(cornerRadius: 8))
    }
}

private struct CategoryRow: View {
    let result: ScanResult
    let isBusy: Bool
    let isConfirming: Bool
    let onCleanTapped: () -> Void
    let onConfirm: () -> Void
    let onCancel: () -> Void

    private var icon: String {
        switch result.scannerName {
        case "Screenshots": "camera.viewfinder"
        case "Screen Recordings": "video"
        case "Xcode": "hammer"
        default: "doc"
        }
    }

    var body: some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundStyle(.tint)

            VStack(alignment: .leading, spacing: 1) {
                Text(result.scannerName)
                    .font(.body)
                Text("\(result.count) items · \(CleanerModel.humanSize(result.totalBytes))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isBusy {
                ProgressView()
                    .controlSize(.small)
            } else if isConfirming {
                Button("Trash \(result.count)?", role: .destructive, action: onConfirm)
                    .controlSize(.small)
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                }
                .controlSize(.small)
            } else {
                Button("Clean", action: onCleanTapped)
                    .controlSize(.small)
                    .disabled(result.count == 0)
            }
        }
    }
}
