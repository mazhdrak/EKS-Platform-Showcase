terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Partial config: bucket/region come from backend.hcl
  #   terraform init -backend-config=backend.hcl
  backend "s3" {
    key          = "environments/dev/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.region
  default_tags {
    tags = local.tags
  }
}

locals {
  name = "${var.project}-${var.environment}"
  tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
    Repository  = var.gitops_repo_url
  }
}

module "network" {
  source = "../../modules/network"

  name               = local.name
  cidr               = var.vpc_cidr
  az_count           = 3
  single_nat_gateway = true # dev: cost over availability
  tags               = local.tags
}

module "eks" {
  source = "../../modules/eks-cluster"

  name               = local.name
  kubernetes_version = var.kubernetes_version
  vpc_id             = module.network.vpc_id
  private_subnet_ids = module.network.private_subnet_ids
  api_allowed_cidrs  = var.api_allowed_cidrs
  access_entries     = var.access_entries

  node_capacity_type = "SPOT"
  node_min_size      = 2
  node_desired_size  = 2
  node_max_size      = 4

  tags = local.tags
}

module "ecr" {
  source = "../../modules/ecr"

  prefix       = var.project
  repositories = ["demo-service"]
  force_delete = true # dev: allow `make destroy` to clean everything
  tags         = local.tags
}

# Argo CD is installed by scripts/bootstrap-argocd.sh, not by Terraform:
# see docs/adr/0002-terraform-vs-gitops-boundary.md.
