# 0004: CI credentials via GitHub OIDC

- Status: accepted
- Date: 2026-10-07

## Decision

No AWS access keys are stored in GitHub. Workflows assume IAM roles through GitHub's OIDC provider:

| Role | Trust condition (`sub` claim) | Permissions |
|---|---|---|
| `gha-plan` | any ref of this repository | `ReadOnlyAccess` + state bucket |
| `gha-apply` | `environment:production` only | `AdministratorAccess` |
| `gha-ecr-push` | `ref:refs/heads/main` only | push to `eks-showcase/*` ECR repos |

The `production` environment requires a human reviewer, so an apply always has an approver on record.

## Known gap

`gha-apply` is broader than necessary. In a client setting it gets a permission boundary that
denies IAM changes outside a path prefix and blocks `organizations:*`, `account:*` and
billing actions. It is left broad here to keep the bootstrap readable. checkov's finding is
suppressed in `.checkov.yaml` with a pointer to this ADR.
