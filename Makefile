SHELL := /usr/bin/env bash
.SHELLFLAGS := -euo pipefail -c
.DEFAULT_GOAL := help

KIND_CLUSTER   ?= eks-showcase
TF_DEV         := infra/terraform/environments/dev
TF_BOOTSTRAP   := infra/terraform/bootstrap
APP_DIR        := apps/demo-service

##@ General
help: ## Show this help
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*##/ {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2} /^##@/ {printf "\n\033[1m%s\033[0m\n", substr($$0, 5)}' $(MAKEFILE_LIST)

set-repo: ## Forks only: point Argo CD manifests at your fork
	@scripts/set-repo.sh

##@ Quality
test: ## Run Go tests
	cd $(APP_DIR) && go vet ./... && go test -race -cover ./...

fmt: ## Format Go and Terraform
	cd $(APP_DIR) && gofmt -w .
	terraform fmt -recursive infra/terraform

lint: ## Lint YAML, Terraform and manifests (needs yamllint, tflint, kubeconform)
	yamllint gitops $(APP_DIR)/deploy
	terraform fmt -check -recursive infra/terraform
	for d in $(APP_DIR)/deploy/overlays/* gitops/platform/*; do kubectl kustomize $$d | kubeconform -strict -summary -ignore-missing-schemas; done

##@ Local (kind, free)
local-up: ## Create kind cluster, load image, bootstrap Argo CD
	kind get clusters | grep -qx $(KIND_CLUSTER) || kind create cluster --config kind/cluster.yaml
	docker build -t demo-service:local --build-arg VERSION=local $(APP_DIR)
	kind load docker-image demo-service:local --name $(KIND_CLUSTER)
	scripts/bootstrap-argocd.sh local

local-image: ## Rebuild and reload the demo image, restart pods
	docker build -t demo-service:local --build-arg VERSION=local-$$(git rev-parse --short HEAD) $(APP_DIR)
	kind load docker-image demo-service:local --name $(KIND_CLUSTER)
	kubectl -n demo rollout restart deploy/demo-service

local-down: ## Delete the kind cluster
	kind delete cluster --name $(KIND_CLUSTER)

##@ AWS (costs money: see README "Cost")
bootstrap: ## One-time: state bucket + GitHub OIDC roles (local state)
	cd $(TF_BOOTSTRAP) && terraform init && terraform apply

plan: ## terraform plan for dev
	cd $(TF_DEV) && terraform init -backend-config=backend.hcl -input=false && terraform plan

apply: ## Create VPC + EKS + ECR, then bootstrap Argo CD
	cd $(TF_DEV) && terraform init -backend-config=backend.hcl -input=false && terraform apply
	eval "$$(cd $(TF_DEV) && terraform output -raw kubeconfig_command)"
	scripts/bootstrap-argocd.sh dev

destroy: ## Tear everything down (Argo apps first so AWS LBs/volumes are released)
	-kubectl -n argocd delete application root --wait=true --timeout=10m
	cd $(TF_DEV) && terraform destroy

##@ Operate
argocd: ## Argo CD UI on http://localhost:8081 (prints admin password)
	@echo "admin password: $$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)"
	kubectl -n argocd port-forward svc/argocd-server 8081:80

grafana: ## Grafana on http://localhost:3000 (prints admin password)
	@echo "admin password: $$(kubectl -n monitoring get secret kube-prometheus-stack-grafana -o jsonpath='{.data.admin-password}' | base64 -d)"
	kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80

prometheus: ## Prometheus on http://localhost:9090
	kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 9090:9090

load: ## Start synthetic traffic against demo-service
	kubectl apply -f $(APP_DIR)/deploy/loadgen/loadgen.yaml

load-stop: ## Stop synthetic traffic
	kubectl delete -f $(APP_DIR)/deploy/loadgen/loadgen.yaml --ignore-not-found

.PHONY: help set-repo test fmt lint local-up local-image local-down bootstrap plan apply destroy argocd grafana prometheus load load-stop
