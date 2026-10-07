#!/usr/bin/env bash
# For forks: rewrites the repository URL in the Argo CD manifests and docs
# from the upstream (mazhdrak/EKS-Platform-Showcase) to the 'origin' remote.
set -euo pipefail

UPSTREAM="mazhdrak/EKS-Platform-Showcase"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
url="$(git -C "$ROOT" remote get-url origin)"
# git@github.com:owner/repo.git | https://github.com/owner/repo(.git)
slug="$(sed -E 's#^(git@github\.com:|https://github\.com/)##; s#\.git$##' <<<"$url")"

[[ "$slug" =~ ^[^/]+/[^/]+$ ]] || { echo "could not parse owner/repo from: $url" >&2; exit 1; }
[[ "$slug" != "$UPSTREAM" ]] || { echo "origin is the upstream repo; nothing to do."; exit 0; }

grep -rl "$UPSTREAM" "$ROOT/gitops" "$ROOT/docs" "$ROOT/infra" "$ROOT/README.md" 2>/dev/null \
  | xargs -r sed -i.bak "s#${UPSTREAM}#${slug}#g"
find "$ROOT" -name '*.bak' -delete

echo "Repository set to '${slug}'. Review with 'git diff', then commit and push."
echo "Also update the github_owner / github_repo defaults in infra/terraform/bootstrap/variables.tf."
