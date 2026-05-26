import Foundation

@MainActor
final class GitHubMetricsService {
    private let decoder = JSONDecoder()

    func fetchMetrics(token: String, days: Int) async throws -> GitHubMetrics {
        let toDate = Date()
        let fromDate = Calendar(identifier: .gregorian).date(byAdding: .day, value: -days, to: toDate) ?? toDate
        let contributionsQuery = try SharedContract.query(named: "contributions")
        let activitySearchQuery = try SharedContract.query(named: "activity-search")

        let contributionData: ContributionsQueryData = try await graphql(
            token: token,
            query: contributionsQuery,
            variables: [
                "from": isoString(fromDate),
                "to": isoString(toDate)
            ]
        )

        let login = contributionData.viewer.login
        let dateQualifier = "created:\(dateOnly(fromDate))..\(dateOnly(toDate))"
        let searchData: SearchQueryData = try await graphql(
            token: token,
            query: activitySearchQuery,
            variables: [
                "pullRequestQuery": "is:pr org:\(AppConfig.targetOrganization) author:\(login) \(dateQualifier)",
                "issueQuery": "is:issue org:\(AppConfig.targetOrganization) author:\(login) \(dateQualifier)",
                "issueCommentQuery": "org:\(AppConfig.targetOrganization) commenter:\(login) \(dateQualifier)"
            ]
        )

        let collection = contributionData.viewer.contributionsCollection
        var repositories: [String: RepositoryMetric] = [:]
        let targetPrefix = "\(AppConfig.targetOrganization)/"

        func isTarget(_ contribution: RepositoryContribution) -> Bool {
            contribution.repository.nameWithOwner.lowercased().hasPrefix(targetPrefix)
        }

        for contribution in collection.commitContributionsByRepository.filter(isTarget) {
            var metric = repositories[contribution.repository.nameWithOwner] ?? repositoryMetric(for: contribution)
            metric.defaultBranchCommits += sumCommits(contribution)
            repositories[metric.nameWithOwner] = metric
        }

        for contribution in collection.pullRequestContributionsByRepository.filter(isTarget) {
            var metric = repositories[contribution.repository.nameWithOwner] ?? repositoryMetric(for: contribution)
            metric.pullRequests += contribution.contributions.totalCount
            repositories[metric.nameWithOwner] = metric
        }

        for contribution in collection.issueContributionsByRepository.filter(isTarget) {
            var metric = repositories[contribution.repository.nameWithOwner] ?? repositoryMetric(for: contribution)
            metric.issues += contribution.contributions.totalCount
            repositories[metric.nameWithOwner] = metric
        }

        for contribution in collection.pullRequestReviewContributionsByRepository.filter(isTarget) {
            var metric = repositories[contribution.repository.nameWithOwner] ?? repositoryMetric(for: contribution)
            metric.reviews += contribution.contributions.totalCount
            repositories[metric.nameWithOwner] = metric
        }

        let pullRequests = searchData.pullRequests.nodes.compactMap { node -> PullRequestMetric? in
            guard let pr = node.asPullRequest else { return nil }
            return PullRequestMetric(
                title: pr.title,
                url: pr.url,
                state: pr.state,
                repository: pr.repository.nameWithOwner,
                createdAt: pr.createdAt,
                mergedAt: pr.mergedAt,
                closedAt: pr.closedAt,
                comments: pr.comments.totalCount,
                reviews: pr.reviews.totalCount,
                commits: pr.commits.totalCount,
                additions: pr.additions,
                deletions: pr.deletions,
                changedFiles: pr.changedFiles
            )
        }

        let issues = searchData.issues.nodes.compactMap { node -> IssueMetric? in
            guard let issue = node.asIssue else { return nil }
            return IssueMetric(
                title: issue.title,
                url: issue.url,
                state: issue.state,
                repository: issue.repository.nameWithOwner,
                createdAt: issue.createdAt,
                closedAt: issue.closedAt,
                comments: issue.comments.totalCount
            )
        }

        let comments = searchData.issueComments.nodes.flatMap { node -> [CommentMetric] in
            guard let source = node.asIssueCommentSource else { return [] }
            return source.comments.nodes
                .filter { $0.author?.login == login && isInRange($0.createdAt, from: fromDate, to: toDate) }
                .map {
                    CommentMetric(
                        url: $0.url,
                        repository: source.repository.nameWithOwner,
                        createdAt: $0.createdAt,
                        bodyText: $0.bodyText
                    )
                }
        }

        let repositoryList = repositories.values.sorted {
            ($0.defaultBranchCommits + $0.pullRequests + $0.issues + $0.reviews) >
                ($1.defaultBranchCommits + $1.pullRequests + $1.issues + $1.reviews)
        }
        let defaultBranchCommits = repositoryList.reduce(0) { $0 + $1.defaultBranchCommits }
        let prBranchCommits = pullRequests.reduce(0) { $0 + $1.commits }
        let repositoriesTouched = Set(
            repositoryList.map(\.nameWithOwner) +
                pullRequests.map(\.repository) +
                issues.map(\.repository) +
                comments.map(\.repository)
        ).count

        return GitHubMetrics(
            viewer: ViewerProfile(
                login: contributionData.viewer.login,
                name: contributionData.viewer.name,
                avatarUrl: contributionData.viewer.avatarUrl,
                url: contributionData.viewer.url
            ),
            organization: AppConfig.targetOrganization,
            from: fromDate,
            to: toDate,
            summary: MetricSummary(
                totalCommits: defaultBranchCommits + prBranchCommits,
                defaultBranchCommits: defaultBranchCommits,
                nonDefaultBranchCommits: prBranchCommits,
                pullRequests: pullRequests.isEmpty ? collection.totalPullRequestContributions : pullRequests.count,
                pullRequestsOpen: pullRequests.filter { $0.state == "OPEN" }.count,
                pullRequestsMerged: pullRequests.filter { $0.state == "MERGED" }.count,
                pullRequestsClosed: pullRequests.filter { $0.state == "CLOSED" }.count,
                issuesOpened: issues.isEmpty ? collection.totalIssueContributions : issues.count,
                issuesOpen: issues.filter { $0.state == "OPEN" }.count,
                issuesClosed: issues.filter { $0.state == "CLOSED" }.count,
                reviews: collection.totalPullRequestReviewContributions,
                issueComments: comments.count,
                prReviewComments: 0,
                repositoriesTouched: repositoriesTouched,
                restrictedContributions: collection.restrictedContributionsCount
            ),
            repositories: repositoryList,
            pullRequests: pullRequests,
            issues: issues,
            comments: Array(comments.sorted { $0.createdAt > $1.createdAt }.prefix(100))
        )
    }

