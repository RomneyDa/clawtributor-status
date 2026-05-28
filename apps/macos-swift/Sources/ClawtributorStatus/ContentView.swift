import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @State private var selectedRepo: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            CompactHeader()
            Divider()
            Group {
                if let metrics = model.metrics {
                    WidgetGrid(metrics: metrics, selectedRepo: $selectedRepo)
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
        .tint(OpenClawBrand.lobster)
        .task {
            if model.token != nil, model.metrics == nil, !model.isLoading {
                model.refresh()
            }
        }
    }
}

private struct LobsterMark: View {
    var size: CGFloat = 18

    var body: some View {
        Group {
            if let nsImage = OpenClawBrand.lobsterImage {
                Image(nsImage: nsImage)
                    .resizable()
                    .interpolation(.none)
            } else {
                Image(systemName: "tortoise.fill")
                    .resizable()
                    .foregroundStyle(OpenClawBrand.lobster)
            }
        }
        .frame(width: size, height: size)
    }
}

private let rangeOptions: [(Int, String)] = [
    (1, "24h"),
    (7, "7d"),
    (30, "30d"),
    (90, "90d"),
    (365, "1y")
]

private struct CompactHeader: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HStack(spacing: 8) {
            if let metrics = model.metrics {
                AsyncImage(url: URL(string: metrics.viewer.avatarUrl)) { image in
                    image.resizable()
                } placeholder: {
                    Image(systemName: "person.crop.circle")
                        .foregroundStyle(.secondary)
                }
                .frame(width: 22, height: 22)
                .clipShape(Circle())

                Text("@\(metrics.viewer.login)")
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
            } else {
                LobsterMark(size: 18)
                Text("Clawtributor")
                    .font(.system(size: 12, weight: .semibold))
            }

            Spacer(minLength: 6)

