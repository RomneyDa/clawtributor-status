# Clawtributor Status

Clawtributor Status is a macOS and Windows desktop app for reviewing GitHub contribution activity from a GitHub login.

## What It Tracks

- Default-branch commit contributions from GitHub's contribution collection.
- Authored pull requests split by open, merged, and closed states.
- Pull request branch commit counts, changed files, additions, deletions, comments, and review comments.
- Authored issues split by open and closed states.
- Pull request reviews, issue comments, review comments, restricted contributions, and repositories touched.

## GitHub Login

The app uses GitHub OAuth device login. Create a GitHub OAuth App and provide its client ID:

```sh
cp .env.example .env
```

Set `GITHUB_CLIENT_ID` for packaged Electron and `VITE_GITHUB_CLIENT_ID` for local Vite development.
If the app is launched without those variables, it prompts for a client ID and stores it locally.

Required OAuth scopes are intentionally narrow:

- `read:user`

## Development

```sh
pnpm install
pnpm electron:dev
```

## Build macOS and Windows Installers

```sh
pnpm build
```

Use `pnpm build:mac` on macOS and `pnpm build:win` on Windows for explicit platform builds. Local macOS builds produce `.dmg` and `.zip` artifacts. Windows artifacts are produced by the Windows GitHub Actions runner.

## Releases

Tagged versions matching `v*` run `.github/workflows/release.yml` and upload macOS and Windows artifacts to a GitHub Release.

```sh
git tag v0.1.0
git push origin main --tags
```

## Platform Scope

The current app supports macOS and Windows. Linux packaging is intentionally out of scope for now.