    private func graphql<T: Decodable>(token: String, query: String, variables: [String: Any]) async throws -> T {
        var request = URLRequest(url: AppConfig.graphqlURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "query": query,
            "variables": variables
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw AppError.message("GitHub GraphQL returned an unexpected response.")
        }

        let envelope = try decoder.decode(GraphQLEnvelope<T>.self, from: data)
        if let errors = envelope.errors, !errors.isEmpty {
            throw AppError.message(errors.map(\.message).joined(separator: "; "))
        }
        guard let decoded = envelope.data else {
            throw AppError.message("GitHub returned an empty response.")
        }
        return decoded
    }

    private func repositoryMetric(for contribution: RepositoryContribution) -> RepositoryMetric {
        RepositoryMetric(
            nameWithOwner: contribution.repository.nameWithOwner,
            url: contribution.repository.url,
            defaultBranch: contribution.repository.defaultBranchRef?.name ?? "default",
            defaultBranchCommits: 0,
            pullRequests: 0,
            issues: 0,
            reviews: 0
        )
    }

    private func sumCommits(_ contribution: RepositoryContribution) -> Int {
        let nodeSum = contribution.contributions.nodes.reduce(0) { $0 + ($1.commitCount ?? 0) }
        return nodeSum == 0 ? contribution.contributions.totalCount : nodeSum
    }
}

private func isoString(_ date: Date) -> String {
    ISO8601DateFormatter().string(from: date)
}

private func dateOnly(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: date)
}

private func isInRange(_ isoDate: String, from: Date, to: Date) -> Bool {
    guard let date = ISO8601DateFormatter().date(from: isoDate) else { return false }
    return date >= from && date <= to
}
