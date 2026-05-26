import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Form {
            Section("GitHub") {
                Text("OAuth client ID: \(AppConfig.githubClientId)")
                Text("Scope: \(AppConfig.oauthScope)")
                Text("Organization filter: \(AppConfig.targetOrganization)")
            }
            Section("Local Data") {
                Button("Delete Local GitHub Token", role: .destructive) {
                    model.signOut()
                }
            }
        }
        .padding(20)
        .frame(width: 460)
    }
}
