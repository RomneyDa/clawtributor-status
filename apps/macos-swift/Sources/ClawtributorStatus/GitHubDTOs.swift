import Foundation

struct GraphQLEnvelope<T: Decodable>: Decodable {
    let data: T?
    let errors: [GraphQLError]?
}

struct GraphQLError: Decodable {
    let message: String
}

struct ContributionsQueryData: Decodable {
    let viewer: Viewer

    struct Viewer: Decodable {
        let login: String
        let name: String?
        let avatarUrl: String
        let url: String
        let contributionsCollection: ContributionsCollection
    }
}

struct ContributionsCollection: Decodable {
    let totalCommitContributions: Int
    let totalPullRequestContributions: Int
    let totalIssueContributions: Int
    let totalPullRequestReviewContributions: Int
    let restrictedContributionsCount: Int
    let totalRepositoriesWithContributedCommits: Int
    let totalRepositoriesWithContributedPullRequests: Int
    let totalRepositoriesWithContributedIssues: Int
    let commitContributionsByRepository: [RepositoryContribution]
    let pullRequestContributionsByRepository: [RepositoryContribution]
    let issueContributionsByRepository: [RepositoryContribution]
    let pullRequestReviewContributionsByRepository: [RepositoryContribution]
}

struct RepositoryContribution: Decodable {
    let repository: RepositoryRef
    let contributions: ContributionConnection
}

struct RepositoryRef: Decodable {
    let nameWithOwner: String
    let url: String
    let defaultBranchRef: DefaultBranchRef?
}

struct DefaultBranchRef: Decodable {
    let name: String
}

struct ContributionConnection: Decodable {
    let totalCount: Int
    let nodes: [CommitContributionNode]

    enum CodingKeys: String, CodingKey {
        case totalCount
        case nodes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        totalCount = try container.decode(Int.self, forKey: .totalCount)
        nodes = try container.decodeIfPresent([CommitContributionNode].self, forKey: .nodes) ?? []
    }
}

struct CommitContributionNode: Decodable {
    let commitCount: Int?
}

struct SearchQueryData: Decodable {
    let viewer: Viewer
    let pullRequests: SearchConnection<SearchNode>
    let issues: SearchConnection<SearchNode>
    let issueComments: SearchConnection<SearchNode>

    struct Viewer: Decodable {
        let login: String
    }
}

struct SearchConnection<T: Decodable>: Decodable {
    let nodes: [T]
    let pageInfo: PageInfo
}

struct PageInfo: Decodable {
    let hasNextPage: Bool
    let endCursor: String?
}

struct SearchNode: Decodable {
    let asPullRequest: PullRequestNode?
    let asIssue: IssueSearchNode?
    let asIssueCommentSource: IssueCommentSourceNode?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if container.allKeys.isEmpty {
            asPullRequest = nil
            asIssue = nil
            asIssueCommentSource = nil
            return
        }

        if let additions = try? container.decode(Int.self, forKey: .additions),
           let reviews = try? container.decode(Count.self, forKey: .reviews),
           let commits = try? container.decode(Count.self, forKey: .commits) {
            asPullRequest = PullRequestNode(
                title: try container.decode(String.self, forKey: .title),
                url: try container.decode(String.self, forKey: .url),
                state: try container.decode(String.self, forKey: .state),
                createdAt: try container.decode(String.self, forKey: .createdAt),
                mergedAt: try container.decodeIfPresent(String.self, forKey: .mergedAt),
                closedAt: try container.decodeIfPresent(String.self, forKey: .closedAt),
                comments: try container.decode(Count.self, forKey: .comments),
                reviews: reviews,
                commits: commits,
                additions: additions,
                deletions: try container.decode(Int.self, forKey: .deletions),
                changedFiles: try container.decode(Int.self, forKey: .changedFiles),
                repository: try container.decode(RepositoryName.self, forKey: .repository)
            )
            asIssue = nil
            asIssueCommentSource = nil
            return
        }

        if let title = try? container.decode(String.self, forKey: .title),
           let state = try? container.decode(String.self, forKey: .state) {
            asPullRequest = nil
            asIssue = IssueSearchNode(
                title: title,
                url: try container.decode(String.self, forKey: .url),
                state: state,
                createdAt: try container.decode(String.self, forKey: .createdAt),
                closedAt: try container.decodeIfPresent(String.self, forKey: .closedAt),
                comments: try container.decodeIfPresent(Count.self, forKey: .comments) ?? Count(totalCount: 0),
                repository: try container.decode(RepositoryName.self, forKey: .repository)
            )
            asIssueCommentSource = nil
            return
        }

        asPullRequest = nil
        asIssue = nil
        if let repository = try? container.decode(RepositoryName.self, forKey: .repository) {
            asIssueCommentSource = IssueCommentSourceNode(
                repository: repository,
                comments: try container.decodeIfPresent(CommentConnection.self, forKey: .comments) ?? CommentConnection(nodes: [])
            )
        } else {
            asIssueCommentSource = nil
        }
    }

    enum CodingKeys: String, CodingKey {
        case title
        case url
        case state
        case createdAt
        case mergedAt
        case closedAt
        case comments
        case reviews
        case commits
        case additions
        case deletions
        case changedFiles
        case repository
    }
}

struct PullRequestNode {
    let title: String
    let url: String
    let state: String
    let createdAt: String
    let mergedAt: String?
    let closedAt: String?
    let comments: Count
    let reviews: Count
    let commits: Count
    let additions: Int
    let deletions: Int
    let changedFiles: Int
    let repository: RepositoryName
}

struct IssueSearchNode {
    let title: String
    let url: String
    let state: String
    let createdAt: String
    let closedAt: String?
    let comments: Count
    let repository: RepositoryName
}

struct Count: Decodable {
    let totalCount: Int
}

struct RepositoryName: Decodable {
    let nameWithOwner: String
}

struct IssueCommentSourceNode {
    let repository: RepositoryName
    let comments: CommentConnection
}

struct CommentConnection: Decodable {
    let nodes: [IssueCommentNode]
}

struct IssueCommentNode: Decodable {
    let url: String
    let createdAt: String
    let bodyText: String
    let author: Author?
}

struct Author: Decodable {
    let login: String
}
