# GitHub Contract

This package is the shared contract between the Electron app and the native macOS Swift app.

Shared files:

- `queries/contributions.graphql`
- `queries/activity-search.graphql`
- `schema/metrics-contract.json`
- `fixtures/sample-metrics.json`

Rules:

- Keep OAuth scopes at `read:user` unless a privacy review changes that explicitly.
- Keep OpenClaw metrics constrained to `org:openclaw` or `openclaw/*`.
- Do not add private repository scopes to the OAuth flow.
- Add fixtures when changing metric semantics.
