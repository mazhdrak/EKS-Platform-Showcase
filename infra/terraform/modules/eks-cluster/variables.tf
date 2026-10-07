variable "name" {
  type = string
}

variable "kubernetes_version" {
  description = "EKS Kubernetes minor version. Check supported versions before bumping."
  type        = string
  default     = "1.33"
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "api_allowed_cidrs" {
  description = "CIDRs allowed to reach the public API endpoint. Never leave 0.0.0.0/0 outside a demo."
  type        = list(string)
}

variable "access_entries" {
  description = "Additional EKS access entries (see terraform-aws-modules/eks docs)."
  type        = any
  default     = {}
}

variable "node_instance_types" {
  description = "Several types improve spot availability."
  type        = list(string)
  default     = ["t3.large", "t3a.large", "m5.large"]
}

variable "node_capacity_type" {
  type    = string
  default = "SPOT"

  validation {
    condition     = contains(["ON_DEMAND", "SPOT"], var.node_capacity_type)
    error_message = "node_capacity_type must be ON_DEMAND or SPOT."
  }
}

variable "node_min_size" {
  type    = number
  default = 2
}

variable "node_max_size" {
  type    = number
  default = 4
}

variable "node_desired_size" {
  type    = number
  default = 2
}

variable "tags" {
  type    = map(string)
  default = {}
}
