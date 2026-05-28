import { useEffect, useMemo, useRef, useState } from "react";
import { ChevronDown, Folder, Loader2, RefreshCw, Trash2 } from "lucide-react";
import {
  clearStoredToken,
  getStoredToken,
  pollForAccessToken,
  requestDeviceCode,
  storeToken,
  type DeviceCodeResponse
} from "./services/githubAuth";
import { fetchGitHubMetrics, type GitHubMetrics, type PullRequestMetric } from "./services/githubMetrics";

type LoadState = "idle" | "loading" | "ready" | "error";

const defaultGitHubClientId = "Ov23liweZPNo3mh79yx7";

const ranges = [
  { label: "24h", days: 1 },
  { label: "7d", days: 7 },
  { label: "30d", days: 30 },
  { label: "90d", days: 90 },
  { label: "1y", days: 365 }
];

const lobsterSrc = "openclaw/pixel-lobster.svg";

function formatNumber(value: number) {
  if (Math.abs(value) >= 10_000) {
    return new Intl.NumberFormat(undefined, { notation: "compact", maximumFractionDigits: 1 }).format(value);
  }
  return new Intl.NumberFormat().format(value);
}

function formatShortDate(value: Date | string) {
  const date = value instanceof Date ? value : new Date(value);
  return new Intl.DateTimeFormat(undefined, { month: "short", day: "numeric" }).format(date);
}

function buildVerificationURL(verificationUri: string, userCode: string) {
  try {
    const url = new URL(verificationUri);
    url.searchParams.set("user_code", userCode);
    return url.toString();
  } catch {
    return verificationUri;
  }
}

