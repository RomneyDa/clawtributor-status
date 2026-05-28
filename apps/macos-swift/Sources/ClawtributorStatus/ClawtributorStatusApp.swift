import SwiftUI

@main
struct ClawtributorStatusApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .frame(width: 420, height: 560)
                .frame(minWidth: 360, minHeight: 440)
        }
        .windowResizability(.contentMinSize)
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
