variable "project" {
  description = "Short name used as a prefix for every resource."
  type        = string
  default     = "eks-showcase"
}

variable "region" {
  description = "AWS region."
  type        = string
  default     = "eu-central-1"
}

variable "github_owner" {
  description = "GitHub user or organization that owns this repository."
  type        = string
  default     = "mazhdrak"
}

variable "github_repo" {
  description = "Repository name, exactly as on GitHub: it is matched against the OIDC sub claim."
  type        = string
  default     = "EKS-Platform-Showcase"
}

variable "apply_environment" {
  description = "GitHub environment whose jobs may assume the apply role."
  type        = string
  default     = "production"
}
