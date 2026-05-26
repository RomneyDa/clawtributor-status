export type PullRequestState = "OPEN" | "CLOSED" | "MERGED";

export interface ViewerProfile {
  login: string;
  name: string | null;
  avatarUrl: string;
  url: string;
}

export interface MetricSummary {
  totalCommits: number;
  defaultBranchCommits: number;
  nonDefaultBranchCommits: number;
  pullRequests: number;
  pullRequestsOpen: number;
  pullRequestsMerged: number;
  pullRequestsClosed: number;
  issuesOpened: number;
  issuesOpen: number;
  issuesClosed: number;
  reviews: number;
  issueComments: number;
  prReviewComments: number;
  repositoriesTouched: number;
  restrictedContributions: number;
}

export interface RepositoryMetric {
  nameWithOwner: string;
  url: string;
  defaultBranch: string;
  defaultBranchCommits: number;
  pullRequests: number;
  issues: number;
  reviews: number;
}

export interface PullRequestMetric {
  title: string;
  url: string;
  state: PullRequestState;
  repository: string;
  createdAt: string;
  mergedAt: string | null;
  closedAt: string | null;
  comments: number;
  reviews: number;
  commits: number;
  additions: number;
  deletions: number;
  changedFiles: number;
}

export interface IssueMetric {
  title: string;
  url: string;
  state: "OPEN" | "CLOSED";
  repository: string;
  createdAt: string;
  closedAt: string | null;
  comments: number;
}

export interface CommentMetric {
  url: string;
  repository: string;
  createdAt: string;
  bodyText: string;
  type: "issue";
}

export interface GitHubMetrics {
  viewer: ViewerProfile;
  organization: string;
  from: string;
  to: string;
  summary: MetricSummary;
  repositories: RepositoryMetric[];
  pullRequests: PullRequestMetric[];
  issues: IssueMetric[];
  comments: CommentMetric[];
}

interface GraphQLResponse<T> {
  data?: T;
  errors?: Array<{ message: string }>;
}

interface SearchResponse<TNode> {
  nodes: TNode[];
  pageInfo: {
    hasNextPage: boolean;
    endCursor: string | null;
  };
}

interface RepositoryContribution {
  repository: {
    nameWithOwner: string;
    url: string;
    defaultBranchRef: { name: string } | null;
  };
  contributions: {
    totalCount: number;
    nodes: Array<{ commitCount?: number }>;
  };
}

interface ContributionsQueryData {
  viewer: ViewerProfile & {
    contributionsCollection: {
      totalCommitContributions: number;
      totalPullRequestContributions: number;
      totalIssueContributions: number;
      totalPullRequestReviewContributions: number;
      restrictedContributionsCount: number;
      totalRepositoriesWithContributedCommits: number;
      totalRepositoriesWithContributedPullRequests: number;
      totalRepositoriesWithContributedIssues: number;
      commitContributionsByRepository: RepositoryContribution[];
      pullRequestContributionsByRepository: RepositoryContribution[];
      issueContributionsByRepository: RepositoryContribution[];
      pullRequestReviewContributionsByRepository: RepositoryContribution[];
    };
  };
}

interface PullRequestNode {
  title: string;
  url: string;
  state: PullRequestState;
  createdAt: string;
  mergedAt: string | null;
  closedAt: string | null;
  comments: { totalCount: number };
  reviews: { totalCount: number };
  commits: { totalCount: number };
  additions: number;
  deletions: number;
  changedFiles: number;
  repository: { nameWithOwner: string };
}

interface IssueNode {
  title: string;
  url: string;
  state: "OPEN" | "CLOSED";
  createdAt: string;
  closedAt: string | null;
  comments: { totalCount: number };
  repository: { nameWithOwner: string };
}

interface IssueCommentNode {
  url: string;
  createdAt: string;
  bodyText: string;
  author: { login: string } | null;
}

interface IssueCommentSearchNode {
  repository: { nameWithOwner: string };
  comments: { nodes: IssueCommentNode[] };
}

interface SearchQueryData {
  viewer: Pick<ViewerProfile, "login">;
  pullRequests: SearchResponse<PullRequestNode>;
  issues: SearchResponse<IssueNode>;
  issueComments: SearchResponse<IssueCommentSearchNode>;
}

