import SwiftUI

@main
struct ClawtributorStatusApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 980, minHeight: 680)
        }
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
