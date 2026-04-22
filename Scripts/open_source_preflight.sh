#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "==> Cusp open-source preflight"

required_files=(
  "README.md"
  "LICENSE"
  "SECURITY.md"
  "CONTRIBUTING.md"
  "THIRD_PARTY_LICENSES.md"
  ".gitignore"
)

echo "==> Checking required governance files"
for file in "${required_files[@]}"; do
  if [[ ! -f "$file" ]]; then
    echo "missing: $file" >&2
    exit 1
  fi
done

echo "==> Scanning for potential secrets"
secret_hits="$(rg -n --hidden --glob '!.git/*' --glob '!vendor/**' --glob '!.build/**' --glob '!.DerivedData/**' \
  -e 'token=[A-Za-z0-9]+' \
  -e 'https?://[^[:space:]]+token=[A-Za-z0-9]+' \
  -e 'sk-[A-Za-z0-9]{20,}' \
  -e 'BEGIN [A-Z ]*PRIVATE KEY' || true)"

if [[ -n "$secret_hits" ]]; then
  echo "potential secret-like content found:" >&2
  echo "$secret_hits" >&2
  echo "Please review and redact false positives before publishing." >&2
  exit 1
fi

echo "==> Checking ignored build artifacts in git status"
status_output="$(git status --short || true)"
if echo "$status_output" | rg -q '(\.build/|\.DerivedData/|vendor/bundle/|\.DS_Store)'; then
  echo "build artifacts detected in working tree status:" >&2
  echo "$status_output" >&2
  exit 1
fi

echo "==> Checking runtime binary distribution policy"
if [[ -f "Resources/mihomo/mihomo" ]]; then
  echo "note: local runtime binary exists at Resources/mihomo/mihomo"
  if git ls-files --error-unmatch Resources/mihomo/mihomo >/dev/null 2>&1; then
    echo "      it is tracked by git (expected for this repository)."
  else
    echo "      it is not tracked by git."
  fi
fi

echo "==> Preflight passed"
