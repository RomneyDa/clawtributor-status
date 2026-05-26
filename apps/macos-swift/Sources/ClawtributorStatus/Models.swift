import Foundation

struct ViewerProfile: Codable {
    let login: String
    let name: String?
    let avatarUrl: String
    let url: String
}

struct MetricSummary {
    let totalCommits: Int
    let defaultBranchCommits: Int
    let nonDefaultBranchCommits: Int
    let pullRequests: Int
    let pullRequestsOpen: Int
    let pullRequestsMerged: Int
    let pullRequestsClosed: Int
    let issuesOpened: Int
    let issuesOpen: Int
    let issuesClosed: Int
    let reviews: Int
    let issueComments: Int
    let prReviewComments: Int
    let repositoriesTouched: Int
    let restrictedContributions: Int
}

struct RepositoryMetric: Identifiable {
    var id: String { nameWithOwner }
    let nameWithOwner: String
    let url: String
    let defaultBranch: String
    var defaultBranchCommits: Int
    var pullRequests: Int
    var issues: Int
    var reviews: Int
}

struct PullRequestMetric: Identifiable {
    var id: String { url }
    let title: String
    let url: String
    let state: String
    let repository: String
    let createdAt: String
    let mergedAt: String?
    let closedAt: String?
    let comments: Int
    let reviews: Int
    let commits: Int
    let additions: Int
    let deletions: Int
    let changedFiles: Int
}

struct IssueMetric: Identifiable {
    var id: String { url }
    let title: String
    let url: String
    let state: String
    let repository: String
    let createdAt: String
    let closedAt: String?
    let comments: Int
}

struct CommentMetric: Identifiable {
    var id: String { url }
    let url: String
    let repository: String
    let createdAt: String
    let bodyText: String
}

struct GitHubMetrics {
    let viewer: ViewerProfile
    let organization: String
    let from: Date
    let to: Date
    let summary: MetricSummary
    let repositories: [RepositoryMetric]
    let pullRequests: [PullRequestMetric]
    let issues: [IssueMetric]
    let comments: [CommentMetric]
}

struct DeviceCodeResponse: Decodable {
    let deviceCode: String
    let userCode: String
    let verificationUri: String
    let expiresIn: Int
    let interval: Int

    enum CodingKeys: String, CodingKey {
        case deviceCode = "device_code"
        case userCode = "user_code"
        case verificationUri = "verification_uri"
        case expiresIn = "expires_in"
        case interval
    }
}

struct DeviceTokenResponse: Decodable {
    let accessToken: String?
    let tokenType: String?
    let scope: String?
    let error: String?
    let errorDescription: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case scope
        case error
        case errorDescription = "error_description"
    }
}