const contributionsQuery = `
  query Contributions($from: DateTime!, $to: DateTime!) {
    viewer {
      login
      name
      avatarUrl
      url
      contributionsCollection(from: $from, to: $to) {
        totalCommitContributions
        totalPullRequestContributions
        totalIssueContributions
        totalPullRequestReviewContributions
        restrictedContributionsCount
        totalRepositoriesWithContributedCommits
        totalRepositoriesWithContributedPullRequests
        totalRepositoriesWithContributedIssues
        commitContributionsByRepository(maxRepositories: 50) {
          repository {
            nameWithOwner
            url
            defaultBranchRef {
              name
            }
          }
          contributions(first: 100) {
            totalCount
            nodes {
              commitCount
            }
          }
        }
        pullRequestContributionsByRepository(maxRepositories: 50) {
          repository {
            nameWithOwner
            url
            defaultBranchRef {
              name
            }
          }
          contributions(first: 100) {
            totalCount
          }
        }
        issueContributionsByRepository(maxRepositories: 50) {
          repository {
            nameWithOwner
            url
            defaultBranchRef {
              name
            }
          }
          contributions(first: 100) {
            totalCount
          }
        }
        pullRequestReviewContributionsByRepository(maxRepositories: 50) {
          repository {
            nameWithOwner
            url
            defaultBranchRef {
              name
            }
          }
          contributions(first: 100) {
            totalCount
          }
        }
      }
    }
  }
`;

const targetOrganization = "openclaw";

const activitySearchQuery = `
  query ActivitySearch(
    $pullRequestQuery: String!,
    $issueQuery: String!,
    $issueCommentQuery: String!
  ) {
    viewer {
      login
    }
    pullRequests: search(type: ISSUE, query: $pullRequestQuery, first: 100) {
      nodes {
        ... on PullRequest {
          title
          url
          state
          createdAt
          mergedAt
          closedAt
          comments {
            totalCount
          }
          reviews {
            totalCount
          }
          commits {
            totalCount
          }
          additions
          deletions
          changedFiles
          repository {
            nameWithOwner
          }
        }
      }
      pageInfo {
        hasNextPage
        endCursor
      }
    }
    issues: search(type: ISSUE, query: $issueQuery, first: 100) {
      nodes {
        ... on Issue {
          title
          url
          state
          createdAt
          closedAt
          comments {
            totalCount
          }
          repository {
            nameWithOwner
          }
        }
      }
      pageInfo {
        hasNextPage
        endCursor
      }
    }
    issueComments: search(type: ISSUE, query: $issueCommentQuery, first: 100) {
      nodes {
        ... on Issue {
          comments(first: 20) {
            nodes {
              url
              createdAt
              bodyText
              author {
                login
              }
            }
          }
        }
      }
      pageInfo {
        hasNextPage
        endCursor
      }
    }
  }
`;

async function graphql<T>(token: string, query: string, variables: Record<string, unknown>): Promise<T> {
  const response = await fetch("https://api.github.com/graphql", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json"
    },
    body: JSON.stringify({ query, variables })
  });

  if (!response.ok) {
    throw new Error(`GitHub GraphQL returned HTTP ${response.status}.`);
  }

  const payload = (await response.json()) as GraphQLResponse<T>;
  if (payload.errors?.length) {
    throw new Error(payload.errors.map((error) => error.message).join("; "));
  }
  if (!payload.data) {
    throw new Error("GitHub returned an empty response.");
  }

  return payload.data;
}

function sumCommits(contribution: RepositoryContribution): number {
  const nodeSum = contribution.contributions.nodes.reduce(
    (total, node) => total + (node.commitCount ?? 0),
    0
  );
  return nodeSum || contribution.contributions.totalCount;
}

function upsertRepository(
  map: Map<string, RepositoryMetric>,
  contribution: RepositoryContribution
): RepositoryMetric {
  const existing = map.get(contribution.repository.nameWithOwner);
  if (existing) {
    return existing;
  }

  const metric: RepositoryMetric = {
    nameWithOwner: contribution.repository.nameWithOwner,
    url: contribution.repository.url,
    defaultBranch: contribution.repository.defaultBranchRef?.name ?? "default",
    defaultBranchCommits: 0,
    pullRequests: 0,
    issues: 0,
    reviews: 0
  };
  map.set(metric.nameWithOwner, metric);
  return metric;
}

function uniqueComments(comments: CommentMetric[]): CommentMetric[] {
  const seen = new Set<string>();
  return comments.filter((comment) => {
    if (seen.has(comment.url)) {
      return false;
    }
    seen.add(comment.url);
    return true;
  });
}

function inRange(date: string, from: Date, to: Date): boolean {
  const parsed = new Date(date);
  return parsed >= from && parsed <= to;
}

