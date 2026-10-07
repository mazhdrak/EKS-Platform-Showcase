# Getting started

## 0. Prerequisites

| Tool | Local mode | AWS mode |
|---|---|---|
| Docker, kind | ✓ | |
| kubectl, helm | ✓ | ✓ |
| Terraform ≥ 1.10 | | ✓ |
| AWS CLI v2, credentials for an account you can spend money in | | ✓ |

Fork the repository (it must be **public**, or you must add repo credentials to Argo CD), clone the fork, then:

```bash
make set-repo
git commit -am "chore: point gitops at my fork" && git push
```

## 1. Local mode (kind)

```bash
make local-up
kubectl -n argocd get applications -w
```

Sync order is controlled by `argocd.argoproj.io/sync-wave`:

| Wave | What |
|---|---|
| 0 | kube-prometheus-stack, Kyverno, metrics-server (CRDs + controllers) |
| 1 | Kyverno policies, SLO rules, Grafana dashboard |
| 2 | demo-service |

A first sync takes 3–6 minutes. If `platform-policies` or `platform-observability` show
`SyncFailed` early on, it is because their CRDs are not registered yet. The retry policy
resolves it without intervention.

Then:

```bash
make load       # traffic
make grafana    # http://localhost:3000, dashboard "demo-service / SLO"
make argocd     # http://localhost:8081
make local-down # when finished
```

## 2. AWS mode (EKS)

### 2.1 Bootstrap (once per AWS account)

```bash
cd infra/terraform/bootstrap
terraform init
terraform apply -var github_owner=<your-github-user>
```

This creates the S3 state bucket and three IAM roles that GitHub Actions can assume through OIDC.

### 2.2 Configure GitHub

In the repository's **Settings → Secrets and variables → Actions → Variables**:

| Variable | Value |
|---|---|
| `AWS_REGION` | `eu-central-1` |
| `TF_STATE_BUCKET` | output `state_bucket` |
| `AWS_PLAN_ROLE_ARN` | output `plan_role_arn` |
| `AWS_APPLY_ROLE_ARN` | output `apply_role_arn` |
| `AWS_ECR_PUSH_ROLE_ARN` | output `ecr_push_role_arn` |
| `API_ALLOWED_CIDRS` | HCL list, e.g. `["203.0.113.10/32"]` |

Create an environment named **production** under **Settings → Environments** and add yourself as a required reviewer.
Only jobs in that environment can assume the apply role.

### 2.3 Create the cluster

From your machine:

```bash
cd infra/terraform/environments/dev
cp backend.hcl.example backend.hcl            # fill in the bucket
cp terraform.tfvars.example terraform.tfvars  # your IP and repo URL
cd -
make apply      # terraform apply (about 15 min), then Argo CD bootstrap
```

Or run the **terraform-apply** workflow from the Actions tab, then run
`scripts/bootstrap-argocd.sh dev` locally once.

### 2.4 Ship the first image

The dev overlay starts with a placeholder image, so demo-service sits in `ImagePullBackOff`
until the first release. Trigger it by changing anything under `apps/demo-service/` (outside
`deploy/`) and merging to `main`. The **app-release** workflow builds and pushes to ECR, then
commits the new tag to `deploy/overlays/dev`. Argo CD rolls it out.

> If `main` is protected, allow `github-actions[bot]` to push, or change the workflow to open a PR instead.

### 2.5 Tear down

```bash
make destroy
```

The root Application is deleted first, so anything Kubernetes created in AWS (EBS volumes for
Prometheus) is released before Terraform removes the cluster.
