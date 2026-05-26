import SwiftUI

struct MetricsDashboard: View {
    let metrics: GitHubMetrics

    private let columns = [
        GridItem(.adaptive(minimum: 190), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                LazyVGrid(columns: columns, spacing: 12) {
                    MetricTile("Default commits", value: metrics.summary.defaultBranchCommits, systemImage: "arrow.triangle.branch")
                    MetricTile("PR commits", value: metrics.summary.nonDefaultBranchCommits, systemImage: "point.3.connected.trianglepath.dotted")
                    MetricTile("Open PRs", value: metrics.summary.pullRequestsOpen, systemImage: "circle")
                    MetricTile("Merged PRs", value: metrics.summary.pullRequestsMerged, systemImage: "checkmark.circle")
                    MetricTile("Issues opened", value: metrics.summary.issuesOpened, systemImage: "exclamationmark.circle")
                    MetricTile("Reviews/comments", value: metrics.summary.reviews + metrics.summary.issueComments, systemImage: "text.bubble")
                }
                HStack(alignment: .top, spacing: 16) {
                    RepositoryPanel(repositories: metrics.repositories)
                    PullRequestPanel(pullRequests: metrics.pullRequests)
                }
                HStack(alignment: .top, spacing: 16) {
                    IssuePanel(issues: metrics.issues)
                    CommentPanel(comments: metrics.comments)
                }
            }
            .padding(24)
        }
        .navigationTitle("OpenClaw Activity")
    }

    private var header: some View {
        HStack(spacing: 14) {
            AsyncImage(url: URL(string: metrics.viewer.avatarUrl)) { image in
                image.resizable()
            } placeholder: {
                Image(systemName: "person.crop.square")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(metrics.viewer.name ?? metrics.viewer.login)
                    .font(.title.bold())
                Text("@\(metrics.viewer.login) in \(metrics.organization) · \(formatDate(metrics.from)) to \(formatDate(metrics.to))")
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

private struct MetricTile: View {
    let label: String
    let value: Int
    let systemImage: String

    init(_ label: String, value: Int, systemImage: String) {
        self.label = label
        self.value = value
        self.systemImage = systemImage
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(.tint)
            Text(label)
                .foregroundStyle(.secondary)
            Text(value.formatted())
                .font(.system(size: 28, weight: .bold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(.quaternary)
        )
    }
}

private struct RepositoryPanel: View {
    let repositories: [RepositoryMetric]

    var body: some View {
        Panel(title: "Repositories", count: repositories.count) {
            ForEach(repositories.prefix(12)) { repo in
                Link(destination: URL(string: repo.url)!) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(repo.nameWithOwner)
                                .font(.headline)
                            Text(repo.defaultBranch)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(repo.defaultBranchCommits) commits")
                            .foregroundStyle(.secondary)
                    }
                }
                Divider()
            }
        }
    }
}

private struct PullRequestPanel: View {
    let pullRequests: [PullRequestMetric]

    var body: some View {
        Panel(title: "Pull Requests", count: pullRequests.count) {
            ForEach(pullRequests.prefix(10)) { pr in
                Link(destination: URL(string: pr.url)!) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            StateBadge(state: pr.state)
                            Text(pr.title)
                                .font(.headline)
                                .lineLimit(1)
                        }
                        Text("\(pr.repository) · \(pr.commits) commits · \(pr.reviews) reviews")
                            .foregroundStyle(.secondary)
                    }
                }
                Divider()
            }
        }
    }
}

private struct IssuePanel: View {
    let issues: [IssueMetric]

    var body: some View {
        Panel(title: "Issues", count: issues.count) {
            ForEach(issues.prefix(10)) { issue in
                Link(destination: URL(string: issue.url)!) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            StateBadge(state: issue.state)
                            Text(issue.title)
                                .font(.headline)
                                .lineLimit(1)
                        }
                        Text("\(issue.repository) · \(issue.comments) comments")
                            .foregroundStyle(.secondary)
                    }
                }
                Divider()
            }
        }
    }
}

private struct CommentPanel: View {
    let comments: [CommentMetric]

    var body: some View {
        Panel(title: "Recent Comments", count: comments.count) {
            ForEach(comments.prefix(10)) { comment in
                Link(destination: URL(string: comment.url)!) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(comment.bodyText.isEmpty ? "Comment" : comment.bodyText)
                            .font(.headline)
                            .lineLimit(1)
                        Text("\(comment.repository) · \(comment.createdAt)")
                            .foregroundStyle(.secondary)
                    }
                }
                Divider()
            }
        }
    }
}

private struct Panel<Content: View>: View {
    let title: String
    let count: Int
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Text(count.formatted())
                    .foregroundStyle(.secondary)
            }
            Divider()
            content
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(.quaternary)
        )
    }
}

private struct StateBadge: View {
    let state: String

    var body: some View {
        Text(state.lowercased())
            .font(.caption.bold())
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.14), in: Capsule())
            .foregroundStyle(color)
    }

    private var color: Color {
        switch state {
        case "OPEN": .green
        case "MERGED": .purple
        case "CLOSED": .red
        default: .secondary
        }
    }
}

private func formatDate(_ date: Date) -> String {
    date.formatted(.dateTime.month(.abbreviated).day().year())
}
