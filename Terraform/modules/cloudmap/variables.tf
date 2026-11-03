
variable "project_name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "namespace_name" {
  type = string
}

variable "namespace_description" {
  type = string
}

variable "record_ttl" {
  type = number
}

variable "record_type" {
  type = string
}

variable "routing_policy" {
  type = string
}
