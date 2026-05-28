import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            HeaderView()
            Divider()
            Group {
                if let metrics = model.metrics {
                    WidgetDashboard(metrics: metrics)
                } else if let code = model.deviceCode {
                    DeviceCodeView(code: code)
                } else if model.token == nil {
                    SignInView()
                } else {
                    LoadingView()
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .task {
            if model.token != nil, model.metrics == nil, !model.isLoading {
                model.refresh()
            }
        }
    }
}

private struct HeaderView: View {
    @EnvironmentObject private var model: AppModel
    private let ranges = [(30, "30d"), (90, "90d"), (365, "1y")]

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "chevron.left.forwardslash.chevron.right")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.tint)

            VStack(alignment: .leading, spacing: 1) {
                Text("Clawtributor")
                    .font(.headline)
                Text("openclaw")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if model.token != nil {
                Picker("Range", selection: $model.selectedDays) {
                    ForEach(ranges, id: \.0) { range in
                        Text(range.1).tag(range.0)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 132)
                .onChange(of: model.selectedDays) { _, days in
                    model.selectRange(days: days)
                }

                Button {
                    model.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh")
                .disabled(model.isLoading)

                Button {
                    model.signOut()
                } label: {
                    Image(systemName: "trash")
                }
                .help("Delete local token")
                .disabled(model.isLoading)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

private struct SignInView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "person.crop.circle")
                .font(.system(size: 42))
                .foregroundStyle(.secondary)

            Text("Clawtributor Status")
                .font(.title2.bold())

            Button {
                model.signIn()
            } label: {
                Label(model.isLoading ? "Waiting for GitHub" : "Sign in with GitHub", systemImage: "person.crop.circle.badge.checkmark")
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .disabled(model.isLoading)

            InlineStatusView()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct DeviceCodeView: View {
    @EnvironmentObject private var model: AppModel
    let code: DeviceCodeResponse

    var body: some View {
        VStack(spacing: 12) {
            Text("GitHub Code")
                .font(.headline)

            Text(code.userCode)
                .font(.system(size: 34, weight: .bold, design: .monospaced))
                .textSelection(.enabled)

            Text("Waiting for browser authorization")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            InlineStatusView()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct LoadingView: View {
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)
            Text("Loading OpenClaw metrics")
                .font(.headline)
            Text("Fetching GitHub activity")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            InlineStatusView()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct InlineStatusView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 10) {
            if model.isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(model.loadingMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let message = model.errorMessage {
                VStack(spacing: 8) {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    if model.token != nil {
                        Button("Retry") {
                            model.refresh()
                        }
                        .controlSize(.small)
                        .disabled(model.isLoading)
                    }
                }
                .padding(10)
                .background(.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}

private struct WidgetDashboard: View {
    let metrics: GitHubMetrics

    private var recentItems: [ActivityItem] {
        let prs = metrics.pullRequests.prefix(4).map {
            ActivityItem(title: $0.title, detail: $0.repository, url: $0.url, state: $0.state.lowercased())
        }
        let issues = metrics.issues.prefix(3).map {
            ActivityItem(title: $0.title, detail: $0.repository, url: $0.url, state: $0.state.lowercased())
        }
        return Array(prs + issues)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    AsyncImage(url: URL(string: metrics.viewer.avatarUrl)) { image in
                        image.resizable()
                    } placeholder: {
                        Image(systemName: "person.crop.square")
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 42, height: 42)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(metrics.viewer.name ?? metrics.viewer.login)
                            .font(.headline)
                            .lineLimit(1)
                        Text("@\(metrics.viewer.login) - \(formatDate(metrics.from)) to \(formatDate(metrics.to))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    SummaryTile("Commits", value: metrics.summary.totalCommits, image: "arrow.triangle.branch")
                    SummaryTile("Merged PRs", value: metrics.summary.pullRequestsMerged, image: "checkmark.circle")
                    SummaryTile("Issues", value: metrics.summary.issuesOpened, image: "exclamationmark.circle")
                    SummaryTile("Comments", value: metrics.summary.reviews + metrics.summary.issueComments, image: "text.bubble")
                }

                HStack(spacing: 10) {
                    MiniStat(label: "Repos", value: metrics.summary.repositoriesTouched)
                    MiniStat(label: "Open PRs", value: metrics.summary.pullRequestsOpen)
                    MiniStat(label: "Private", value: metrics.summary.restrictedContributions)
                }

                if !recentItems.isEmpty {
                    Text("Recent Activity")
                        .font(.headline)
                        .padding(.top, 2)

                    VStack(spacing: 0) {
                        ForEach(recentItems) { item in
                            Link(destination: URL(string: item.url)!) {
                                HStack(spacing: 8) {
                                    Text(item.state)
                                        .font(.caption2.bold())
                                        .foregroundStyle(.secondary)
                                        .frame(width: 46, alignment: .leading)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.title)
                                            .font(.subheadline)
                                            .lineLimit(1)
                                        Text(item.detail)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, 8)
                            }
                            if item.id != recentItems.last?.id {
                                Divider()
                            }
                        }
                    }
                    .padding(.horizontal, 10)
                    .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
                }

                InlineStatusView()
            }
            .padding(16)
        }
    }
}

private struct SummaryTile: View {
    let label: String
    let value: Int
    let image: String

    init(_ label: String, value: Int, image: String) {
        self.label = label
        self.value = value
        self.image = image
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Image(systemName: image)
                .foregroundStyle(.tint)
            Text(value.formatted())
                .font(.system(size: 24, weight: .bold))
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct MiniStat: View {
    let label: String
    let value: Int

    var body: some View {
        VStack(spacing: 2) {
            Text(value.formatted())
                .font(.headline)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct ActivityItem: Identifiable {
    var id: String { url }
    let title: String
    let detail: String
    let url: String
    let state: String
}

private func formatDate(_ date: Date) -> String {
    date.formatted(.dateTime.month(.abbreviated).day())
}
