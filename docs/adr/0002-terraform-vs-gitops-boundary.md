# 0002: Terraform stops at the cluster; Argo CD owns the inside

- Status: accepted
- Date: 2026-10-07

## Context

A first version installed Argo CD with Terraform's Helm provider. That requires network access
to the Kubernetes API from wherever Terraform runs. The API endpoint is restricted to an
allow-list of operator IPs, and GitHub-hosted runners have no stable IPs. `terraform plan` in CI
would fail to refresh the Helm releases, or the endpoint would have to be opened to the internet.

## Decision

- Terraform manages **AWS resources only**: VPC, EKS, IAM, ECR.
- `scripts/bootstrap-argocd.sh <env>` installs Argo CD and one root Application. It is
  idempotent and identical for kind and EKS.
- Argo CD manages **everything else in the cluster**, from git.

## Consequences

- CI only needs AWS API access, never Kubernetes API access. The API endpoint stays locked down.
- There is one manual step after `terraform apply`, wrapped in `make apply`.
- Platform components (Prometheus, Kyverno) are upgraded by a PR that changes a chart version.
  Renovate opens those PRs.
- An alternative would be a self-hosted runner inside the VPC. It is worth it for a team, but
  it is overhead for a showcase.
