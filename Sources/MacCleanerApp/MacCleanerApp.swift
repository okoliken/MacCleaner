import SwiftUI

@main
struct MacCleanerApp: App {
    @State private var model = CleanerModel()

    init() {
        // Menu-bar-only: no Dock icon. The .app bundle gets this from LSUIElement
        // in Info.plist; this line covers `swift run`, which has no Info.plist.
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra("Mac Cleaner", systemImage: "sparkles") {
            DashboardView(model: model)
                .frame(width: 320)
        }
        .menuBarExtraStyle(.window)
    }
}
