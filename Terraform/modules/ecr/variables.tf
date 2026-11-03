
variable "project_name" {
  type = string
}

variable "image_tag_mutability" {
  type = string
}

variable "scan_on_push" {
  type = bool
}

variable "encryption_type" {
  type = string
}

variable "image_retention_count" {
  type = number
}
