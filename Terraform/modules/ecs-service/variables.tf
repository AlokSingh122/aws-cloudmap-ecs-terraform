variable "project_name" {
  type = string
}

variable "cluster_arn" {
  type = string
}

variable "task_definition_arn" {
  type = string
}

variable "capacity_provider" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "task_security_group_id" {
  type = string
}

variable "cloudmap_service_arn" {
  type = string
}

variable "container_name" {
  type = string
}

variable "container_port" {
  type = number
}

variable "desired_task_count" {
  type = number
}