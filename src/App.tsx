import { useEffect, useMemo, useState } from "react";
import {
  CheckCircle2,
  CircleDot,
  GitCommitHorizontal,
  GitPullRequest,
  Github,
  LogOut,
  MessageSquare,
  RefreshCw,
  Search,
  ShieldAlert,
  Timer,
  XCircle
} from "lucide-react";
import {
  clearStoredToken,
  getStoredToken,
  pollForAccessToken,
  requestDeviceCode,
  storeToken,
  type DeviceCodeResponse
} from "./services/githubAuth";
import { fetchGitHubMetrics, type GitHubMetrics } from "./services/githubMetrics";

type LoadState = "idle" | "loading" | "ready" | "error";

const defaultGitHubClientId = "Ov23liweZPNo3mh79yx7";

const ranges = [
  { label: "30d", days: 30 },
  { label: "90d", days: 90 },
  { label: "1y", days: 365 }
];

function formatNumber(value: number) {
  return new Intl.NumberFormat().format(value);
}

function formatDate(value: string) {
  return new Intl.DateTimeFormat(undefined, {
    month: "short",
    day: "numeric",
    year: "numeric"
  }).format(new Date(value));
}

function useGitHubClientId(): [string, (clientId: string) => void] {
  const [clientId, setClientIdState] = useState(
    () => window.localStorage.getItem("github_client_id") ?? defaultGitHubClientId
  );

  useEffect(() => {
    const load = async () => {
      const bridged = await window.desktop?.getGitHubClientId();
      if (!clientId) {
        setClientIdState(bridged || import.meta.env.VITE_GITHUB_CLIENT_ID || defaultGitHubClientId);
      }
    };
    void load();
  }, [clientId]);

  const setClientId = (nextClientId: string) => {
    const trimmed = nextClientId.trim();
    setClientIdState(trimmed);
    if (trimmed) {
      window.localStorage.setItem("github_client_id", trimmed);
    } else {
      window.localStorage.removeItem("github_client_id");
    }
  };

  return [clientId, setClientId];
}

function openExternal(event: React.MouseEvent<HTMLAnchorElement>, url: string) {
  event.preventDefault();
  void window.desktop?.openExternal(url);
}

