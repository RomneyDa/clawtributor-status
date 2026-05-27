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
source "$ENV_FILE"
set +a

cd "$ROOT_DIR"
pnpm build:mac:native
pnpm build:mac
