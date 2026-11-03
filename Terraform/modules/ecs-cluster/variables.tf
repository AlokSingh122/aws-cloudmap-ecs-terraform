variable "project_name" {
  type = string
}

variable "container_insights_enabled" {
  type = bool
}

variable "capacity_providers" {
  type = list(string)
}

variable "default_capacity_provider" {
  type = string
}

variable "capacity_provider_weight" {
  type = number
}

variable "capacity_provider_base" {
  type = number
}