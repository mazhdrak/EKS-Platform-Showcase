variable "project" {
  type    = string
  default = "eks-showcase"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "region" {
  type    = string
  default = "eu-central-1"
}

variable "vpc_cidr" {
  type    = string
  default = "10.20.0.0/16"
}

variable "kubernetes_version" {
  type    = string
  default = "1.33"
}

variable "api_allowed_cidrs" {
  description = "Your public IP as x.x.x.x/32. Required: there is deliberately no default."
  type        = list(string)

  validation {
    condition     = !contains(var.api_allowed_cidrs, "0.0.0.0/0")
    error_message = "Refusing to expose the Kubernetes API to the whole internet."
  }
}

variable "access_entries" {
  type    = any
  default = {}
}

variable "gitops_repo_url" {
  description = "HTTPS URL of this repository; used for resource tagging."
  type        = string
}
