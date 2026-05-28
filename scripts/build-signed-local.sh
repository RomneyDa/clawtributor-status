#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT_DIR/.env.signing.local"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing $ENV_FILE"
  echo "Copy .env.signing.local.example to .env.signing.local and fill in your signing values."
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

missing=()
for var in DEVELOPER_ID_APPLICATION APPLE_ID APPLE_APP_SPECIFIC_PASSWORD APPLE_TEAM_ID MAC_CSC_LINK MAC_CSC_KEY_PASSWORD; do
  if [[ -z "${!var:-}" ]]; then
    missing+=("$var")
  fi
done

if (( ${#missing[@]} > 0 )); then
  echo "The following required variables are not set in $ENV_FILE:"
  printf '  - %s\n' "${missing[@]}"
  exit 1
fi

# electron-builder reads CSC_LINK / CSC_KEY_PASSWORD; the local env file uses
# the MAC_-prefixed names that mirror the GitHub Actions release secrets.
export CSC_LINK="$MAC_CSC_LINK"
export CSC_KEY_PASSWORD="$MAC_CSC_KEY_PASSWORD"

cd "$ROOT_DIR"
pnpm build:mac:native
pnpm build:mac
