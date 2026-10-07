#!/usr/bin/env bash
# Replaces the YOUR_GITHUB_USER placeholder with the owner of the 'origin'
# remote, so Argo CD syncs from your fork.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
url="$(git -C "$ROOT" remote get-url origin)"
# git@github.com:owner/repo.git | https://github.com/owner/repo(.git)
owner="$(sed -E 's#(git@github\.com:|https://github\.com/)([^/]+)/.*#\2#' <<<"$url")"

[[ -n "$owner" && "$owner" != "$url" ]] || { echo "could not parse GitHub owner from: $url" >&2; exit 1; }

grep -rl "YOUR_GITHUB_USER" "$ROOT/gitops" "$ROOT/docs" "$ROOT/README.md" 2>/dev/null \
  | xargs -r sed -i.bak "s/YOUR_GITHUB_USER/${owner}/g"
find "$ROOT" -name '*.bak' -delete

echo "Repository owner set to '${owner}'. Review with 'git diff', then commit and push."