            if model.token != nil {
                Picker("Range", selection: $model.selectedDays) {
                    ForEach(rangeOptions, id: \.0) { range in
                        Text(range.1).tag(range.0)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .controlSize(.small)
                .frame(width: 168)
                .onChange(of: model.selectedDays) { _, days in
                    model.selectRange(days: days)
                }

                Button {
                    model.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Refresh")
                .disabled(model.isLoading)

                Button {
                    model.signOut()
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Delete local token")
                .disabled(model.isLoading)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }
}

private struct RepoFilterBar: View {
    @EnvironmentObject private var model: AppModel
    let metrics: GitHubMetrics
    @Binding var selectedRepo: String?

    private var repoNames: [String] {
        metrics.repositories.map(\.nameWithOwner).sorted()
    }

    var body: some View {
        HStack(spacing: 6) {
            Menu {
                Button {
                    selectedRepo = nil
                } label: {
                    if selectedRepo == nil {
                        Label("All repos", systemImage: "checkmark")
                    } else {
                        Text("All repos")
                    }
                }
                if !repoNames.isEmpty {
                    Divider()
                    ForEach(repoNames, id: \.self) { name in
                        Button {
                            selectedRepo = name
                        } label: {
                            if selectedRepo == name {
                                Label(name, systemImage: "checkmark")
                            } else {
                                Text(name)
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "folder")
                        .font(.system(size: 10))
                    Text(selectedRepo ?? "All repos")
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8))
                }
                .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            if model.isLoading {
                ProgressView()
                    .controlSize(.small)
                    .scaleEffect(0.65)
                    .frame(width: 14, height: 14)
            }

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
    }
}

private struct FilteredStats {
    var commits: Int
    var prsMerged: Int
    var prsOpen: Int
    var prsTotal: Int
    var additions: Int
    var deletions: Int
    var filesChanged: Int
    var issues: Int
    var reviews: Int
    var comments: Int
    var repos: Int
    var restricted: Int
}

private func computeStats(from metrics: GitHubMetrics, repo: String?) -> FilteredStats {
    if let repo {
        let repoEntry = metrics.repositories.first { $0.nameWithOwner == repo }
        let prs = metrics.pullRequests.filter { $0.repository == repo }
        let issues = metrics.issues.filter { $0.repository == repo }
        let comments = metrics.comments.filter { $0.repository == repo }
        return FilteredStats(
            commits: repoEntry?.defaultBranchCommits ?? 0,
            prsMerged: prs.filter { $0.state == "MERGED" }.count,
            prsOpen: prs.filter { $0.state == "OPEN" }.count,
            prsTotal: prs.count,
            additions: prs.reduce(0) { $0 + $1.additions },
            deletions: prs.reduce(0) { $0 + $1.deletions },
            filesChanged: prs.reduce(0) { $0 + $1.changedFiles },
            issues: issues.count,
            reviews: repoEntry?.reviews ?? 0,
            comments: comments.count,
            repos: 1,
            restricted: 0
        )
    }

    let s = metrics.summary
    let prs = metrics.pullRequests
    return FilteredStats(
        commits: s.totalCommits,
        prsMerged: s.pullRequestsMerged,
        prsOpen: s.pullRequestsOpen,
        prsTotal: s.pullRequests,
        additions: prs.reduce(0) { $0 + $1.additions },
        deletions: prs.reduce(0) { $0 + $1.deletions },
        filesChanged: prs.reduce(0) { $0 + $1.changedFiles },
        issues: s.issuesOpened,
        reviews: s.reviews,
        comments: s.issueComments + s.prReviewComments,
        repos: s.repositoriesTouched,
        restricted: s.restrictedContributions
    )
}

private struct WidgetGrid: View {
    let metrics: GitHubMetrics
    @Binding var selectedRepo: String?

    private var stats: FilteredStats {
        computeStats(from: metrics, repo: selectedRepo)
    }

    private var mergeRate: Int {
        guard stats.prsTotal > 0 else { return 0 }
        return Int((Double(stats.prsMerged) / Double(stats.prsTotal)) * 100.0)
    }

    private var avgPrSize: Int {
        let prs = selectedRepo == nil
            ? metrics.pullRequests
            : metrics.pullRequests.filter { $0.repository == selectedRepo }
        guard !prs.isEmpty else { return 0 }
        let total = prs.reduce(0) { $0 + $1.additions + $1.deletions }
        return total / prs.count
    }

    private var topRepo: String? {
        if let selectedRepo { return selectedRepo }
        return metrics.repositories
            .max(by: { ($0.defaultBranchCommits + $0.pullRequests) < ($1.defaultBranchCommits + $1.pullRequests) })?
            .nameWithOwner
    }

    var body: some View {
        VStack(spacing: 6) {
            RepoFilterBar(metrics: metrics, selectedRepo: $selectedRepo)

            let columns = Array(repeating: GridItem(.flexible(), spacing: 5), count: 3)
            LazyVGrid(columns: columns, spacing: 5) {
                StatCell(value: stats.commits, label: "commits", tint: OpenClawBrand.lobster)
                StatCell(value: stats.prsMerged, label: "merged", tint: .purple)
                StatCell(value: stats.prsOpen, label: "open PRs", tint: .green)
                StatCell(value: stats.additions, label: "added", prefix: "+", tint: .green)
                StatCell(value: stats.deletions, label: "deleted", prefix: "−", tint: .red)
                StatCell(value: stats.filesChanged, label: "files", tint: .orange)
                StatCell(value: stats.issues, label: "issues", tint: .yellow)
                StatCell(value: stats.reviews, label: "reviews", tint: .cyan)
                StatCell(value: stats.comments, label: "comments", tint: .pink)
            }
            .padding(.horizontal, 8)

            FooterLine(
                dateRange: "\(formatDate(metrics.from))–\(formatDate(metrics.to))",
                repos: stats.repos,
                mergeRate: mergeRate,
                avgPrSize: avgPrSize,
                topRepo: topRepo,
                restricted: stats.restricted
            )
            .padding(.horizontal, 8)

            InlineStatusView()
                .padding(.horizontal, 8)
        }
        .padding(.bottom, 8)
    }
}

private struct StatCell: View {
    let value: Int
    let label: String
    var prefix: String = ""
    let tint: Color

    private var formatted: String {
        if value >= 10_000 {
            return value.formatted(.number.notation(.compactName))
        }
        return value.formatted()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(prefix)\(formatted)")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 6))
    }
}

private struct FooterLine: View {
    let dateRange: String
    let repos: Int
    let mergeRate: Int
    let avgPrSize: Int
    let topRepo: String?
    let restricted: Int

    var body: some View {
        VStack(spacing: 1) {
            HStack(spacing: 10) {
                Label("\(repos) repos", systemImage: "folder")
                Label("\(mergeRate)% merged", systemImage: "checkmark.seal")
                Label("\(avgPrSize) Δ/PR", systemImage: "arrow.up.arrow.down")
                if restricted > 0 {
                    Label("\(restricted)", systemImage: "lock")
                }
            }
            .font(.system(size: 9))
            .labelStyle(.titleAndIcon)
            .foregroundStyle(.secondary)

            HStack(spacing: 4) {
                if let topRepo {
                    Text("top: \(topRepo)")
                    Text("·")
                }
                Text(dateRange)
            }
            .font(.system(size: 9))
            .foregroundStyle(.tertiary)
            .lineLimit(1)
        }
        .padding(.top, 1)
    }
}

private struct SignInView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 10) {
            LobsterMark(size: 48)

            Button {
                model.signIn()
            } label: {
                Label(model.isLoading ? "Waiting for GitHub" : "Sign in with GitHub", systemImage: "person.crop.circle.badge.checkmark")
            }
            .controlSize(.regular)
            .buttonStyle(.borderedProminent)
            .disabled(model.isLoading)

            InlineStatusView()
        }
        .padding(16)
    }
}

private struct DeviceCodeView: View {
    @EnvironmentObject private var model: AppModel
    let code: DeviceCodeResponse

    var body: some View {
        VStack(spacing: 8) {
            Text("GitHub code")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            Text(code.userCode)
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .textSelection(.enabled)

            Text("Waiting for browser authorization")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)

            InlineStatusView()
        }
        .padding(16)
    }
}

private struct LoadingView: View {
    var body: some View {
        VStack(spacing: 8) {
            LobsterMark(size: 36)
            ProgressView()
                .controlSize(.small)
            Text("Loading OpenClaw metrics")
                .font(.system(size: 11, weight: .semibold))
            InlineStatusView()
        }
        .padding(16)
    }
}

private struct InlineStatusView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 6) {
            if let message = model.errorMessage {
                VStack(spacing: 6) {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .font(.system(size: 10))
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
                .padding(6)
                .background(.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
            }
        }
    }
}

private func formatDate(_ date: Date) -> String {
    date.formatted(.dateTime.month(.abbreviated).day())
}