function openVerificationURL(verificationUri: string, userCode: string) {
  const full = buildVerificationURL(verificationUri, userCode);
  if (window.desktop?.openExternal) {
    void window.desktop.openExternal(full);
    return;
  }
  window.open(full, "_blank", "noopener,noreferrer");
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

interface FilteredStats {
  commits: number;
  prsMerged: number;
  prsOpen: number;
  prsTotal: number;
  additions: number;
  deletions: number;
  filesChanged: number;
  issues: number;
  reviews: number;
  comments: number;
  repos: number;
  restricted: number;
}

function computeStats(metrics: GitHubMetrics, selectedRepo: string | null): FilteredStats {
  if (selectedRepo) {
    const repoEntry = metrics.repositories.find((repo) => repo.nameWithOwner === selectedRepo);
    const prs = metrics.pullRequests.filter((pr) => pr.repository === selectedRepo);
    const issues = metrics.issues.filter((issue) => issue.repository === selectedRepo);
    const comments = metrics.comments.filter((comment) => comment.repository === selectedRepo);
    return {
      commits: repoEntry?.defaultBranchCommits ?? 0,
      prsMerged: prs.filter((pr) => pr.state === "MERGED").length,
      prsOpen: prs.filter((pr) => pr.state === "OPEN").length,
      prsTotal: prs.length,
      additions: prs.reduce((sum, pr) => sum + pr.additions, 0),
      deletions: prs.reduce((sum, pr) => sum + pr.deletions, 0),
      filesChanged: prs.reduce((sum, pr) => sum + pr.changedFiles, 0),
      issues: issues.length,
      reviews: repoEntry?.reviews ?? 0,
      comments: comments.length,
      repos: 1,
      restricted: 0
    };
  }
  const s = metrics.summary;
  const prs = metrics.pullRequests;
  return {
    commits: s.totalCommits,
    prsMerged: s.pullRequestsMerged,
    prsOpen: s.pullRequestsOpen,
    prsTotal: s.pullRequests,
    additions: prs.reduce((sum: number, pr: PullRequestMetric) => sum + pr.additions, 0),
    deletions: prs.reduce((sum: number, pr: PullRequestMetric) => sum + pr.deletions, 0),
    filesChanged: prs.reduce((sum: number, pr: PullRequestMetric) => sum + pr.changedFiles, 0),
    issues: s.issuesOpened,
    reviews: s.reviews,
    comments: s.issueComments + s.prReviewComments,
    repos: s.repositoriesTouched,
    restricted: s.restrictedContributions
  };
}

export function App() {
  const [clientId, setClientId] = useGitHubClientId();
  const [clientIdDraft, setClientIdDraft] = useState(clientId);
  const [token, setToken] = useState<string | null>(() => getStoredToken());
  const [metrics, setMetrics] = useState<GitHubMetrics | null>(null);
  const [days, setDays] = useState(1);
  const [selectedRepo, setSelectedRepo] = useState<string | null>(null);
  const [state, setState] = useState<LoadState>("idle");
  const [error, setError] = useState("");
  const [deviceCode, setDeviceCode] = useState<DeviceCodeResponse | null>(null);
  const [repoMenuOpen, setRepoMenuOpen] = useState(false);
  const [isFetching, setIsFetching] = useState(false);
  const metricsCache = useRef<Map<number, GitHubMetrics>>(new Map());
  const currentDaysRef = useRef(days);

  useEffect(() => {
    currentDaysRef.current = days;
  }, [days]);

  const loadMetrics = async (accessToken = token, selectedDays = days) => {
    if (!accessToken) return;
    setError("");
    const cached = metricsCache.current.get(selectedDays);
    if (cached) {
      setMetrics(cached);
      setState("ready");
    } else {
      setState("loading");
    }
    setIsFetching(true);
    try {
      const data = await fetchGitHubMetrics(accessToken, selectedDays);
      metricsCache.current.set(selectedDays, data);
      if (currentDaysRef.current === selectedDays) {
        setMetrics(data);
        setState("ready");
      }
    } catch (currentError) {
      if (!cached && currentDaysRef.current === selectedDays) {
        setError(currentError instanceof Error ? currentError.message : "Unable to load GitHub metrics.");
        setState("error");
      }
    } finally {
      setIsFetching(false);
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
      openVerificationURL(code.verification_uri, code.user_code);

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
        if (response.error === "authorization_pending") continue;
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

  const signOut = () => {
    clearStoredToken();
    setToken(null);
    setMetrics(null);
    setDeviceCode(null);
    setState("idle");
    setError("");
    setSelectedRepo(null);
    metricsCache.current.clear();
  };

  const stats = useMemo(() => (metrics ? computeStats(metrics, selectedRepo) : null), [metrics, selectedRepo]);

  const mergeRate = stats && stats.prsTotal > 0 ? Math.round((stats.prsMerged / stats.prsTotal) * 100) : 0;

  const avgPrSize = useMemo(() => {
    if (!metrics) return 0;
    const prs = selectedRepo
      ? metrics.pullRequests.filter((pr) => pr.repository === selectedRepo)
      : metrics.pullRequests;
    if (prs.length === 0) return 0;
    return Math.round(prs.reduce((sum, pr) => sum + pr.additions + pr.deletions, 0) / prs.length);
  }, [metrics, selectedRepo]);

  const topRepo = useMemo(() => {
    if (!metrics) return null;
    if (selectedRepo) return selectedRepo;
    const sorted = [...metrics.repositories].sort(
      (a, b) => b.defaultBranchCommits + b.pullRequests - (a.defaultBranchCommits + a.pullRequests)
    );
    return sorted[0]?.nameWithOwner ?? null;
  }, [metrics, selectedRepo]);

  const repoNames = useMemo(() => {
    if (!metrics) return [];
    return [...metrics.repositories.map((repo) => repo.nameWithOwner)].sort();
  }, [metrics]);

  if (!token) {
    return (
      <main className="widget login">
        <img className="lobster lg" src={lobsterSrc} alt="OpenClaw" />
        <h1>Clawtributor</h1>
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
          {state === "loading" ? "Waiting for GitHub" : "Sign in with GitHub"}
        </button>
        {deviceCode ? (
          <div className="device-code">
            <span>enter this code at</span>
            <a
              href={buildVerificationURL(deviceCode.verification_uri, deviceCode.user_code)}
              onClick={(event) => {
                event.preventDefault();
                openVerificationURL(deviceCode.verification_uri, deviceCode.user_code);
              }}
            >
              {deviceCode.verification_uri}
            </a>
            <strong>{deviceCode.user_code}</strong>
          </div>
        ) : null}
        {error ? <p className="error-text">{error}</p> : null}
      </main>
    );
  }

  return (
    <main className="widget">
      <header className="compact-header">
        {metrics ? (
          <>
            <img className="avatar" src={metrics.viewer.avatarUrl} alt="" />
            <span className="handle">@{metrics.viewer.login}</span>
          </>
        ) : (
          <>
            <img className="lobster sm" src={lobsterSrc} alt="OpenClaw" />
            <span className="handle">Clawtributor</span>
          </>
        )}
        <div className="spacer" />
        <div className="range-control" role="group" aria-label="Range">
          {ranges.map((range) => (
            <button
              key={range.days}
              type="button"
              className={range.days === days ? "selected" : ""}
              onClick={() => setDays(range.days)}
            >
              {range.label}
            </button>
          ))}
        </div>
        <button
          className="icon-button"
          type="button"
          onClick={() => void loadMetrics()}
          title="Refresh"
          disabled={state === "loading"}
        >
          <RefreshCw size={13} />
        </button>
        <button className="icon-button" type="button" onClick={signOut} title="Sign out">
          <Trash2 size={13} />
        </button>
      </header>

      {metrics && stats ? (
        <>
          <div className="repo-filter">
            <button
              type="button"
              className="repo-button"
              onClick={() => setRepoMenuOpen((open) => !open)}
            >
              <Folder size={11} />
              <span>{selectedRepo ?? "All repos"}</span>
              <ChevronDown size={10} />
            </button>
            {isFetching ? <Loader2 size={11} className="spin" aria-label="Refreshing" /> : null}
            {repoMenuOpen ? (
              <div className="repo-menu" onMouseLeave={() => setRepoMenuOpen(false)}>
                <button
                  type="button"
                  className={selectedRepo === null ? "selected" : ""}
                  onClick={() => {
                    setSelectedRepo(null);
                    setRepoMenuOpen(false);
                  }}
                >
                  All repos
                </button>
                {repoNames.map((name) => (
                  <button
                    key={name}
                    type="button"
                    className={name === selectedRepo ? "selected" : ""}
                    onClick={() => {
                      setSelectedRepo(name);
                      setRepoMenuOpen(false);
                    }}
                  >
                    {name}
                  </button>
                ))}
              </div>
            ) : null}
          </div>

          <section className="stat-grid">
            <StatCell value={stats.commits} label="commits" tint="lobster" />
            <StatCell value={stats.prsMerged} label="merged" tint="purple" />
            <StatCell value={stats.prsOpen} label="open PRs" tint="green" />
            <StatCell value={stats.additions} prefix="+" label="added" tint="green" />
            <StatCell value={stats.deletions} prefix="−" label="deleted" tint="red" />
            <StatCell value={stats.filesChanged} label="files" tint="orange" />
            <StatCell value={stats.issues} label="issues" tint="yellow" />
            <StatCell value={stats.reviews} label="reviews" tint="cyan" />
            <StatCell value={stats.comments} label="comments" tint="pink" />
          </section>

          <footer className="footer-line">
            <div className="footer-stats">
              <span>📁 {stats.repos} repos</span>
              <span>✓ {mergeRate}% merged</span>
              <span>↕ {avgPrSize} Δ/PR</span>
              {stats.restricted > 0 ? <span>🔒 {stats.restricted}</span> : null}
            </div>
            <div className="footer-meta">
              {topRepo ? <span>top: {topRepo} · </span> : null}
              <span>
                {formatShortDate(metrics.from)}–{formatShortDate(metrics.to)}
              </span>
            </div>
          </footer>
        </>
      ) : state === "loading" ? (
        <div className="loading-state">
          <img className="lobster md" src={lobsterSrc} alt="OpenClaw" />
          <span>Loading OpenClaw metrics</span>
        </div>
      ) : null}

      {error ? <div className="alert">{error}</div> : null}
    </main>
  );
}

function StatCell({
  value,
  label,
  prefix = "",
  tint
}: {
  value: number;
  label: string;
  prefix?: string;
  tint: string;
}) {
  return (
    <article className={`stat-cell tint-${tint}`}>
      <strong>
        {prefix}
        {formatNumber(value)}
      </strong>
      <span>{label}</span>
    </article>
  );
}