export async function fetchGitHubMetrics(token: string, days: number): Promise<GitHubMetrics> {
  const toDate = new Date();
  const fromDate = new Date(toDate);
  fromDate.setUTCDate(toDate.getUTCDate() - days);

  const from = fromDate.toISOString();
  const to = toDate.toISOString();

  const contributionData = await graphql<ContributionsQueryData>(token, contributionsQuery, {
    from,
    to
  });

  const login = contributionData.viewer.login;
  const dateQualifier = `created:${fromDate.toISOString().slice(0, 10)}..${toDate
    .toISOString()
    .slice(0, 10)}`;
  const searchData = await graphql<SearchQueryData>(token, activitySearchQuery, {
    pullRequestQuery: `is:pr org:${targetOrganization} author:${login} ${dateQualifier}`,
    issueQuery: `is:issue org:${targetOrganization} author:${login} ${dateQualifier}`,
    issueCommentQuery: `org:${targetOrganization} commenter:${login} ${dateQualifier}`
  });

  const collection = contributionData.viewer.contributionsCollection;
  const repositories = new Map<string, RepositoryMetric>();
  const isTargetRepository = (contribution: RepositoryContribution) =>
    contribution.repository.nameWithOwner.toLowerCase().startsWith(`${targetOrganization}/`);

  for (const contribution of collection.commitContributionsByRepository.filter(isTargetRepository)) {
    const metric = upsertRepository(repositories, contribution);
    metric.defaultBranchCommits += sumCommits(contribution);
  }

  for (const contribution of collection.pullRequestContributionsByRepository.filter(isTargetRepository)) {
    const metric = upsertRepository(repositories, contribution);
    metric.pullRequests += contribution.contributions.totalCount;
  }

  for (const contribution of collection.issueContributionsByRepository.filter(isTargetRepository)) {
    const metric = upsertRepository(repositories, contribution);
    metric.issues += contribution.contributions.totalCount;
  }

  for (const contribution of collection.pullRequestReviewContributionsByRepository.filter(isTargetRepository)) {
    const metric = upsertRepository(repositories, contribution);
    metric.reviews += contribution.contributions.totalCount;
  }

  const pullRequests = searchData.pullRequests.nodes.filter(Boolean).map((node) => ({
    title: node.title,
    url: node.url,
    state: node.state,
    repository: node.repository.nameWithOwner,
    createdAt: node.createdAt,
    mergedAt: node.mergedAt,
    closedAt: node.closedAt,
    comments: node.comments.totalCount,
    reviews: node.reviews.totalCount,
    commits: node.commits.totalCount,
    additions: node.additions,
    deletions: node.deletions,
    changedFiles: node.changedFiles
  }));

  const issues = searchData.issues.nodes.filter(Boolean).map((node) => ({
    title: node.title,
    url: node.url,
    state: node.state,
    repository: node.repository.nameWithOwner,
    createdAt: node.createdAt,
    closedAt: node.closedAt,
    comments: node.comments.totalCount
  }));

  const issueComments = searchData.issueComments.nodes
    .flatMap((issue) => {
      if (!issue.comments?.nodes || !issue.repository?.nameWithOwner) {
        return [];
      }
      return issue.comments.nodes.map((comment) => ({
        ...comment,
        repository: issue.repository.nameWithOwner
      }));
    })
    .filter((comment) => comment.author?.login === login)
    .filter((comment) => inRange(comment.createdAt, fromDate, toDate))
    .map<CommentMetric>((comment) => ({
      url: comment.url,
      repository: comment.repository,
      createdAt: comment.createdAt,
      bodyText: comment.bodyText,
      type: "issue"
    }));

  const comments = uniqueComments(issueComments).sort((a, b) =>
    b.createdAt.localeCompare(a.createdAt)
  );

  const totalIssueComments = comments.filter((comment) => comment.type === "issue").length;
  const defaultBranchCommits = Array.from(repositories.values()).reduce(
    (total, repository) => total + repository.defaultBranchCommits,
    0
  );
  const prBranchCommits = pullRequests.reduce((total, pr) => total + pr.commits, 0);

  return {
    viewer: {
      login: contributionData.viewer.login,
      name: contributionData.viewer.name,
      avatarUrl: contributionData.viewer.avatarUrl,
      url: contributionData.viewer.url
    },
    organization: targetOrganization,
    from,
    to,
    summary: {
      totalCommits: defaultBranchCommits + prBranchCommits,
      defaultBranchCommits,
      nonDefaultBranchCommits: prBranchCommits,
      pullRequests: pullRequests.length || collection.totalPullRequestContributions,
      pullRequestsOpen: pullRequests.filter((pr) => pr.state === "OPEN").length,
      pullRequestsMerged: pullRequests.filter((pr) => pr.state === "MERGED").length,
      pullRequestsClosed: pullRequests.filter((pr) => pr.state === "CLOSED").length,
      issuesOpened: issues.length || collection.totalIssueContributions,
      issuesOpen: issues.filter((issue) => issue.state === "OPEN").length,
      issuesClosed: issues.filter((issue) => issue.state === "CLOSED").length,
      reviews: collection.totalPullRequestReviewContributions,
      issueComments: totalIssueComments,
      prReviewComments: 0,
      repositoriesTouched: new Set([
        ...Array.from(repositories.keys()),
        ...pullRequests.map((pr) => pr.repository),
        ...issues.map((issue) => issue.repository),
        ...comments.map((comment) => comment.repository)
      ]).size,
      restrictedContributions: collection.restrictedContributionsCount
    },
    repositories: Array.from(repositories.values()).sort(
      (a, b) =>
        b.defaultBranchCommits +
        b.pullRequests +
        b.issues +
        b.reviews -
        (a.defaultBranchCommits + a.pullRequests + a.issues + a.reviews)
    ),
    pullRequests,
    issues,
    comments
  };
}
