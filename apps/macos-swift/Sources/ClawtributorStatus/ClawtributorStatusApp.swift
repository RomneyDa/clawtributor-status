import AppKit
import SwiftUI

@main
struct ClawtributorStatusApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .frame(width: 360)
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    model.shutdown()
                }
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Delete Local GitHub Token") {
                    model.signOut()
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])
            }
        }
        Settings {
            SettingsView()
                .environmentObject(model)
        }
    }
}
