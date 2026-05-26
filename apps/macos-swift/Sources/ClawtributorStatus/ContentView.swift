import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationSplitView {
            SidebarView()
        } detail: {
            DetailView()
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    model.refresh()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(model.token == nil || model.isLoading)
            }
        }
        .alert("Clawtributor Status", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("OK") {
                model.errorMessage = nil
            }
        } message: {
            Text(model.errorMessage ?? "")
        }
        .task {
            if model.token != nil, model.metrics == nil {
                model.refresh()
            }
        }
    }
}

private struct SidebarView: View {
    @EnvironmentObject private var model: AppModel
    private let ranges = [(30, "30d"), (90, "90d"), (365, "1y")]

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Clawtributor", systemImage: "chevron.left.forwardslash.chevron.right")
                        .font(.headline)
                    Text("OpenClaw GitHub activity")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
                .padding(.vertical, 8)
            }

            Section("Range") {
                Picker("Range", selection: $model.selectedDays) {
                    ForEach(ranges, id: \.0) { range in
                        Text(range.1).tag(range.0)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: model.selectedDays) { _, days in
                    model.selectRange(days: days)
                }
            }

            Section("Privacy") {
                Label("Scope: read:user", systemImage: "lock")
                Label("Org filter: openclaw", systemImage: "line.3.horizontal.decrease.circle")
                Label("Token stored in Keychain", systemImage: "key")
            }

            Section {
                if model.token == nil {
                    Button {
                        model.signIn()
                    } label: {
                        Label(model.isLoading ? "Waiting for GitHub" : "Sign in with GitHub", systemImage: "person.crop.circle.badge.checkmark")
                    }
                } else {
                    Button(role: .destructive) {
                        model.signOut()
                    } label: {
                        Label("Delete Local Token", systemImage: "trash")
                    }
                }
            }
        }
        .navigationTitle("Clawtributor")
    }
}

private struct DetailView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Group {
            if let metrics = model.metrics {
                MetricsDashboard(metrics: metrics)
            } else if let code = model.deviceCode {
                DeviceCodeView(code: code)
            } else if model.token == nil {
                SignInView()
            } else {
                ProgressView("Loading OpenClaw metrics")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .overlay {
            if model.isLoading && model.metrics != nil {
                ProgressView()
                    .padding(18)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }
}

private struct SignInView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "chevron.left.forwardslash.chevron.right")
                .font(.system(size: 54))
                .foregroundStyle(.tint)
            Text("Clawtributor Status")
                .font(.largeTitle.bold())
            Text("Sign in with GitHub to view your OpenClaw contribution activity. The app requests only read:user and stores the token locally.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 520)
            Button {
                model.signIn()
            } label: {
                Label("Sign in with GitHub", systemImage: "person.crop.circle.badge.checkmark")
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .disabled(model.isLoading)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct DeviceCodeView: View {
    let code: DeviceCodeResponse

    var body: some View {
        VStack(spacing: 14) {
            Text("Enter this code in GitHub")
                .font(.title2.bold())
            Text(code.userCode)
                .font(.system(size: 38, weight: .bold, design: .monospaced))
                .padding(.vertical, 8)
            Text(code.verificationUri)
                .foregroundStyle(.secondary)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