export function App() {
  const [clientId, setClientId] = useGitHubClientId();
  const [clientIdDraft, setClientIdDraft] = useState(clientId);
  const [token, setToken] = useState<string | null>(() => getStoredToken());
  const [metrics, setMetrics] = useState<GitHubMetrics | null>(null);
  const [days, setDays] = useState(90);
  const [state, setState] = useState<LoadState>("idle");
  const [error, setError] = useState("");
  const [deviceCode, setDeviceCode] = useState<DeviceCodeResponse | null>(null);
  const [query, setQuery] = useState("");

  const loadMetrics = async (accessToken = token, selectedDays = days) => {
    if (!accessToken) {
      return;
    }
    setState("loading");
    setError("");
    try {
      const data = await fetchGitHubMetrics(accessToken, selectedDays);
      setMetrics(data);
      setState("ready");
    } catch (currentError) {
      setError(currentError instanceof Error ? currentError.message : "Unable to load GitHub metrics.");
      setState("error");
    }
  };

  useEffect(() => {
    if (token) {
      void loadMetrics(token, days);
    }
  }, [token, days]);

  const beginLogin = async () => {
    if (!clientId) {
      const draftedClientId = clientIdDraft.trim();
      if (draftedClientId) {
        setClientId(draftedClientId);
      } else {
        setError("Enter a GitHub OAuth client ID before starting GitHub login.");
        setState("error");
        return;
      }
    }

    const effectiveClientId = clientId || clientIdDraft.trim();
    if (!effectiveClientId) {
      setError("Enter a GitHub OAuth client ID before starting GitHub login.");
      setState("error");
      return;
    }

    setState("loading");
    setError("");
    try {
      const code = await requestDeviceCode(effectiveClientId);
      setDeviceCode(code);
      await window.desktop?.openExternal(code.verification_uri);

      let delaySeconds = code.interval;
      const expiresAt = Date.now() + code.expires_in * 1000;
      while (Date.now() < expiresAt) {
        await new Promise((resolve) => window.setTimeout(resolve, delaySeconds * 1000));
        const response = await pollForAccessToken(effectiveClientId, code.device_code);
        if (response.access_token) {
          storeToken(response.access_token);
          setToken(response.access_token);
          setDeviceCode(null);
          return;
        }
        if (response.error === "authorization_pending") {
          continue;
        }
        if (response.error === "slow_down") {
          delaySeconds += 5;
          continue;
        }
        throw new Error(response.error_description ?? response.error ?? "GitHub login failed.");
      }
      throw new Error("GitHub login expired. Start login again.");
    } catch (currentError) {
      setError(currentError instanceof Error ? currentError.message : "GitHub login failed.");
      setState("error");
    }
  };

  const filteredRepositories = useMemo(() => {
    const normalized = query.trim().toLowerCase();
    if (!metrics || !normalized) {
      return metrics?.repositories ?? [];
    }
    return metrics.repositories.filter((repo) => repo.nameWithOwner.toLowerCase().includes(normalized));
  }, [metrics, query]);

  const signOut = () => {
    clearStoredToken();
    setToken(null);
    setMetrics(null);
    setDeviceCode(null);
    setState("idle");
    setError("");
  };

  if (!token) {
    return (
      <main className="login-screen">
        <section className="login-panel">
          <div className="brand-mark">
            <Github size={34} />
          </div>
          <h1>Clawtributor Status</h1>
          <p>
            Sign in with GitHub to analyze contribution activity across commits, pull requests, issues,
            reviews, and comments.
          </p>
          {!clientId ? (
            <label className="client-id-field">
              <span>OAuth client ID</span>
              <input
                value={clientIdDraft}
                onChange={(event) => setClientIdDraft(event.target.value)}
                placeholder="GitHub OAuth app client ID"
              />
            </label>
          ) : null}
          <button className="primary-button" type="button" onClick={beginLogin} disabled={state === "loading"}>
            <Github size={18} />
            {state === "loading" ? "Waiting for GitHub" : "Sign in with GitHub"}
          </button>
          {deviceCode ? (
            <div className="device-code">
              <span>Enter code</span>
              <strong>{deviceCode.user_code}</strong>
              <small>{deviceCode.verification_uri}</small>
            </div>
          ) : null}
          {error ? <p className="error-text">{error}</p> : null}
        </section>
      </main>
    );
  }

  return (
    <main className="app-shell">
      <aside className="sidebar">
        <div className="sidebar-header">
          <div className="brand-mark compact">
            <Github size={24} />
          </div>
          <div>
            <strong>Clawtributor</strong>
            <span>Status</span>
          </div>
        </div>
        <div className="range-control" aria-label="Metric range">
          {ranges.map((range) => (
            <button
              key={range.days}
              className={range.days === days ? "selected" : ""}
              type="button"
              onClick={() => setDays(range.days)}
            >
              {range.label}
            </button>
          ))}
        </div>
        <button className="secondary-button" type="button" onClick={() => void loadMetrics()}>
          <RefreshCw size={16} />
          Refresh
        </button>
        <button className="ghost-button" type="button" onClick={signOut}>
          <LogOut size={16} />
          Sign out
        </button>
      </aside>

      <section className="content">
        {state === "loading" && !metrics ? (
          <div className="loading-state">
            <Timer size={28} />
            Loading GitHub metrics
          </div>
        ) : null}

        {error ? (
          <div className="alert">
            <ShieldAlert size={18} />
            {error}
          </div>
        ) : null}

        {metrics ? (
          <>
            <header className="profile-header">
              <img src={metrics.viewer.avatarUrl} alt="" />
              <div>
                <h1>{metrics.viewer.name ?? metrics.viewer.login}</h1>
                <p>
                  @{metrics.viewer.login} in {metrics.organization} from {formatDate(metrics.from)} to{" "}
                  {formatDate(metrics.to)}
                </p>
              </div>
            </header>

            <section className="summary-grid" aria-label="Contribution summary">
              <MetricCard
                icon={<GitCommitHorizontal size={20} />}
                label="Default branch commits"
                value={metrics.summary.defaultBranchCommits}
                detail="GitHub contribution commits on default branches"
              />
              <MetricCard
                icon={<GitPullRequest size={20} />}
                label="PR branch commits"
                value={metrics.summary.nonDefaultBranchCommits}
                detail="Commits attached to authored pull requests"
              />
              <MetricCard
                icon={<CircleDot size={20} />}
                label="Open PRs"
                value={metrics.summary.pullRequestsOpen}
                detail={`${formatNumber(metrics.summary.pullRequests)} authored PRs total`}
              />
              <MetricCard
                icon={<CheckCircle2 size={20} />}
                label="Merged PRs"
                value={metrics.summary.pullRequestsMerged}
                detail={`${formatNumber(metrics.summary.pullRequestsClosed)} closed without merge`}
              />
              <MetricCard
                icon={<XCircle size={20} />}
                label="Issues opened"
                value={metrics.summary.issuesOpened}
                detail={`${formatNumber(metrics.summary.issuesOpen)} open, ${formatNumber(
                  metrics.summary.issuesClosed
                )} closed`}
              />
              <MetricCard
                icon={<MessageSquare size={20} />}
                label="Comments and reviews"
                value={metrics.summary.issueComments + metrics.summary.prReviewComments + metrics.summary.reviews}
                detail={`${formatNumber(metrics.summary.reviews)} reviews, ${formatNumber(
                  metrics.summary.issueComments + metrics.summary.prReviewComments
                )} comments`}
              />
            </section>

            <section className="split-layout">
              <div className="panel">
                <div className="panel-header">
                  <h2>Repositories</h2>
                  <label className="search-box">
                    <Search size={16} />
                    <input
                      value={query}
                      onChange={(event) => setQuery(event.target.value)}
                      placeholder="Filter repositories"
                    />
                  </label>
                </div>
                <div className="repo-list">
                  {filteredRepositories.map((repo) => (
                    <a
                      key={repo.nameWithOwner}
                      className="repo-row"
                      href={repo.url}
                      onClick={(event) => openExternal(event, repo.url)}
                    >
                      <strong>{repo.nameWithOwner}</strong>
                      <span>{repo.defaultBranch}</span>
                      <b>{formatNumber(repo.defaultBranchCommits)}</b>
                      <small>commits</small>
                      <b>{formatNumber(repo.pullRequests)}</b>
                      <small>PRs</small>
                      <b>{formatNumber(repo.issues + repo.reviews)}</b>
                      <small>issues/reviews</small>
                    </a>
                  ))}
                </div>
              </div>

              <div className="panel">
                <div className="panel-header">
                  <h2>Pull Requests</h2>
                  <span>{formatNumber(metrics.pullRequests.length)}</span>
                </div>
                <div className="activity-list">
                  {metrics.pullRequests.slice(0, 12).map((pr) => (
                    <a
                      key={pr.url}
                      className="activity-row"
                      href={pr.url}
                      onClick={(event) => openExternal(event, pr.url)}
                    >
                      <span className={`state-pill ${pr.state.toLowerCase()}`}>{pr.state.toLowerCase()}</span>
                      <strong>{pr.title}</strong>
                      <small>
                        {pr.repository} · {formatNumber(pr.commits)} commits · {formatNumber(pr.reviews)} reviews
                      </small>
                    </a>
                  ))}
                </div>
              </div>
            </section>

            <section className="split-layout">
              <div className="panel">
                <div className="panel-header">
                  <h2>Issues</h2>
                  <span>{formatNumber(metrics.issues.length)}</span>
                </div>
                <div className="activity-list">
                  {metrics.issues.slice(0, 10).map((issue) => (
                    <a
                      key={issue.url}
                      className="activity-row"
                      href={issue.url}
                      onClick={(event) => openExternal(event, issue.url)}
                    >
                      <span className={`state-pill ${issue.state.toLowerCase()}`}>{issue.state.toLowerCase()}</span>
                      <strong>{issue.title}</strong>
                      <small>
                        {issue.repository} · {formatNumber(issue.comments)} comments
                      </small>
                    </a>
                  ))}
                </div>
              </div>

              <div className="panel">
                <div className="panel-header">
                  <h2>Recent Comments</h2>
                  <span>{formatNumber(metrics.comments.length)}</span>
                </div>
                <div className="activity-list">
                  {metrics.comments.slice(0, 10).map((comment) => (
                    <a
                      key={comment.url}
                      className="activity-row"
                      href={comment.url}
                      onClick={(event) => openExternal(event, comment.url)}
                    >
                      <span className="state-pill neutral">{comment.type === "issue" ? "issue" : "review"}</span>
                      <strong>{comment.bodyText || "Comment"}</strong>
                      <small>
                        {comment.repository} · {formatDate(comment.createdAt)}
                      </small>
                    </a>
                  ))}
                </div>
              </div>
            </section>
          </>
        ) : null}
      </section>
    </main>
  );
}

function MetricCard({
  icon,
  label,
  value,
  detail
}: {
  icon: React.ReactNode;
  label: string;
  value: number;
  detail: string;
}) {
  return (
    <article className="metric-card">
      <div>{icon}</div>
      <span>{label}</span>
      <strong>{formatNumber(value)}</strong>
      <small>{detail}</small>
    </article>
  );
}
