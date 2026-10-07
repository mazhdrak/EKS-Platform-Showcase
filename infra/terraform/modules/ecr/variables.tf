variable "prefix" {
  type = string
}

variable "repositories" {
  type = list(string)
}

variable "keep_images" {
  type    = number
  default = 30
}

variable "force_delete" {
  description = "Allow destroying repositories that still contain images (handy for demos)."
  type        = bool
  default     = false
}

variable "tags" {
  type    = map(string)
  default = {}
}
