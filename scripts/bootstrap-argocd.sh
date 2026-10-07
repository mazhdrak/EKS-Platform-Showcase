#!/usr/bin/env bash
# Installs Argo CD and the root app-of-apps into the current kube-context.
# Same code path for the local kind cluster and EKS; idempotent.
#
#   scripts/bootstrap-argocd.sh local|dev
set -euo pipefail

ENVIRONMENT="${1:?usage: $0 local|dev}"
# renovate: datasource=helm depName=argo-cd registryUrl=https://argoproj.github.io/argo-helm
ARGOCD_CHART_VERSION="8.0.0"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ROOT_APP="$ROOT/gitops/bootstrap/root-${ENVIRONMENT}.yaml"

[[ -f "$ROOT_APP" ]] || { echo "unknown environment: $ENVIRONMENT" >&2; exit 1; }

if grep -rq "YOUR_GITHUB_USER" "$ROOT/gitops"; then
  echo "Repository URL placeholders are still present." >&2
  echo "Run 'make set-repo' once, commit and push, then retry." >&2
  exit 1
fi

for bin in kubectl helm; do
  command -v "$bin" >/dev/null || { echo "missing dependency: $bin" >&2; exit 1; }
done

echo ">> context: $(kubectl config current-context)"

helm repo add argo https://argoproj.github.io/argo-helm --force-update >/dev/null
helm upgrade --install argocd argo/argo-cd \
  --namespace argocd --create-namespace \
  --version "$ARGOCD_CHART_VERSION" \
  --values "$ROOT/gitops/bootstrap/argocd-values.yaml" \
  --wait --timeout 10m

kubectl apply -f "$ROOT_APP"

echo
echo ">> Argo CD is syncing gitops/clusters/${ENVIRONMENT}. Follow along with:"
echo "   kubectl -n argocd get applications -w"
echo "   make argocd    # UI on http://localhost:8081"
